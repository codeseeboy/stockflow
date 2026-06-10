import 'package:supabase/supabase.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
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
  Future<void> signUpCustomer(String email, String password, String name, String phone) async {
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
        await client.from('profiles').upsert({'id': uid, 'name': name, 'role': 'customer', 'phone': phone, 'email': email});
      } catch (_) {
        // Older schema without the email column — retry without it.
        try {
          await client.from('profiles').upsert({'id': uid, 'name': name, 'role': 'customer', 'phone': phone});
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

  Future<void> insertItem({
    required String name,
    required String emoji,
    required String category,
    required String unit,
    required double qty,
    required double reorder,
  }) =>
      client.from('items').insert({
        'name': name,
        'emoji': emoji,
        'category': category,
        'unit': unit,
        'opening_qty': qty,
        'current_qty': qty,
        'reorder_level': reorder,
      });

  Future<void> insertUser({
    required String name,
    required UserRole role,
    required String phone,
    required String unit,
  }) =>
      client.from('profiles').insert({
        'name': name,
        'role': role.name,
        'phone': phone,
        'unit': unit,
      });

  Future<void> deleteUser(String id) => client.from('profiles').delete().eq('id', id);

  Future<void> updateOrderStatus(String id, OrderStatus status) =>
      client.from('orders').update({'status': status.name}).eq('id', id);

  Future<void> updateCycleStatus(String id, CycleStatus status) =>
      client.from('order_cycles').update({'status': status.name}).eq('id', id);

  Future<void> insertCycle({
    required String title,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) =>
      client.from('order_cycles').insert({
        'title': title,
        'week_start': weekStart.toIso8601String(),
        'week_end': weekEnd.toIso8601String(),
        'status': 'open',
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

  Item _item(Map<String, dynamic> r) => Item(
        id: r['id'].toString(),
        name: r['name'] as String,
        emoji: (r['emoji'] as String?) ?? '📦',
        category: r['category'] as String,
        unit: r['unit'] as String,
        openingQty: _d(r['opening_qty']),
        currentQty: _d(r['current_qty']),
        reorderLevel: _d(r['reorder_level']),
      );

  AppUser _user(Map<String, dynamic> r) => AppUser(
        id: r['id'].toString(),
        name: r['name'] as String,
        role: UserRole.values.byName((r['role'] as String?) ?? 'customer'),
        phone: (r['phone'] as String?) ?? '',
        unit: (r['unit'] as String?) ?? '',
        email: (r['email'] as String?) ?? '',
      );

  OrderCycle _cycle(Map<String, dynamic> r) => OrderCycle(
        id: r['id'].toString(),
        title: r['title'] as String,
        weekStart: DateTime.parse(r['week_start'].toString()),
        weekEnd: DateTime.parse(r['week_end'].toString()),
        status: CycleStatus.values.byName((r['status'] as String?) ?? 'open'),
        shareToken: (r['share_token'] as String?) ?? '',
      );

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
    return Order(
      id: r['id'].toString(),
      cycleId: r['cycle_id']?.toString() ?? '',
      customerName: (r['customer_name'] as String?) ?? 'Customer',
      customerPhone: (r['customer_phone'] as String?) ?? '',
      lines: lines,
      status: OrderStatus.values.byName((r['status'] as String?) ?? 'pending'),
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
}
