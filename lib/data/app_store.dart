import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/app_prefs.dart';
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
      final localPending = orders.where((o) => o.id.startsWith('ORD-') && !fetchedOrders.any((f) => f.id == o.id)).toList();
      items
        ..clear()
        ..addAll(fetchedItems);
      orders
        ..clear()
        ..addAll(fetchedOrders);
      for (final o in localPending) {
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
  }) {
    final lines = <OrderLine>[];
    cart.forEach((itemId, qty) {
      if (qty <= 0) return;
      final item = items.firstWhere((i) => i.id == itemId);
      final take = min(qty, item.currentQty);
      if (take <= 0) return;
      item.currentQty -= take;
      lines.add(OrderLine(
        itemId: item.id,
        name: item.name,
        emoji: item.emoji,
        unit: item.unit,
        qty: take,
      ));
    });
    if (lines.isEmpty) {
      throw StateError('Nothing could be added — check item availability and try again.');
    }
    final localId = 'ORD-${_orderSeq++}';
    final order = Order(
      id: localId,
      cycleId: orderingCycle.id,
      customerName: customerName,
      customerPhone: customerPhone,
      lines: lines,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    orders.insert(0, order);
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      _fire(sb
          .placeOrder(cycleId: orderingCycle.id, name: customerName, phone: customerPhone, cart: cart)
          .then((_) {
        // RPC succeeded → the DB now has the real order. Drop the optimistic
        // copy so reload() doesn't show a duplicate, then pull the truth.
        orders.removeWhere((o) => o.id == localId);
        return reload();
      }).catchError((Object _) {
        // Remote write failed (RLS, network, etc.) — keep the local order visible.
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
  }) {
    users.add(AppUser(id: 'U${_userSeq++}', name: name, role: role, phone: phone, unit: unit));
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

  OrderCycle openNewCycle() {
    final previouslyOpen = cycles.where((c) => c.status == CycleStatus.open).map((c) => c.id).toList();
    for (final c in cycles) {
      if (c.status == CycleStatus.open) c.status = CycleStatus.closed;
    }
    final last = cycles.isNotEmpty ? cycles.first : null;
    final start = (last?.weekEnd ?? DateTime.now()).add(const Duration(days: 1));
    final end = start.add(const Duration(days: 6));
    final num = int.tryParse((last?.title ?? '23').replaceAll(RegExp(r'[^0-9]'), '')) ?? 23;
    final cycle = OrderCycle(
      id: 'CY-${num + 1}',
      title: 'Week ${num + 1}',
      weekStart: start,
      weekEnd: end,
      status: CycleStatus.open,
      shareToken: _token(),
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
    items.addAll([
      Item(id: 'I1', name: 'Basmati Rice', emoji: '🍚', category: 'Grains', unit: 'kg', openingQty: 1200, currentQty: 920, reorderLevel: 300),
      Item(id: 'I2', name: 'Wheat Flour (Atta)', emoji: '🌾', category: 'Grains', unit: 'kg', openingQty: 800, currentQty: 540, reorderLevel: 200),
      Item(id: 'I3', name: 'Toor Dal', emoji: '🫘', category: 'Pulses', unit: 'kg', openingQty: 400, currentQty: 150, reorderLevel: 160),
      Item(id: 'I4', name: 'Chana Dal', emoji: '🟡', category: 'Pulses', unit: 'kg', openingQty: 300, currentQty: 210, reorderLevel: 100),
      Item(id: 'I5', name: 'Potato', emoji: '🥔', category: 'Vegetables', unit: 'kg', openingQty: 600, currentQty: 430, reorderLevel: 150),
      Item(id: 'I6', name: 'Onion', emoji: '🧅', category: 'Vegetables', unit: 'kg', openingQty: 500, currentQty: 205, reorderLevel: 150),
      Item(id: 'I7', name: 'Tomato', emoji: '🍅', category: 'Vegetables', unit: 'kg', openingQty: 300, currentQty: 70, reorderLevel: 90),
      Item(id: 'I8', name: 'Green Chilli', emoji: '🌶️', category: 'Vegetables', unit: 'kg', openingQty: 60, currentQty: 11, reorderLevel: 16),
      Item(id: 'I9', name: 'Carrot', emoji: '🥕', category: 'Vegetables', unit: 'kg', openingQty: 180, currentQty: 96, reorderLevel: 50),
      Item(id: 'I10', name: 'Banana', emoji: '🍌', category: 'Fruits', unit: 'dozen', openingQty: 200, currentQty: 42, reorderLevel: 55),
      Item(id: 'I11', name: 'Apple', emoji: '🍎', category: 'Fruits', unit: 'kg', openingQty: 250, currentQty: 175, reorderLevel: 60),
      Item(id: 'I12', name: 'Orange', emoji: '🍊', category: 'Fruits', unit: 'kg', openingQty: 200, currentQty: 130, reorderLevel: 50),
      Item(id: 'I13', name: 'Milk', emoji: '🥛', category: 'Dairy', unit: 'litre', openingQty: 400, currentQty: 250, reorderLevel: 110),
      Item(id: 'I14', name: 'Eggs', emoji: '🥚', category: 'Dairy', unit: 'dozen', openingQty: 350, currentQty: 120, reorderLevel: 100),
      Item(id: 'I15', name: 'Paneer', emoji: '🧀', category: 'Dairy', unit: 'kg', openingQty: 120, currentQty: 64, reorderLevel: 45),
      Item(id: 'I16', name: 'Bread', emoji: '🍞', category: 'Bakery', unit: 'packet', openingQty: 300, currentQty: 0, reorderLevel: 60),
      Item(id: 'I17', name: 'Butter', emoji: '🧈', category: 'Dairy', unit: 'kg', openingQty: 90, currentQty: 58, reorderLevel: 30),
      Item(id: 'I18', name: 'Cooking Oil', emoji: '🛢️', category: 'Essentials', unit: 'litre', openingQty: 300, currentQty: 235, reorderLevel: 80),
      Item(id: 'I19', name: 'Sugar', emoji: '🍬', category: 'Essentials', unit: 'kg', openingQty: 250, currentQty: 188, reorderLevel: 70),
      Item(id: 'I20', name: 'Tea', emoji: '🍵', category: 'Essentials', unit: 'kg', openingQty: 80, currentQty: 22, reorderLevel: 26),
      Item(id: 'I21', name: 'Salt', emoji: '🧂', category: 'Essentials', unit: 'kg', openingQty: 150, currentQty: 118, reorderLevel: 40),
    ]);

    users.addAll(const [
      AppUser(id: 'U1', name: 'Arjun Mehta', role: UserRole.admin, phone: '+91 98200 11001', unit: 'Central Store'),
      AppUser(id: 'U2', name: 'Priya Nair', role: UserRole.worker, phone: '+91 98200 11002', unit: 'Store Floor'),
      AppUser(id: 'U3', name: 'Rahul Verma', role: UserRole.worker, phone: '+91 98200 11003', unit: 'Store Floor'),
      AppUser(id: 'U4', name: 'Alpha Mess', role: UserRole.customer, phone: '+91 90000 22001', unit: 'Block A'),
      AppUser(id: 'U5', name: 'Bravo Mess', role: UserRole.customer, phone: '+91 90000 22002', unit: 'Block B'),
      AppUser(id: 'U6', name: 'Delta Canteen', role: UserRole.customer, phone: '+91 90000 22003', unit: 'Block D'),
      AppUser(id: 'U7', name: 'Charlie Galley', role: UserRole.customer, phone: '+91 90000 22004', unit: 'Block C'),
    ]);

    cycles.addAll([
      OrderCycle(id: 'CY-23', title: 'Week 23', weekStart: DateTime(2026, 6, 9), weekEnd: DateTime(2026, 6, 15), status: CycleStatus.open, shareToken: 'wk23a7f3'),
      OrderCycle(id: 'CY-22', title: 'Week 22', weekStart: DateTime(2026, 5, 26), weekEnd: DateTime(2026, 6, 1), status: CycleStatus.closed, shareToken: 'wk22b1c9'),
      OrderCycle(id: 'CY-21', title: 'Week 21', weekStart: DateTime(2026, 5, 19), weekEnd: DateTime(2026, 5, 25), status: CycleStatus.closed, shareToken: 'wk21d4e2'),
    ]);

    final now = DateTime.now();
    orders.addAll([
      Order(
        id: 'ORD-${_orderSeq++}',
        cycleId: 'CY-23',
        customerName: 'Alpha Mess',
        customerPhone: '+91 90000 22001',
        status: OrderStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 3)),
        lines: const [
          OrderLine(itemId: 'I1', name: 'Basmati Rice', emoji: '🍚', unit: 'kg', qty: 40),
          OrderLine(itemId: 'I13', name: 'Milk', emoji: '🥛', unit: 'litre', qty: 30),
          OrderLine(itemId: 'I14', name: 'Eggs', emoji: '🥚', unit: 'dozen', qty: 12),
        ],
      ),
      Order(
        id: 'ORD-${_orderSeq++}',
        cycleId: 'CY-23',
        customerName: 'Bravo Mess',
        customerPhone: '+91 90000 22002',
        status: OrderStatus.pending,
        createdAt: now.subtract(const Duration(hours: 6)),
        lines: const [
          OrderLine(itemId: 'I5', name: 'Potato', emoji: '🥔', unit: 'kg', qty: 25),
          OrderLine(itemId: 'I6', name: 'Onion', emoji: '🧅', unit: 'kg', qty: 20),
          OrderLine(itemId: 'I18', name: 'Cooking Oil', emoji: '🛢️', unit: 'litre', qty: 10),
        ],
      ),
      Order(
        id: 'ORD-${_orderSeq++}',
        cycleId: 'CY-23',
        customerName: 'Delta Canteen',
        customerPhone: '+91 90000 22003',
        status: OrderStatus.fulfilled,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        lines: const [
          OrderLine(itemId: 'I2', name: 'Wheat Flour (Atta)', emoji: '🌾', unit: 'kg', qty: 30),
          OrderLine(itemId: 'I11', name: 'Apple', emoji: '🍎', unit: 'kg', qty: 15),
        ],
      ),
    ]);
  }
}
