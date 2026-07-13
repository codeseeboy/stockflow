import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/app_prefs.dart';
import '../utils/customer_orders.dart';
import '../utils/item_icon_brain.dart';
import '../utils/stock_import.dart';
import 'supabase_service.dart';

/// In-memory data + business logic for the prototype.
///
/// This is the single source of truth the whole app reads from. When we move to
/// Supabase, only this class's method bodies change (the screens stay the same).
class AppStore extends ChangeNotifier {
  AppStore() {
    // Only seed in-memory demo data when Supabase is NOT configured.
    // In live mode the real tables are empty on first run and populate
    // via reload() once connectSupabase() is called.
    if (!SupabaseConfig.isConfigured) _seed();
  }

  final List<Item> items = [];
  final List<AppUser> users = [];
  final List<OrderCycle> cycles = [];
  final List<Order> orders = [];
  final List<CustomerBroadcast> customerBroadcasts = [];

  int _orderSeq = 1000;
  int _broadcastSeq = 1;
  int _itemSeq = 100;
  int _userSeq = 100;

  String storeName = 'Central Store';

  // ---- Ration zones (admin-editable criteria) -----------------------------
  final Map<String, double> _zoneMaster = {for (final z in kRationZones) z.name: z.masterLimit};
  final Map<String, Map<String, double>> _zoneCats = {for (final z in kRationZones) z.name: Map<String, double>.of(z.categoryLimits)};
  final Map<String, Map<String, double>> _zoneItemMax = {for (final z in kRationZones) z.name: Map<String, double>.of(z.itemMax)};

  List<String> get zoneNames => kZoneNames;

  /// The current (possibly admin-edited) criteria for a zone.
  RationZone zoneFor(String name) {
    final base = rationZoneFor(name);
    return RationZone(
      name: base.name,
      level: base.level,
      masterLimit: _zoneMaster[base.name] ?? base.masterLimit,
      categoryLimits: _zoneCats[base.name] ?? base.categoryLimits,
      itemMax: _zoneItemMax[base.name] ?? base.itemMax,
      defaultCategoryLimit: base.defaultCategoryLimit,
    );
  }

  void setZoneMaster(String zone, double value) {
    _zoneMaster[zone] = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setZoneCategoryLimit(String zone, String category, double value) {
    (_zoneCats[zone] ??= {})[category] = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setZoneItemMax(String zone, String itemName, double value) {
    final m = _zoneItemMax[zone] ??= {};
    if (value <= 0) {
      m.remove(itemName);
    } else {
      m[itemName] = value;
    }
    notifyListeners();
  }

  /// Customers assigned to [zone].
  List<AppUser> customersInZone(String zone) =>
      users.where((u) => u.role == UserRole.customer && u.zone == zone).toList();

  /// Order links (cycles) scoped to [zone], newest first.
  List<OrderCycle> linksForZone(String zone) =>
      cyclesByRecent.where((c) => c.designation == zone).toList();

  /// Orders placed against any link in [zone].
  List<Order> ordersInZone(String zone) {
    final ids = linksForZone(zone).map((c) => c.id).toSet();
    return orders.where((o) => ids.contains(o.cycleId)).toList();
  }

  /// Non-null once connected to Supabase. When null, everything runs on the
  /// seeded in-memory data.
  SupabaseService? _sb;
  bool get isLive => _sb != null;

  /// True once the saved session (if any) has been restored, so the splash
  /// screen knows it can route the user.
  bool _bootstrapped = false;
  bool get bootstrapped => _bootstrapped;

  /// Mark the store ready without Supabase (demo mode).
  void markReady() {
    _bootstrapped = true;
    notifyListeners();
  }

  /// Connect to Supabase: restore session, load real data + subscribe to live changes.
  Future<void> connectSupabase(SupabaseService sb) async {
    _sb = sb;
    await sb.restoreSession();
    _bootstrapped = true;
    notifyListeners();
    await reload();
    sb.subscribe(() => reload());
  }

  /// True when running on Supabase (live) — admin/staff must sign in to write.
  bool get requiresLogin => _sb != null;

  /// True once an admin/staff user is signed in (session restored or fresh login).
  bool get isSignedIn => _sb?.isSignedIn ?? false;

  /// Sign in a staff/admin user. Throws on failure (UI shows the message).
  Future<void> signIn(String email, String password) async {
    final sb = _sb;
    if (sb == null) return;
    await sb.signIn(email, password);
    final role = await currentRole() ?? UserRole.admin;
    SavedAdminSession(email: email, role: role).save();
    await reload();
    notifyListeners();
  }

  /// Role of the signed-in user, from their profile.
  Future<UserRole?> currentRole() => _sb?.fetchMyRole() ?? Future.value(null);

  /// Register a customer account (no-op in demo mode).
  Future<void> signUpCustomer(String email, String password, String name, String phone) async {
    final sb = _sb;
    if (sb == null) return;
    await sb.signUpCustomer(email, password, name, phone);
  }

  /// The signed-in user's profile (name/phone), if any.
  Future<AppUser?> myProfile() => _sb?.fetchMyProfile() ?? Future.value(null);

  Future<void> signOut() async {
    await _sb?.signOut();
    SavedAdminSession.clear();
    await reload();
    notifyListeners();
  }

  /// Pull the latest data from Supabase into the local cache.
  Future<void> reload() async {
    final sb = _sb;
    if (sb == null) return;
    try {
      final fetchedItems = await sb.fetchItems();
      final fetchedUsers = await sb.fetchUsers();
      final fetchedCycles = await sb.fetchCycles();
      final fetchedOrders = await sb.fetchOrders();
      List<CustomerBroadcast> fetchedBroadcasts = const [];
      try {
        fetchedBroadcasts = await sb.fetchBroadcasts();
      } catch (_) {}
      // Always replace with real data — this clears any in-memory seed data
      // so the UI never shows demo items alongside real DB rows.
      // Keep in-memory orders the server didn't return (RLS gap, pending sync).
      final localOnly = orders.where((o) => !fetchedOrders.any((f) => f.id == o.id)).toList();
      items
        ..clear()
        ..addAll(fetchedItems);
      orders
        ..clear()
        ..addAll(fetchedOrders);
      for (final o in localOnly) {
        orders.insert(0, o);
      }
      customerBroadcasts
        ..clear()
        ..addAll(fetchedBroadcasts);
      users
        ..clear()
        ..addAll(fetchedUsers);
      cycles
        ..clear()
        ..addAll(fetchedCycles);
      notifyListeners();
    } catch (_) {
      // On any failure keep the existing data so the UI stays usable.
    }
  }

  /// Fire-and-forget a remote write, swallowing errors. Staff writes need a
  /// signed-in user (RLS); until the login screen exists those will be rejected
  /// remotely — local state still updates so the UI stays responsive.
  void _fire(Future<void>? f) {
    if (f != null) unawaited(f.catchError((Object _) {}));
  }

  /// Days the current month's stock has been running — used to estimate the
  /// consumption rate for the "days left" prediction.
  static const int _daysElapsed = 13;

  // ---- Derived ------------------------------------------------------------

  OrderCycle get activeCycle {
    if (cycles.isEmpty) {
      return OrderCycle(
        id: '',
        title: 'No active week',
        weekStart: DateTime.now(),
        weekEnd: DateTime.now(),
        status: CycleStatus.draft,
        shareToken: '',
      );
    }
    return cycles.firstWhere((c) => c.status == CycleStatus.open, orElse: () => cycles.first);
  }

  /// Cycle customers place orders against — prefers an open week, otherwise the latest.
  OrderCycle get orderingCycle => activeCycle;

  /// Every order window that is currently open. There can be more than one —
  /// two windows in a week, or several per-designation links live at once.
  List<OrderCycle> get openCycles =>
      cycles.where((c) => c.status == CycleStatus.open).toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart));

  /// Open windows a customer with [designation] may order in. A public window
  /// (empty designation) is open to everyone; a scoped one must match the
  /// customer's designation (case-insensitive).
  List<OrderCycle> openCyclesFor(String designation) {
    final d = designation.trim().toLowerCase();
    return openCycles.where((c) {
      if (c.isPublic) return true;
      return c.designation.trim().toLowerCase() == d;
    }).toList();
  }

  /// True only when there is an OPEN order window and stock to order.
  /// (Falls back cycle may exist but be closed — then ordering is disabled.)
  bool get canPlaceOrders =>
      items.isNotEmpty && orderingCycle.id.isNotEmpty && orderingCycle.status == CycleStatus.open;

  /// All cycles newest-first (for week-wise order history).
  List<OrderCycle> get cyclesByRecent =>
      [...cycles]..sort((a, b) => b.weekStart.compareTo(a.weekStart));

  List<Item> get lowStockItems =>
      items.where((i) => i.status == StockStatus.low).toList();

  List<Item> get outOfStockItems =>
      items.where((i) => i.status == StockStatus.out).toList();

  int get totalItems => items.length;
  int get lowCount => lowStockItems.length;
  int get outCount => outOfStockItems.length;

  List<Order> get ordersThisCycle =>
      orders.where((o) => o.cycleId == activeCycle.id).toList();

  /// Estimated days until an item runs out at the current consumption rate.
  /// Returns null when it isn't moving (no consumption yet).
  int? daysLeft(Item item) {
    final consumed = item.openingQty - item.currentQty;
    if (consumed <= 0 || item.currentQty <= 0) return item.currentQty <= 0 ? 0 : null;
    final perDay = consumed / _daysElapsed;
    if (perDay <= 0) return null;
    return (item.currentQty / perDay).floor();
  }

  /// Fair-share fraction: in a single order a customer/unit may take at most
  /// this share of a category's currently-available stock. Tweak to make the
  /// per-category quota tighter or looser.
  static const double categoryFairShare = 0.5;

  /// Rule-based ordering quota for a category (in units), based on a fair share
  /// of what's currently in stock so one unit can't claim everything.
  double categoryQuota(String cat) {
    final stock = items
        .where((i) => i.category == cat && i.currentQty > 0)
        .fold<double>(0, (s, i) => s + i.currentQty);
    return stock * categoryFairShare;
  }

  /// Units remaining grouped by category (for the dashboard chart).
  Map<String, double> get unitsByCategory {
    final map = <String, double>{};
    for (final c in kCategories) {
      map[c.name] = 0;
    }
    for (final i in items) {
      map[i.category] = (map[i.category] ?? 0) + i.currentQty;
    }
    map.removeWhere((k, v) => v <= 0);
    return map;
  }

  // ---- Analytics (consumption vs stock) -----------------------------------

  /// How much of an item has been sold/used this cycle (opening − current).
  double consumedOf(Item i) => (i.openingQty - i.currentQty).clamp(0, double.infinity);

  double get totalConsumed => items.fold(0.0, (s, i) => s + consumedOf(i));
  double get totalInStock => items.fold(0.0, (s, i) => s + i.currentQty);

  /// Per-category: consumed vs currently in stock.
  /// Returns ordered category names that have any activity.
  List<String> get activeCategories {
    final names = <String>[];
    for (final c in kCategories) {
      final has = items.any((i) => i.category == c.name);
      if (has) names.add(c.name);
    }
    return names;
  }

  double consumedInCategory(String cat) =>
      items.where((i) => i.category == cat).fold(0.0, (s, i) => s + consumedOf(i));

  double stockInCategory(String cat) =>
      items.where((i) => i.category == cat).fold(0.0, (s, i) => s + i.currentQty);

  /// Units ordered grouped by customer/unit (from orders) — "consumption by unit".
  Map<String, double> consumptionByUnit() {
    final m = <String, double>{};
    for (final o in orders) {
      m[o.customerName] = (m[o.customerName] ?? 0) + o.totalUnits;
    }
    return m;
  }

  /// Alerts feed = out-of-stock + low + "running out soon" predictions.
  List<Alert> get alerts {
    final list = <Alert>[];
    final now = DateTime.now();
    for (final i in outOfStockItems) {
      list.add(Alert(
        id: 'out-${i.id}',
        title: '${i.name} is out of stock',
        body: 'Restock immediately. Customers can no longer order this.',
        icon: Icons.error_rounded,
        color: AppColors.danger,
        time: now,
      ));
    }
    for (final i in lowStockItems) {
      final d = daysLeft(i);
      list.add(Alert(
        id: 'low-${i.id}',
        title: '${i.name} running low',
        body: d != null
            ? 'About ${_fmt(i.currentQty)} ${i.unit} left · ~$d days at current rate.'
            : 'About ${_fmt(i.currentQty)} ${i.unit} left, below reorder level.',
        icon: Icons.trending_down_rounded,
        color: AppColors.warning,
        time: now,
      ));
    }
    return list;
  }

  // ---- Mutations ----------------------------------------------------------

  Order placeOrder({
    required String customerName,
    required String customerPhone,
    required Map<String, double> cart,
    String? cycleId,
  }) {
    final targetCycleId = cycleId ?? orderingCycle.id;
    final lines = <OrderLine>[];
    cart.forEach((itemId, qty) {
      if (qty <= 0) return;
      final item = items.firstWhere((i) => i.id == itemId);
      // Ration system: availability never blocks an order — record the full
      // requested quantity. Stock is still decremented (for admin records),
      // floored at zero so it never reads negative.
      item.currentQty = (item.currentQty - qty).clamp(0, double.infinity).toDouble();
      lines.add(OrderLine(
        itemId: item.id,
        name: item.name,
        emoji: item.emoji,
        unit: item.unit,
        qty: qty,
      ));
    });
    if (lines.isEmpty) {
      throw StateError('Nothing could be added — check item availability and try again.');
    }
    final localId = 'ORD-${_orderSeq++}';
    final order = Order(
      id: localId,
      cycleId: targetCycleId,
      customerName: customerName,
      customerPhone: customerPhone,
      lines: lines,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    orders.insert(0, order);
    SavedCustomerOrders.upsert(customerName, customerPhone, order);
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      _fire(sb
          .placeOrder(cycleId: targetCycleId, name: customerName, phone: customerPhone, cart: cart)
          .then((remoteId) async {
        final sid = remoteId.toString();
        final idx = orders.indexWhere((o) => o.id == localId);
        final synced = Order(
          id: sid,
          cycleId: order.cycleId,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          lines: order.lines,
          status: order.status,
          createdAt: order.createdAt,
        );
        if (idx >= 0) {
          orders[idx] = synced;
        } else if (!orders.any((o) => o.id == sid)) {
          orders.insert(0, synced);
        }
        SavedCustomerOrders.upsert(customerName, customerPhone, synced);
        notifyListeners();
        await reload();
        if (!orders.any((o) => o.id == sid)) {
          orders.insert(0, synced);
          notifyListeners();
        }
      }).catchError((Object _) {
        // Remote write failed — local + on-device copy stays visible.
      }));
    }
    return order;
  }

  void restock(Item item, double amount) {
    item.currentQty += amount;
    if (item.currentQty > item.openingQty) item.openingQty = item.currentQty;
    notifyListeners();
    _fire(_sb?.updateItemQty(item.id, item.currentQty));
  }

  void setStock(Item item, double qty) {
    item.currentQty = qty.clamp(0, double.infinity);
    if (item.currentQty > item.openingQty) item.openingQty = item.currentQty;
    notifyListeners();
    _fire(_sb?.updateItemQty(item.id, item.currentQty));
  }

  void setReorder(Item item, double level) {
    item.reorderLevel = level.clamp(0, double.infinity);
    notifyListeners();
    _fire(_sb?.updateReorder(item.id, item.reorderLevel));
  }

  void setEmoji(Item item, String emoji) {
    item.emoji = emoji.isEmpty ? '📦' : emoji;
    notifyListeners();
    _fire(_sb?.updateItemEmoji(item.id, item.emoji));
  }

  void addItem({
    required String name,
    required String emoji,
    required String category,
    required String unit,
    required double qty,
    required double reorder,
    bool notifyCustomers = false,
  }) {
    final icon = emoji.isEmpty ? '📦' : emoji;
    items.add(Item(
      id: 'I${_itemSeq++}',
      name: name,
      emoji: icon,
      category: category,
      unit: unit,
      openingQty: qty,
      currentQty: qty,
      reorderLevel: reorder,
    ));
    notifyListeners();
    if (notifyCustomers) {
      unawaited(broadcastToCustomers(
        title: 'New item available',
        body: '$icon $name is now on the order list.',
        itemEmoji: icon,
      ));
    }
    final sb = _sb;
    if (sb != null) {
      _fire(sb
          .insertItem(name: name, emoji: icon, category: category, unit: unit, qty: qty, reorder: reorder)
          .then((_) => reload()));
    }
  }

  /// Send a notification blast to all registered customers.
  /// In-app + push are instant. Email is sent automatically server-side via the
  /// `send-broadcast-email` Edge Function (Gmail SMTP) when live + configured.
  Future<BroadcastResult> broadcastToCustomers({
    required String title,
    required String body,
    bool inApp = true,
    bool sms = true,
    bool whatsapp = true,
    bool email = true,
    String? itemEmoji,
  }) async {
    final customers = users.where((u) => u.role == UserRole.customer).toList();
    final count = customers.length;
    final logs = <DeliveryLogEntry>[
      for (final c in customers)
        DeliveryLogEntry(
          customerName: c.name,
          phone: c.phone,
          email: c.email,
          inAppDelivered: inApp,
          smsDelivered: sms && c.phone.trim().isNotEmpty,
          whatsappDelivered: whatsapp && c.phone.trim().isNotEmpty,
          emailDelivered: email && c.email.trim().isNotEmpty,
        ),
    ];
    final broadcast = CustomerBroadcast(
      id: 'BC-${_broadcastSeq++}',
      title: title,
      body: body,
      sentAt: DateTime.now(),
      inApp: inApp,
      sms: sms,
      whatsapp: whatsapp,
      recipientCount: count,
      itemEmoji: itemEmoji,
    );
    customerBroadcasts.insert(0, broadcast);
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      _fire(sb.insertBroadcast(broadcast).then((_) => reload()).catchError((Object _) {}));
    }

    // Automatic email delivery via the Edge Function. Silently falls back to the
    // manual "Email all" button if the function isn't deployed/configured yet.
    var autoEmailed = 0;
    if (email && sb != null) {
      try {
        autoEmailed = await sb.sendBroadcastEmail(title, body);
      } catch (_) {
        autoEmailed = 0;
      }
    }

    return BroadcastResult(
      inAppCount: inApp ? count : 0,
      smsCount: sms ? logs.where((l) => l.smsDelivered).length : 0,
      whatsappCount: whatsapp ? logs.where((l) => l.whatsappDelivered).length : 0,
      emailCount: email ? (autoEmailed > 0 ? autoEmailed : logs.where((l) => l.emailDelivered).length) : 0,
      autoEmailed: autoEmailed > 0,
      logs: logs,
    );
  }

  void updateOrderStatus(Order order, OrderStatus status) {
    order.status = status;
    notifyListeners();
    _fire(_sb?.updateOrderStatus(order.id, status));
  }

  /// Apply an uploaded master-stock file.
  /// [addToExisting] = true → add quantities onto existing items; false → replace.
  ImportSummary importStock(List<ImportRow> rows, {required bool addToExisting}) {
    var added = 0;
    var updated = 0;
    for (final r in rows) {
      final match = items.where((i) => i.name.toLowerCase() == r.name.toLowerCase());
      if (match.isNotEmpty) {
        final it = match.first;
        if (addToExisting) {
          it.openingQty += r.qty;
          it.currentQty += r.qty;
        } else {
          it.openingQty = r.qty;
          it.currentQty = r.qty;
        }
        if (r.reorder > 0) it.reorderLevel = r.reorder;
        updated++;
        _fire(_sb?.updateItemStock(it.id, current: it.currentQty, opening: it.openingQty));
        if (r.reorder > 0) _fire(_sb?.updateReorder(it.id, it.reorderLevel));
      } else {
        final smart = ItemIconBrain.suggest(r.name, items);
        final emoji = r.emoji == '📦' || r.emoji.isEmpty ? smart.emoji : r.emoji;
        final category = r.category.isEmpty || r.category == 'Essentials' && smart.confidence > 0.5 ? smart.category : r.category;
        final unit = r.unit.isEmpty ? smart.unit : r.unit;
        items.add(Item(
          id: 'I${_itemSeq++}',
          name: r.name,
          emoji: emoji,
          category: category,
          unit: unit,
          openingQty: r.qty,
          currentQty: r.qty,
          reorderLevel: r.reorder,
        ));
        added++;
        _fire(_sb?.insertItem(name: r.name, emoji: emoji, category: category, unit: unit, qty: r.qty, reorder: r.reorder));
      }
    }
    notifyListeners();
    if (_sb != null) _fire(reload());
    return ImportSummary(added: added, updated: updated);
  }

  void addUser({
    required String name,
    required UserRole role,
    required String phone,
    required String unit,
    String zone = '',
  }) {
    users.add(AppUser(id: 'U${_userSeq++}', name: name, role: role, phone: phone, unit: unit, zone: zone));
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      _fire(sb.insertUser(name: name, role: role, phone: phone, unit: unit).then((_) => reload()));
    }
  }

  void removeUser(AppUser user) {
    users.removeWhere((u) => u.id == user.id);
    notifyListeners();
    final sb = _sb;
    if (sb != null) _fire(sb.deleteUser(user.id).then((_) => reload()));
  }

  void setStoreName(String name) {
    storeName = name;
    notifyListeners();
  }

  List<AppUser> get staff => users.where((u) => u.role != UserRole.customer).toList();
  List<AppUser> get customers => users.where((u) => u.role == UserRole.customer).toList();

  /// Open a new ordering window. [designation] scopes it to an audience (empty =
  /// everyone). [closeOthers] false keeps existing open windows live too, so you
  /// can run two windows in a week or several per-designation links at once.
  OrderCycle openNewCycle({String designation = '', bool closeOthers = true}) {
    final previouslyOpen = <String>[];
    if (closeOthers) {
      for (final c in cycles) {
        if (c.status == CycleStatus.open) {
          previouslyOpen.add(c.id);
          c.status = CycleStatus.closed;
        }
      }
    }
    final last = cycles.isNotEmpty ? cycles.first : null;
    final start = (last?.weekEnd ?? DateTime.now()).add(const Duration(days: 1));
    final end = start.add(const Duration(days: 6));
    final num = int.tryParse((last?.title ?? '23').replaceAll(RegExp(r'[^0-9]'), '')) ?? 23;
    final label = designation.trim();
    final slug = label.isEmpty ? '' : '-${label.replaceAll(RegExp(r'\s+'), '').toLowerCase()}';
    final cycle = OrderCycle(
      id: 'CY-${num + 1}$slug',
      title: label.isEmpty ? 'Week ${num + 1}' : 'Week ${num + 1} · $label',
      weekStart: start,
      weekEnd: end,
      status: CycleStatus.open,
      shareToken: _token(),
      designation: label,
    );
    cycles.insert(0, cycle);
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      for (final id in previouslyOpen) {
        _fire(sb.updateCycleStatus(id, CycleStatus.closed));
      }
      _fire(sb.insertCycle(title: cycle.title, weekStart: start, weekEnd: end).then((_) => reload()));
    }
    return cycle;
  }

  void closeCycle(OrderCycle cycle) {
    cycle.status = CycleStatus.closed;
    notifyListeners();
    _fire(_sb?.updateCycleStatus(cycle.id, CycleStatus.closed).then((_) => reload()));
  }

  void reopenCycle(OrderCycle cycle) {
    cycle.status = CycleStatus.open;
    notifyListeners();
    _fire(_sb?.updateCycleStatus(cycle.id, CycleStatus.open).then((_) => reload()));
  }

  // ---- Helpers ------------------------------------------------------------

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _token() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ---- Seed ---------------------------------------------------------------

  void _seed() {
    // Build the catalogue from the real RIK Officers scale. Stock is effectively
    // unlimited (ration) so quantities are set high and never shown to customers.
    var idx = 0;
    for (final cat in kRikOfficers) {
      for (final a in cat.articles) {
        items.add(Item(
          id: 'R${idx++}',
          name: a.name,
          emoji: cat.emoji,
          category: cat.name,
          unit: cat.unit,
          openingQty: 100000,
          currentQty: 100000,
          reorderLevel: 0,
        ));
      }
    }

    users.addAll(const [
      AppUser(id: 'U1', name: 'Cdr Arjun Mehta', role: UserRole.admin, phone: '+91 98200 11001', unit: 'Logistics'),
      AppUser(id: 'U2', name: 'PO Priya Nair', role: UserRole.worker, phone: '+91 98200 11002', unit: 'Ration Store'),
      AppUser(id: 'U3', name: 'LS Rahul Verma', role: UserRole.worker, phone: '+91 98200 11003', unit: 'Ration Store'),
      AppUser(id: 'U4', name: 'Wardroom Mess', role: UserRole.customer, phone: '+91 90000 22001', unit: 'Wardroom', zone: 'Officers'),
      AppUser(id: 'U5', name: 'Lt Bravo', role: UserRole.customer, phone: '+91 90000 22002', unit: 'OM Block A', zone: 'Officers'),
      AppUser(id: 'U6', name: 'Lt Cdr Delta', role: UserRole.customer, phone: '+91 90000 22003', unit: 'OM Block B', zone: 'Officers'),
      AppUser(id: 'U7', name: 'Sub Lt Charlie', role: UserRole.customer, phone: '+91 90000 22004', unit: 'OM Block C', zone: 'Officers'),
    ]);

    cycles.addAll([
      OrderCycle(id: 'CY-23', title: 'RIK · Officers · Wk 23', weekStart: DateTime(2026, 6, 9), weekEnd: DateTime(2026, 6, 15), status: CycleStatus.open, shareToken: 'rikoff23', designation: 'Officers'),
      OrderCycle(id: 'CY-22', title: 'RIK · Officers · Wk 22', weekStart: DateTime(2026, 6, 2), weekEnd: DateTime(2026, 6, 8), status: CycleStatus.closed, shareToken: 'rikoff22', designation: 'Officers'),
      OrderCycle(id: 'CY-21', title: 'RIK · Officers · Wk 21', weekStart: DateTime(2026, 5, 26), weekEnd: DateTime(2026, 6, 1), status: CycleStatus.closed, shareToken: 'rikoff21', designation: 'Officers'),
    ]);

    Item pick(String name) => items.firstWhere((i) => i.name == name, orElse: () => items.first);
    OrderLine line(String name, double qty) {
      final it = pick(name);
      return OrderLine(itemId: it.id, name: it.name, emoji: it.emoji, unit: it.unit, qty: qty);
    }

    final now = DateTime.now();
    orders.addAll([
      Order(
        id: 'ORD-${_orderSeq++}', cycleId: 'CY-23', customerName: 'Wardroom Mess', customerPhone: '+91 90000 22001',
        status: OrderStatus.confirmed, createdAt: now.subtract(const Duration(hours: 3)),
        lines: [line('Atta 1 kg', 3), line('Meat Fresh 1 kg', 1.5), line('Tomato', 1), line('Eggs', 14)],
      ),
      Order(
        id: 'ORD-${_orderSeq++}', cycleId: 'CY-23', customerName: 'Lt Bravo', customerPhone: '+91 90000 22002',
        status: OrderStatus.pending, createdAt: now.subtract(const Duration(hours: 6)),
        lines: [line('Potato', 0.75), line('Onion', 0.4), line('Refined Oil 1 L', 0.5), line('Sugar 1 kg', 0.6)],
      ),
      Order(
        id: 'ORD-${_orderSeq++}', cycleId: 'CY-22', customerName: 'Lt Cdr Delta', customerPhone: '+91 90000 22003',
        status: OrderStatus.fulfilled, createdAt: now.subtract(const Duration(days: 2, hours: 2)),
        lines: [line('India Gate Rozana 1 kg', 3), line('Apple Delicious', 1.6)],
      ),
    ]);
  }
}
