import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/app_prefs.dart';
import '../utils/customer_orders.dart';
import '../utils/entitlement_import.dart';
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
  //
  // A zone is the customer's designation (Officers, Commanders, …). Each holds
  // its own per-day entitlement scale, so Zone A and Zone B differ. Only the
  // real Officers sheet ships with the app; the admin creates further zones and
  // fills them from their own Excel.
  final Map<String, RationZone> _zones = {
    for (final z in kRationZones) z.name: z.copyWith(perDay: Map<String, double>.of(z.perDay)),
  };

  List<String> get zoneNames => _zones.keys.toList();

  /// The current (possibly admin-edited) criteria for a zone.
  RationZone zoneFor(String name) {
    final key = _zones.keys.firstWhere(
      (k) => k.toLowerCase() == name.trim().toLowerCase(),
      orElse: () => '',
    );
    if (key.isNotEmpty) return _zones[key]!;
    return _zones.values.isNotEmpty ? _zones.values.first : kOfficersZone;
  }

  /// Create a new designation/zone, optionally starting from an existing scale.
  /// Returns false when the name is blank or already taken.
  bool addZone(String name, {String? copyFrom}) {
    final n = name.trim();
    if (n.isEmpty) return false;
    if (_zones.keys.any((k) => k.toLowerCase() == n.toLowerCase())) return false;
    final base = copyFrom != null ? zoneFor(copyFrom) : kOfficersZone;
    _zones[n] = RationZone(
      name: n,
      level: n,
      perDay: Map<String, double>.of(base.perDay),
      itemMax: Map<String, double>.of(base.itemMax),
    );
    notifyListeners();
    return true;
  }

  /// Remove a zone. The last remaining zone can't be deleted.
  void removeZone(String name) {
    if (_zones.length <= 1) return;
    _zones.remove(name);
    notifyListeners();
  }

  /// Set a category's per-person-per-day entitlement for a zone. Every allowance
  /// (a 10-day demand, a whole month) is derived from this rate.
  void setZonePerDay(String zone, String category, double perDay) {
    final z = zoneFor(zone);
    final next = Map<String, double>.of(z.perDay)..[category] = perDay < 0 ? 0 : perDay;
    _zones[z.name] = z.copyWith(perDay: next);
    notifyListeners();
  }

  void setZoneItemMax(String zone, String itemName, double value) {
    final z = zoneFor(zone);
    final next = Map<String, double>.of(z.itemMax);
    if (value <= 0) {
      next.remove(itemName);
    } else {
      next[itemName] = value;
    }
    _zones[z.name] = z.copyWith(itemMax: next);
    notifyListeners();
  }

  /// Apply an entitlement sheet (the unit's Excel) to a zone.
  EntitlementImportSummary importEntitlement(String zone, List<EntitlementRow> rows) {
    if (rows.isEmpty) return const EntitlementImportSummary(updated: 0, skipped: 0);
    final z = zoneFor(zone);
    final perDay = Map<String, double>.of(z.perDay);
    var updated = 0;
    var skipped = 0;
    for (final r in rows) {
      if (r.category.isEmpty) {
        skipped++;
        continue;
      }
      perDay[r.category] = r.perDay;
      updated++;
    }
    _zones[z.name] = z.copyWith(perDay: perDay);
    notifyListeners();
    return EntitlementImportSummary(updated: updated, skipped: skipped);
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

  /// Load the in-memory demo catalogue (RIK Officers scale + sample demands).
  /// Normally the constructor seeds this when Supabase isn't configured; this
  /// lets tests and offline demos seed on demand. No-op once data exists.
  @visibleForTesting
  void seedDemoData() {
    if (items.isEmpty) _seed();
  }

  Timer? _reloadDebounce;
  bool _reloading = false; // guard: prevents overlapping network calls

  /// Connect to Supabase: restore session, load real data + subscribe to live changes.
  ///
  /// Realtime events are debounced: a bulk import fires one event per changed
  /// row, and refetching everything for each of them made the UI "reload again
  /// and again". One trailing reload covers the whole burst.
  Future<void> connectSupabase(SupabaseService sb) async {
    _sb = sb;
    await sb.restoreSession();
    _bootstrapped = true;
    // reload() will call notifyListeners() once everything is fetched —
    // no need for an extra notifyListeners() here that would cause a blank flash.
    await reload();
    sb.subscribe(() {
      _reloadDebounce?.cancel();
      _reloadDebounce = Timer(const Duration(milliseconds: 700), () => reload());
    });
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
    await reload(); // reload() calls notifyListeners() — no extra call needed
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
    await reload(); // reload() calls notifyListeners() — no extra call needed
  }

  /// Pull the latest data from Supabase into the local cache.
  Future<void> reload() async {
    final sb = _sb;
    if (sb == null) return;
    // If a reload is already in flight, skip — the in-flight one will call
    // notifyListeners() when it finishes, so the UI won't miss anything.
    if (_reloading) return;
    _reloading = true;
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
    } finally {
      _reloading = false;
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

  // ---- Entitlement ledger -------------------------------------------------
  //
  // The customer is never shown warehouse stock. What they see — and what caps
  // their order — is their own balance for the month:
  //
  //     balance(category) = allowance + carriedIn − consumed
  //
  // Because the balance is held per category and shared by every demand in the
  // month, bread taken on a fresh demand is spent out of the same Cereals
  // balance the dry demand later draws on (carry-forward *within* the month),
  // and whatever is left at month end is added on top of next month's allowance
  // (carry-forward *to the next month*: 500 + 300 = 800).

  /// Never walk back further than this when rolling carry-forward forward — a
  /// stale clock or bad data shouldn't spin the loop.
  static const int _maxCarryMonths = 36;

  /// The entitlement month an order was placed against (its demand's month,
  /// falling back to when it was placed if the demand is gone).
  RationMonth monthOfOrder(Order o) {
    final c = cycles.where((x) => x.id == o.cycleId);
    if (c.isNotEmpty) return c.first.month;
    return RationMonth.of(o.createdAt);
  }

  /// The RIK category an order line belongs to. Resolves by item id, then by
  /// name (the item may have been renamed or removed), then via the RIK sheet.
  String? categoryOfLine(OrderLine line) {
    final byId = items.where((i) => i.id == line.itemId);
    if (byId.isNotEmpty) return byId.first.category;
    final byName = items.where((i) => i.name.toLowerCase() == line.name.toLowerCase());
    if (byName.isNotEmpty) return byName.first.category;
    return rikCategoryForArticle(line.name);
  }

  /// Quantity ordered per category, per month, for one customer. Cancelled
  /// orders don't consume entitlement.
  Map<String, Map<String, double>> _consumedByMonth(String name, String phone) {
    final out = <String, Map<String, double>>{};
    for (final o in customerOrdersFor(this, name, phone)) {
      if (o.status == OrderStatus.cancelled) continue;
      final m = monthOfOrder(o).key;
      final bucket = out.putIfAbsent(m, () => <String, double>{});
      for (final l in o.lines) {
        final cat = categoryOfLine(l);
        if (cat == null) continue;
        bucket[cat] = (bucket[cat] ?? 0) + l.qty;
      }
    }
    return out;
  }

  /// What this customer has already taken in [month], per category — across
  /// every demand in that month, fresh and dry alike.
  Map<String, double> consumedByCategory(String name, String phone, RationMonth month) =>
      _consumedByMonth(name, phone)[month.key] ?? const {};

  /// Leftover rolled in from earlier months. Starts at the customer's first
  /// ordering month and rolls each month's leftover forward onto the next.
  Map<String, double> carriedInto(String name, String phone, String zone, RationMonth month) {
    final consumedByMonth = _consumedByMonth(name, phone);
    if (consumedByMonth.isEmpty) return const {};

    final months = consumedByMonth.keys.map(RationMonth.tryParse).nonNulls.toList()..sort();
    var from = months.first;
    if (!from.isBefore(month)) return const {};
    // Cap how far back we roll from, so a bad date can't spin this.
    if (from.monthsTo(month) > _maxCarryMonths) {
      from = month;
      for (var i = 0; i < _maxCarryMonths; i++) {
        from = from.previous;
      }
    }

    final z = zoneFor(zone);
    var carry = <String, double>{};
    for (var m = from; m.isBefore(month); m = m.next) {
      final consumed = consumedByMonth[m.key] ?? const <String, double>{};
      final next = <String, double>{};
      for (final c in kCategories) {
        final left = z.monthlyAllowance(c.name, m) + (carry[c.name] ?? 0) - (consumed[c.name] ?? 0);
        // Only a surplus rolls forward — an overdraw isn't carried as a debt.
        if (left > 1e-9) next[c.name] = left;
      }
      carry = next;
    }
    return carry;
  }

  /// The customer's full entitlement position for a month — one row per
  /// category. This is what the customer sees in place of stock, and what caps
  /// how much they may order. A customer who was on leave and ordered nothing
  /// simply has `consumed = 0`, so they see their entitlement in full.
  List<CategoryBalance> balancesFor({
    required String name,
    required String phone,
    required String zone,
    RationMonth? month,
  }) {
    final m = month ?? currentMonth;
    final z = zoneFor(zone);
    final consumed = consumedByCategory(name, phone, m);
    final carried = carriedInto(name, phone, zone, m);
    return [
      for (final c in kCategories)
        CategoryBalance(
          category: c.name,
          unit: rikCategoryByName(c.name)?.unit ?? 'kg',
          allowance: z.monthlyAllowance(c.name, m),
          carriedIn: carried[c.name] ?? 0,
          consumed: consumed[c.name] ?? 0,
        ),
    ];
  }

  /// One category's balance for a customer.
  CategoryBalance balanceOf({
    required String name,
    required String phone,
    required String zone,
    required String category,
    RationMonth? month,
  }) {
    final m = month ?? currentMonth;
    final z = zoneFor(zone);
    return CategoryBalance(
      category: category,
      unit: rikCategoryByName(category)?.unit ?? 'kg',
      allowance: z.monthlyAllowance(category, m),
      carriedIn: carriedInto(name, phone, zone, m)[category] ?? 0,
      consumed: consumedByCategory(name, phone, m)[category] ?? 0,
    );
  }

  /// The entitlement month "now" falls in.
  RationMonth get currentMonth => RationMonth.of(DateTime.now());

  /// The articles that appear on a demand — the admin's selection, narrowed to
  /// the demand's ration type. What isn't added here, the customer never sees.
  List<Item> itemsForCycle(OrderCycle cycle) => items.where(cycle.includes).toList();

  // ---- Mutations ----------------------------------------------------------

  Order placeOrder({
    required String customerName,
    required String customerPhone,
    required Map<String, double> cart,
    String? cycleId,
    String zone = '',
  }) {
    final targetCycleId = cycleId ?? orderingCycle.id;
    final cycle = cycles.where((c) => c.id == targetCycleId).firstOrNull;

    // Guard the entitlement balance here too, not just in the form — a page left
    // open while another demand was placed must not be able to overdraw.
    final month = cycle?.month ?? currentMonth;
    final wanted = <String, double>{};
    cart.forEach((itemId, qty) {
      if (qty <= 0) return;
      final item = items.where((i) => i.id == itemId).firstOrNull;
      if (item == null) return;
      wanted[item.category] = (wanted[item.category] ?? 0) + qty;
    });
    for (final entry in wanted.entries) {
      final bal = balanceOf(
        name: customerName,
        phone: customerPhone,
        zone: zone,
        category: entry.key,
        month: month,
      );
      if (entry.value > bal.remaining + 1e-6) {
        throw StateError(
          'Only ${_fmt(bal.remaining)} ${bal.unit} of ${entry.key} is left in your '
          '${month.label} entitlement — reduce the quantity and try again.',
        );
      }
    }

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
        // Retire the local copy from the on-device cache — its synced twin
        // replaces it, otherwise the pair shows up as two orders.
        SavedCustomerOrders.remove(customerName, customerPhone, localId);
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
    final newRows = <Map<String, dynamic>>[];
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
        // The name→icon brain wins when it's confident: a misaligned emoji
        // column in the sheet must never leave Sugar wearing a peas icon.
        final emoji = (smart.confidence >= 0.6 || r.emoji == '📦' || r.emoji.isEmpty) ? smart.emoji : r.emoji;
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
        newRows.add({
          'name': r.name,
          'emoji': emoji,
          'category': category,
          'unit': unit,
          'opening_qty': r.qty,
          'current_qty': r.qty,
          'reorder_level': r.reorder,
        });
      }
    }
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      // One bulk insert + one reload for the whole sheet.
      _fire(sb.insertItems(newRows).then((_) => reload()));
    }
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
      _fire(sb.insertUser(name: name, role: role, phone: phone, unit: unit, zone: zone).then((_) => reload()));
    }
  }

  /// Assign a customer to a zone (their designation) — this is what decides
  /// which entitlement scale and which demands apply to them.
  void setUserZone(AppUser user, String zone) {
    final i = users.indexWhere((u) => u.id == user.id);
    if (i < 0) return;
    users[i] = AppUser(
      id: user.id,
      name: user.name,
      role: user.role,
      phone: user.phone,
      unit: user.unit,
      email: user.email,
      zone: zone,
    );
    notifyListeners();
    _fire(_sb?.updateUserZone(user.id, zone));
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

  /// How many demands already exist for a month + zone — used to name the next
  /// one ("1st fresh demand", "2nd fresh demand", …).
  int demandCountIn(RationMonth month, String designation, DemandType type) => cycles
      .where((c) => c.month == month && c.designation == designation.trim() && c.type == type)
      .length;

  /// Open the demand — "we are ready to accept the demand". Until one is open,
  /// customers see "demand acceptance has not started yet" and no order page.
  ///
  /// [designation] scopes it to a zone (empty = everyone). [type] picks fresh or
  /// dry, [days] is the span it covers (5 / 10 / 15 / 30 from the unit's Excel),
  /// [month] is the entitlement month it spends from, and [itemIds] are the
  /// varieties the admin added — what isn't in there, the customer never sees.
  /// [closeOthers] false keeps existing open demands live too.
  OrderCycle openNewCycle({
    String designation = '',
    bool closeOthers = true,
    DemandType type = DemandType.fresh,
    int? days,
    RationMonth? month,
    Set<String>? itemIds,
    DateTime? start,
  }) {
    final previouslyOpen = <String>[];
    if (closeOthers) {
      for (final c in cycles) {
        if (c.status == CycleStatus.open) {
          previouslyOpen.add(c.id);
          c.status = CycleStatus.closed;
        }
      }
    }
    final m = month ?? currentMonth;
    final span = days ?? type.defaultDays;
    final label = designation.trim();

    // Fresh demands run in ~10-day slices through the month (or from the
    // week the admin picked); the dry demand covers the whole month.
    final index = demandCountIn(m, label, type);
    final begin = start ??
        (type == DemandType.dry ? m.firstDay : m.firstDay.add(Duration(days: index * span)));
    var end = begin.add(Duration(days: span - 1));
    if (end.isAfter(m.lastDay)) end = m.lastDay;

    final ordinal = _ordinal(index + 1);
    final name = '$ordinal ${type.label.toLowerCase()} demand · ${m.shortLabel}';
    final slug = label.isEmpty ? '' : '-${label.replaceAll(RegExp(r'\s+'), '').toLowerCase()}';
    final cycle = OrderCycle(
      id: 'CY-${m.key}-${type.name}-${index + 1}$slug',
      title: label.isEmpty ? name : '$name · $label',
      weekStart: begin,
      weekEnd: end,
      status: CycleStatus.open,
      shareToken: _token(),
      designation: label,
      type: type,
      days: span,
      month: m,
      itemIds: itemIds,
    );
    cycles.insert(0, cycle);
    notifyListeners();
    final sb = _sb;
    if (sb != null) {
      for (final id in previouslyOpen) {
        _fire(sb.updateCycleStatus(id, CycleStatus.closed));
      }
      _fire(sb.insertCycle(cycle).then((_) => reload()));
    }
    return cycle;
  }

  /// Replace the varieties on a demand — the admin picking, say, 9 of the 30
  /// fruit varieties. An empty set means "every article valid for this type".
  void setCycleItems(OrderCycle cycle, Set<String> itemIds) {
    final i = cycles.indexWhere((c) => c.id == cycle.id);
    if (i < 0) return;
    cycles[i] = cycle.copyWith(itemIds: itemIds);
    notifyListeners();
    _fire(_sb?.updateCycleItems(cycle.id, itemIds));
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

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
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

    // The month's demand cycle as the unit runs it: three fresh demands of
    // ~10 days each, then one dry demand covering the whole month.
    final now = DateTime.now();
    final m = RationMonth.of(now);
    final prev = m.previous;

    cycles.addAll([
      OrderCycle(
        id: 'CY-${m.key}-fresh-2', title: '2nd fresh demand · ${m.shortLabel} · Officers',
        weekStart: m.firstDay.add(const Duration(days: 10)), weekEnd: m.firstDay.add(const Duration(days: 19)),
        status: CycleStatus.open, shareToken: 'rikfresh2', designation: 'Officers',
        type: DemandType.fresh, days: 10, month: m,
      ),
      OrderCycle(
        id: 'CY-${m.key}-fresh-1', title: '1st fresh demand · ${m.shortLabel} · Officers',
        weekStart: m.firstDay, weekEnd: m.firstDay.add(const Duration(days: 9)),
        status: CycleStatus.closed, shareToken: 'rikfresh1', designation: 'Officers',
        type: DemandType.fresh, days: 10, month: m,
      ),
      OrderCycle(
        id: 'CY-${prev.key}-dry-1', title: '1st dry demand · ${prev.shortLabel} · Officers',
        weekStart: prev.firstDay, weekEnd: prev.lastDay,
        status: CycleStatus.closed, shareToken: 'rikdry0', designation: 'Officers',
        type: DemandType.dry, days: prev.days, month: prev,
      ),
    ]);

    Item pick(String name) => items.firstWhere((i) => i.name == name, orElse: () => items.first);
    OrderLine line(String name, double qty) {
      final it = pick(name);
      return OrderLine(itemId: it.id, name: it.name, emoji: it.emoji, unit: it.unit, qty: qty);
    }

    orders.addAll([
      // Fresh demand: bread comes out of the Cereals balance, so the dry demand
      // later in the month sees a smaller Cereals balance.
      Order(
        id: 'ORD-${_orderSeq++}', cycleId: 'CY-${m.key}-fresh-1', customerName: 'Wardroom Mess', customerPhone: '+91 90000 22001',
        status: OrderStatus.confirmed, createdAt: m.firstDay.add(const Duration(days: 1)),
        lines: [line('Brown Bread 400 g', 1.2), line('Meat Fresh 1 kg', 1.5), line('Tomato', 1), line('Eggs', 14)],
      ),
      Order(
        id: 'ORD-${_orderSeq++}', cycleId: 'CY-${m.key}-fresh-1', customerName: 'Lt Bravo', customerPhone: '+91 90000 22002',
        status: OrderStatus.pending, createdAt: m.firstDay.add(const Duration(days: 2)),
        lines: [line('Potato', 0.75), line('Onion', 0.4), line('Apple Delicious', 1.6)],
      ),
      // Last month's dry demand — its leftover carries into this month.
      Order(
        id: 'ORD-${_orderSeq++}', cycleId: 'CY-${prev.key}-dry-1', customerName: 'Lt Cdr Delta', customerPhone: '+91 90000 22003',
        status: OrderStatus.fulfilled, createdAt: prev.firstDay.add(const Duration(days: 3)),
        lines: [line('India Gate Rozana 1 kg', 3), line('Dal Arhar 400 g', 0.8)],
      ),
    ]);
  }
}
