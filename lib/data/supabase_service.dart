import 'package:supabase/supabase.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
import '../utils/item_icon_brain.dart';
import '../utils/session_store.dart';

/// Thin wrapper over the Supabase client. Maps DB rows <-> app models and
/// exposes the operations [AppStore] needs. Pure-Dart `supabase` package, so
/// no native plugins / Developer Mode required.
class SupabaseService {
  SupabaseService()
      : client = SupabaseClient(
          SupabaseConfig.url,
          SupabaseConfig.anonKey,
          // Implicit flow avoids PKCE, which needs a configured async storage
          // we don't use (pure `supabase` package). Without this, signUp throws
          // a null-check before the request is even sent.
          authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
        ) {
    // Persist the refresh token so users stay logged in across reloads (web).
    client.auth.onAuthStateChange.listen((_) {
      final rt = client.auth.currentSession?.refreshToken;
      if (rt != null && rt.isNotEmpty) {
        writeSession(rt);
      } else {
        clearSession();
      }
    });
  }

  final SupabaseClient client;
  RealtimeChannel? _channel;

  bool get isSignedIn => client.auth.currentSession != null;

  /// Restore a previously saved session from its refresh token. Call before
  /// the first fetch so authenticated reads/writes work immediately.
  Future<void> restoreSession() async {
    final rt = readSession();
    if (rt == null || rt.isEmpty) return;
    try {
      await client.auth.setSession(rt);
      if (client.auth.currentSession == null) {
        await client.auth.refreshSession();
      }
      _persistSession();
    } catch (_) {
      clearSession();
    }
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
    _persistSession();
  }

  void _persistSession() {
    final rt = client.auth.currentSession?.refreshToken;
    if (rt != null && rt.isNotEmpty) writeSession(rt);
  }

  /// Customer self-signup. Name/phone go in as signup metadata so the
  /// `handle_new_user` trigger creates the profile.
  ///
  /// `signUp` response parsing can be flaky (it sometimes throws a null-check
  /// even when the account is created), so we swallow that and then establish
  /// a real session via sign-in, which surfaces any genuine error clearly.
  Future<void> signUpCustomer(String email, String password, String name, String phone, {String zone = ''}) async {
    // With implicit flow this completes cleanly and sets a session (email
    // confirmation is off). Genuine errors (weak password, already registered)
    // surface as AuthException for the UI to show.
    await client.auth.signUp(email: email, password: password, data: {'name': name, 'phone': phone});
    if (client.auth.currentSession == null) {
      try {
        await client.auth.signInWithPassword(email: email, password: password);
      } catch (_) {}
    }
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await client.from('profiles').upsert({'id': uid, 'name': name, 'role': 'customer', 'phone': phone, 'email': email, 'zone': zone});
      } catch (_) {
        // Older schema without the email column — retry without it.
        try {
          await client.from('profiles').upsert({'id': uid, 'name': name, 'role': 'customer', 'phone': phone, 'zone': zone});
        } catch (_) {}
      }
    }
  }

  /// The signed-in user's profile (name/phone), if available.
  Future<AppUser?> fetchMyProfile() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await client.from('profiles').select().eq('id', uid).limit(1);
    if (rows.isEmpty) return null;
    return _user(rows.first);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
    clearSession();
  }

  /// Role of the currently signed-in user (from their profile), or null.
  Future<UserRole?> fetchMyRole() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await client.from('profiles').select('role').eq('id', uid).limit(1);
    if (rows.isEmpty) return null;
    return UserRole.values.byName((rows.first['role'] as String?) ?? 'worker');
  }

  // ---- Fetch -------------------------------------------------------------

  Future<List<RationZone>> fetchZones() async {
    final rows = await client.from('zones').select().order('name');
    return rows.map<RationZone>(_zone).toList();
  }

  /// Create or update a zone's entitlement scale. name is the primary key —
  /// renaming a zone (if that's ever allowed) would need a delete + insert.
  Future<void> upsertZone(RationZone zone) => client.from('zones').upsert({
        'name': zone.name,
        'level': zone.level,
        'description': zone.description,
        'per_day': zone.perDay,
        'item_max': zone.itemMax,
        'default_per_day': zone.defaultPerDay,
      });

  Future<void> deleteZone(String name) => client.from('zones').delete().eq('name', name);

  Future<List<Item>> fetchItems() async {
    final rows = await client.from('items').select().order('name');
    return rows.map<Item>(_item).toList();
  }

  Future<List<AppUser>> fetchUsers() async {
    final rows = await client.from('profiles').select().order('name');
    return rows.map<AppUser>(_user).toList();
  }

  Future<List<OrderCycle>> fetchCycles() async {
    final rows = await client.from('order_cycles').select().order('week_start', ascending: false);
    return rows.map<OrderCycle>(_cycle).toList();
  }

  Future<List<CustomerBroadcast>> fetchBroadcasts() async {
    final rows = await client.from('customer_broadcasts').select().order('created_at', ascending: false).limit(50);
    return rows.map<CustomerBroadcast>(_broadcast).toList();
  }

  /// Sends the broadcast email to all customers via the `send-broadcast-email`
  /// Edge Function (Gmail SMTP). Returns how many were emailed. Throws on failure.
  Future<int> sendBroadcastEmail(String subject, String body) async {
    final res = await client.functions.invoke(
      'send-broadcast-email',
      body: {'subject': subject, 'body': body},
    );
    if (res.status != 200) {
      throw Exception('Email function failed (status ${res.status})');
    }
    final data = res.data;
    if (data is Map && data['sent'] != null) {
      return data['sent'] is int ? data['sent'] as int : int.tryParse('${data['sent']}') ?? 0;
    }
    return 0;
  }

  Future<void> insertBroadcast(CustomerBroadcast b) => client.from('customer_broadcasts').insert({
        'title': b.title,
        'body': b.body,
        'item_emoji': b.itemEmoji,
        'in_app': b.inApp,
        'sms': b.sms,
        'whatsapp': b.whatsapp,
        'recipient_count': b.recipientCount,
      });

  Future<List<Order>> fetchOrders() async {
    final rows = await client
        .from('orders')
        .select('*, order_items(*, items(name, emoji, unit))')
        .order('created_at', ascending: false);
    return rows.map<Order>(_order).toList();
  }

  // ---- Mutations ---------------------------------------------------------

  Future<String> placeOrder({
    required String cycleId,
    required String name,
    required String phone,
    required Map<String, double> cart,
  }) async {
    final items = cart.entries
        .where((e) => e.value > 0)
        .map((e) => {'item_id': e.key, 'qty': e.value})
        .toList();
    final res = await client.rpc('place_order', params: {
      'p_cycle': cycleId,
      'p_name': name,
      'p_phone': phone,
      'p_items': items,
    });
    return res.toString();
  }

  Future<void> updateItemQty(String id, double qty) =>
      client.from('items').update({'current_qty': qty}).eq('id', id);

  Future<void> updateItemStock(String id, {required double current, required double opening}) =>
      client.from('items').update({'current_qty': current, 'opening_qty': opening}).eq('id', id);

  Future<void> updateReorder(String id, double level) =>
      client.from('items').update({'reorder_level': level}).eq('id', id);

  Future<void> updateItemEmoji(String id, String emoji) =>
      client.from('items').update({'emoji': emoji}).eq('id', id);

  /// The zone this item's stock pool belongs to (Officers' rice vs Sailors'
  /// rice are separate items, separately tracked).
  Future<void> updateItemZone(String id, String zone) =>
      client.from('items').update({'zone': zone}).eq('id', id);

  Future<void> insertItem({
    required String name,
    required String emoji,
    required String category,
    required String unit,
    required double qty,
    required double reorder,
    String zone = '',
  }) async {
    final payload = {
      'name': name,
      'emoji': emoji,
      'category': category,
      'unit': unit,
      'opening_qty': qty,
      'current_qty': qty,
      'reorder_level': reorder,
      'zone': zone,
    };
    try {
      await client.from('items').insert(payload);
    } catch (_) {
      // Older schema without the zone column yet — retry without it rather
      // than lose the item entirely.
      await client.from('items').insert(payload..remove('zone'));
    }
  }

  /// Bulk insert for imports — one network call and one realtime event for the
  /// whole sheet, instead of one per row (which made the UI reload repeatedly).
  Future<void> insertItems(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await client.from('items').insert(rows);
    } catch (_) {
      // Older schema without the zone column yet.
      await client.from('items').insert([for (final r in rows) {...r}..remove('zone')]);
    }
  }

  Future<void> insertUser({
    required String name,
    required UserRole role,
    required String phone,
    required String unit,
    String zone = '',
  }) =>
      client.from('profiles').insert({
        'name': name,
        'role': role.name,
        'phone': phone,
        'unit': unit,
        'zone': zone,
      });

  Future<void> deleteUser(String id) => client.from('profiles').delete().eq('id', id);

  /// The customer's zone / designation — decides their entitlement scale.
  Future<void> updateUserZone(String id, String zone) =>
      client.from('profiles').update({'zone': zone}).eq('id', id);

  Future<void> updateOrderStatus(String id, OrderStatus status, {List<OrderStatusEvent>? history}) =>
      client.from('orders').update({
        'status': status.name,
        if (history != null) 'status_history': history.map((h) => h.toJson()).toList(),
      }).eq('id', id);

  Future<void> updateCycleStatus(String id, CycleStatus status) =>
      client.from('order_cycles').update({'status': status.name}).eq('id', id);

  /// The varieties the admin added to a demand.
  Future<void> updateCycleItems(String id, Set<String> itemIds) =>
      client.from('order_cycles').update({'item_ids': itemIds.toList()}).eq('id', id);

  Future<void> insertCycle(OrderCycle c) => client.from('order_cycles').insert({
        'title': c.title,
        'week_start': c.weekStart.toIso8601String(),
        'week_end': c.weekEnd.toIso8601String(),
        'status': c.status.name,
        'designation': c.designation,
        'demand_type': c.type.name,
        'days': c.days,
        'entitlement_month': c.month.key,
        'item_ids': c.itemIds.toList(),
      });

  // ---- Realtime ----------------------------------------------------------

  /// Calls [onChange] whenever items/orders/cycles/broadcasts change — drives live UI.
  void subscribe(void Function() onChange) {
    _channel = client.channel('public:stockflow')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'items',
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'order_cycles',
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customer_broadcasts',
        callback: (_) => onChange(),
      )
      ..subscribe();
  }

  Future<void> dispose() async {
    final ch = _channel;
    if (ch != null) await client.removeChannel(ch);
  }

  // ---- Mappers -----------------------------------------------------------

  RationZone _zone(Map<String, dynamic> r) => RationZone(
        name: (r['name'] as String?) ?? '',
        level: (r['level'] as String?) ?? '',
        description: (r['description'] as String?) ?? '',
        perDay: numMap(r['per_day']),
        itemMax: numMap(r['item_max']),
        defaultPerDay: r['default_per_day'] == null ? 0.05 : _d(r['default_per_day']),
      );

  Item _item(Map<String, dynamic> r) {
    final name = (r['name'] as String?) ?? '';
    var emoji = (r['emoji'] as String?) ?? '';
    // Rows imported before the icon brain existed (or with a bad emoji column)
    // arrive as 📦 boxes — resolve the right icon from the name at read time.
    if (emoji.isEmpty || emoji == '📦') {
      emoji = ItemIconBrain.suggest(name, const []).emoji;
    }
    return Item(
      id: r['id'].toString(),
      name: name,
      emoji: emoji,
      category: (r['category'] as String?) ?? 'Essentials',
      unit: (r['unit'] as String?) ?? 'kg',
      openingQty: _d(r['opening_qty']),
      currentQty: _d(r['current_qty']),
      reorderLevel: _d(r['reorder_level']),
      zone: (r['zone'] as String?) ?? '',
    );
  }

  AppUser _user(Map<String, dynamic> r) => AppUser(
        id: r['id'].toString(),
        name: r['name'] as String,
        role: UserRole.values.byName((r['role'] as String?) ?? 'customer'),
        phone: (r['phone'] as String?) ?? '',
        unit: (r['unit'] as String?) ?? '',
        email: (r['email'] as String?) ?? '',
        zone: (r['zone'] as String?) ?? '',
      );

  /// Demand fields are read defensively: a database that hasn't had the
  /// migration applied yet simply falls back to the defaults, so the app keeps
  /// working instead of failing to load its cycles.
  OrderCycle _cycle(Map<String, dynamic> r) {
    final weekStart = DateTime.parse(r['week_start'].toString());
    final rawType = (r['demand_type'] as String?) ?? '';
    final type = DemandType.values.where((t) => t.name == rawType).firstOrNull ?? DemandType.fresh;
    final rawDays = (r['days'] as num?)?.toInt();
    final month = RationMonth.tryParse((r['entitlement_month'] as String?) ?? '') ?? RationMonth.of(weekStart);
    final ids = (r['item_ids'] as List?)?.map((e) => e.toString()).toSet();
    return OrderCycle(
      id: r['id'].toString(),
      title: r['title'] as String,
      weekStart: weekStart,
      weekEnd: DateTime.parse(r['week_end'].toString()),
      status: CycleStatus.values.byName((r['status'] as String?) ?? 'open'),
      shareToken: (r['share_token'] as String?) ?? '',
      designation: (r['designation'] as String?) ?? '',
      type: type,
      days: rawDays != null && rawDays > 0 ? rawDays : type.defaultDays,
      month: month,
      itemIds: ids,
    );
  }

  CustomerBroadcast _broadcast(Map<String, dynamic> r) => CustomerBroadcast(
        id: r['id'].toString(),
        title: r['title'] as String,
        body: r['body'] as String,
        sentAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
        inApp: (r['in_app'] as bool?) ?? true,
        sms: (r['sms'] as bool?) ?? true,
        whatsapp: (r['whatsapp'] as bool?) ?? true,
        recipientCount: (r['recipient_count'] as num?)?.toInt() ?? 0,
        itemEmoji: r['item_emoji'] as String?,
      );

  Order _order(Map<String, dynamic> r) {
    final rawLines = (r['order_items'] as List?) ?? const [];
    final lines = rawLines.map<OrderLine>((raw) {
      final oi = raw as Map<String, dynamic>;
      final item = (oi['items'] as Map<String, dynamic>?) ?? const {};
      return OrderLine(
        itemId: oi['item_id']?.toString() ?? '',
        name: (item['name'] as String?) ?? 'Item',
        emoji: (item['emoji'] as String?) ?? '📦',
        unit: (item['unit'] as String?) ?? '',
        qty: _d(oi['qty_requested']),
      );
    }).toList();
    // Status values from before the richer lifecycle existed ('confirmed')
    // fall back to something in the current enum rather than throwing.
    final rawStatus = (r['status'] as String?) ?? 'pending';
    final status = OrderStatus.values.where((s) => s.name == rawStatus).firstOrNull ??
        (rawStatus == 'confirmed' ? OrderStatus.accepted : OrderStatus.pending);
    final rawHistory = (r['status_history'] as List?) ?? const [];
    final history = rawHistory
        .map((e) => OrderStatusEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Order(
      id: r['id'].toString(),
      cycleId: r['cycle_id']?.toString() ?? '',
      customerName: (r['customer_name'] as String?) ?? 'Customer',
      customerPhone: (r['customer_phone'] as String?) ?? '',
      lines: lines,
      status: status,
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
      orderNo: (r['order_no'] as num?)?.toInt(),
      history: history,
    );
  }

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
}
