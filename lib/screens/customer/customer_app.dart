import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_prefs.dart';
import '../../utils/notification_service.dart';
import '../../widgets/ui_kit.dart';
import '../entry_screen.dart';
import 'customer_auth.dart';
import 'order_form.dart';

/// The customer-facing app: Home, Order, My Orders, Profile.
class CustomerShell extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String address;
  const CustomerShell({super.key, required this.name, required this.phone, this.email = '', this.address = ''});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> with WidgetsBindingObserver {
  int _index = 0;
  int _seenBroadcasts = 0;
  // Only broadcasts that arrive AFTER this moment trigger a notification, so
  // reopening the app never re-fires alerts for messages already on file.
  final DateTime _sessionStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<AppStore>();
      _seenBroadcasts = store.customerBroadcasts.length;
      store.addListener(_onStoreUpdate);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<AppStore>().removeListener(_onStoreUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pull fresh data whenever the app returns to the foreground, so an admin
    // closing the link / new orders / notifications reflect even if a realtime
    // event was missed while backgrounded.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppStore>().reload();
    }
  }

  void _onStoreUpdate() {
    if (!mounted) return;
    final store = context.read<AppStore>();
    if (store.customerBroadcasts.length <= _seenBroadcasts) {
      _seenBroadcasts = store.customerBroadcasts.length;
      return;
    }
    final b = store.customerBroadcasts.first;
    _seenBroadcasts = store.customerBroadcasts.length;
    if (!b.inApp) return;
    // Skip broadcasts created before this app session (avoids re-notifying old
    // messages that simply loaded from the server on open).
    if (!b.sentAt.isAfter(_sessionStart)) return;
    // Status-bar notification (works even when the app is in the background).
    NotificationService.show(b.title, b.body);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            if (b.itemEmoji != null) Text(b.itemEmoji!, style: const TextStyle(fontSize: 22)),
            if (b.itemEmoji != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(b.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _HomeTab(name: widget.name, phone: widget.phone, onOrderNow: () => setState(() => _index = 1)),
      OrderForm(name: widget.name, phone: widget.phone),
      _MyOrdersTab(name: widget.name, phone: widget.phone, onOrderNow: () => setState(() => _index = 1)),
      _ProfileTab(name: widget.name, phone: widget.phone, email: widget.email, address: widget.address),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(name: widget.name, phone: widget.phone),
            Expanded(child: IndexedStack(index: _index, children: tabs)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_shopping_cart_outlined), selectedIcon: Icon(Icons.add_shopping_cart_rounded), label: 'Order'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'My Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String name;
  final String phone;
  const _TopBar({required this.name, required this.phone});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final theme = context.watch<ThemeController>();
    final store = context.watch<AppStore>();
    final hasUpdates = _customerUpdates(store, name, phone).isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outline))),
      child: Row(
        children: [
          const BrandMark(size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('StockFlow', style: t.titleMedium),
                Text(store.storeName, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(onPressed: theme.toggle, icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          Stack(clipBehavior: Clip.none, children: [
            IconButton(onPressed: () => _showNotifs(context, store, name, phone), icon: const Icon(Icons.notifications_none_rounded)),
            if (hasUpdates)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 1.5)),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  void _showNotifs(BuildContext context, AppStore store, String name, String phone) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _NotifsSheet(store: store, name: name, phone: phone),
    );
  }
}

/// Notifications list — swipe a row left/right to dismiss it (stays dismissed).
class _NotifsSheet extends StatefulWidget {
  final AppStore store;
  final String name;
  final String phone;
  const _NotifsSheet({required this.store, required this.name, required this.phone});

  @override
  State<_NotifsSheet> createState() => _NotifsSheetState();
}

class _NotifsSheetState extends State<_NotifsSheet> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final notifs = _customerUpdates(widget.store, widget.name, widget.phone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.brand),
            const SizedBox(width: 8),
            Text('Notifications', style: t.titleLarge),
            const Spacer(),
            if (notifs.isNotEmpty)
              TextButton(
                onPressed: () {
                  for (final u in notifs) {
                    DismissedNotifs.add(u.id);
                  }
                  setState(() {});
                },
                child: const Text('Clear all'),
              ),
          ]),
          const SizedBox(height: 4),
          if (notifs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: EmptyState(icon: Icons.notifications_none_rounded, title: 'No notifications', subtitle: "You're all caught up."),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final u in notifs)
                    Dismissible(
                      key: ValueKey(u.id),
                      onDismissed: (_) {
                        DismissedNotifs.add(u.id);
                        setState(() {});
                      },
                      background: _swipeBg(Alignment.centerLeft),
                      secondaryBackground: _swipeBg(Alignment.centerRight),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 36, height: 36, decoration: BoxDecoration(color: u.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.sm)), child: Icon(u.icon, color: u.color, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u.title, style: t.titleSmall), Text(u.body, style: t.bodySmall)])),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _swipeBg(Alignment alignment) => Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      );
}

class _Update {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Update(this.id, this.icon, this.color, this.title, this.body);
}

List<_Update> _customerUpdates(AppStore store, String name, String phone) {
  final cycle = store.activeCycle;
  final open = cycle.status == CycleStatus.open;
  final orders = _customerOrders(store, name, phone);
  final dismissed = DismissedNotifs.load();
  final out = <_Update>[];
  for (final b in store.customerBroadcasts.take(8)) {
    if (!b.inApp) continue;
    out.add(_Update(
      'bc-${b.id}',
      Icons.campaign_rounded,
      AppColors.brand,
      b.title,
      b.itemEmoji != null ? '${b.itemEmoji} ${b.body}' : b.body,
    ));
  }
  if (open) {
    out.add(_Update('cycle-open-${cycle.id}', Icons.campaign_rounded, AppColors.brand,
        '${cycle.title} order link is open', 'Place your order before it closes.'));
  }
  for (final o in orders.take(5)) {
    out.add(_Update(
      'order-${o.id}-${o.status.name}',
      o.status == OrderStatus.fulfilled ? Icons.check_circle_rounded : Icons.local_shipping_rounded,
      orderStatusColor(o.status),
      'Order ${o.id} is ${orderStatusLabel(o.status).toLowerCase()}',
      '${o.itemCount} items · ${relTime(o.createdAt)}',
    ));
  }
  return out.where((u) => !dismissed.contains(u.id)).toList();
}

// ---------------- Home helpers ----------------

String _homeDisplayName(String name) {
  final n = name.trim();
  if (n.isEmpty || n.contains('@')) return 'there';
  // Email-prefix style (no spaces, has dots/digits): extract leading alpha chars
  if (!n.contains(' ') && n.contains(RegExp(r'[._\d]'))) {
    final m = RegExp(r'^[a-zA-Z]+').firstMatch(n);
    if (m != null && m.group(0)!.length >= 2) {
      final s = m.group(0)!;
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }
    final first = n.split(RegExp(r'[._]')).first;
    if (first.isNotEmpty) return first[0].toUpperCase() + first.substring(1);
  }
  return n;
}

String _timeGreeting() {
  final h = DateTime.now().hour;
  if (h < 6) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

IconData _greetIcon() {
  final h = DateTime.now().hour;
  if (h < 6) return Icons.bedtime_rounded;
  if (h < 12) return Icons.wb_sunny_rounded;
  if (h < 17) return Icons.wb_cloudy_rounded;
  return Icons.nights_stay_rounded;
}

String _normPhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

bool _orderBelongsToCustomer(Order o, String name, String phone) {
  if (o.customerName.trim().toLowerCase() == name.trim().toLowerCase()) return true;
  final np = _normPhone(phone);
  if (np.length < 6) return false;
  return _normPhone(o.customerPhone) == np;
}

/// All orders belonging to this customer (by name or phone), newest first.
/// No date cutoff — orders persist in the DB and must always be visible.
List<Order> _customerOrders(AppStore store, String name, String phone) {
  final list = store.orders.where((o) => _orderBelongsToCustomer(o, name, phone)).toList();
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return list;
}

/// Totals per item across this customer's orders.
Map<String, ({String name, String emoji, String unit, double qty})> _consumptionByItem(List<Order> orders) {
  final map = <String, ({String name, String emoji, String unit, double qty})>{};
  for (final o in orders) {
    for (final l in o.lines) {
      final prev = map[l.itemId];
      map[l.itemId] = (
        name: l.name,
        emoji: l.emoji,
        unit: l.unit,
        qty: (prev?.qty ?? 0) + l.qty,
      );
    }
  }
  return map;
}

Map<String, double> _categoryTotals(List<Order> orders, AppStore store) {
  final map = <String, double>{};
  for (final o in orders) {
    for (final l in o.lines) {
      final cat = store.items.where((i) => i.id == l.itemId).map((i) => i.category).firstOrNull ?? 'Other';
      map[cat] = (map[cat] ?? 0) + l.qty;
    }
  }
  return map;
}

double _itemQtyInCycle(List<Order> orders, String cycleId, String itemId) {
  var total = 0.0;
  for (final o in orders.where((x) => x.cycleId == cycleId)) {
    for (final l in o.lines) {
      if (l.itemId == itemId) total += l.qty;
    }
  }
  return total;
}

(String currentId, String? previousId) _recentCyclePair(AppStore store) {
  final sorted = [...store.cycles]..sort((a, b) => b.weekStart.compareTo(a.weekStart));
  if (sorted.isEmpty) return ('', null);
  return (sorted.first.id, sorted.length > 1 ? sorted[1].id : null);
}

// ---------------- Home ----------------

class _HomeTab extends StatelessWidget {
  final String name;
  final String phone;
  final VoidCallback onOrderNow;
  const _HomeTab({required this.name, required this.phone, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final canOrder = store.canPlaceOrders;
    final displayName = _homeDisplayName(name);
    final accountSince = SavedProfile.load()?.accountCreatedAt;
    final myOrders = _customerOrders(store, name, phone);
    final lastOrder = myOrders.isNotEmpty ? myOrders.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeGreeting(name: displayName),
              const SizedBox(height: 14),
              _OrderStatusCard(store: store, onOrderNow: onOrderNow),
              const SizedBox(height: 14),
              _AvailableItemsCard(store: store, onOrderNow: onOrderNow),
              const SizedBox(height: 14),
              _CustomerActivityCard(store: store, orders: myOrders, accountSince: accountSince),
              if (myOrders.isEmpty) ...[
                const SizedBox(height: 14),
                const _HowToOrderCard(),
              ],
              if (canOrder && myOrders.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ReorderShortcuts(orders: myOrders, onOrderNow: onOrderNow),
              ],
              if (lastOrder != null) ...[
                const SizedBox(height: 14),
                _LastOrderStrip(order: lastOrder),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  final String name;
  const _HomeGreeting({required this.name});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final greet = _timeGreeting();
    final dateLine = DateFormat('EEEE, d MMM').format(DateTime.now());
    final showName = name != 'there';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF1A3D2E), const Color(0xFF0F1F18)]
              : [AppColors.brandWash, scheme.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greet,
                  style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  showName ? '$name  ·  $dateLine' : dateLine,
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: 0.07) : AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_greetIcon(), color: AppColors.brand, size: 22),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic);
  }
}

class _OrderStatusCard extends StatelessWidget {
  final AppStore store;
  final VoidCallback onOrderNow;
  const _OrderStatusCard({required this.store, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cycle = store.orderingCycle;
    final open = store.canPlaceOrders;
    final closeLine = DateFormat('d MMM').format(cycle.weekEnd);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = open
        ? (dark ? [AppColors.brandLight, AppColors.brand] : [AppColors.brand, AppColors.brandDark])
        : (dark ? [const Color(0xFF2A3532), const Color(0xFF1A2421)] : [const Color(0xFF6B7B75), const Color(0xFF3C4B46)]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: open ? const Color(0xFF7CFFB2) : Colors.white54,
                  shape: BoxShape.circle,
                  boxShadow: open ? [BoxShadow(color: const Color(0xFF7CFFB2).withValues(alpha: 0.6), blurRadius: 6)] : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                open ? 'LIVE · ${cycle.title}' : '${cycle.title.isEmpty ? 'Ordering' : cycle.title} · CLOSED',
                style: t.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92), letterSpacing: 1.1, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            open ? 'Order window is open' : 'Order window is closed',
            style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            open
                ? 'Closes $closeLine, 11:59 PM'
                : "This week's ordering has closed. You'll be notified when the next window opens.",
            style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
          ),
          if (open) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.brandDark),
                onPressed: onOrderNow,
                child: const Text('Place order'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Customer ordering activity — bar pillars, categories, and week-over-week trends.
class _CustomerActivityCard extends StatelessWidget {
  final AppStore store;
  final List<Order> orders;
  final DateTime? accountSince;
  const _CustomerActivityCard({required this.store, required this.orders, this.accountSince});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final byItem = _consumptionByItem(orders);
    final itemEntries = byItem.entries.toList()..sort((a, b) => b.value.qty.compareTo(a.value.qty));
    final entries = itemEntries.map((e) => e.value).toList();
    final totalQty = entries.fold<double>(0, (s, e) => s + e.qty);
    final sinceLine = accountSince != null ? 'Since ${DateFormat('d MMM yyyy').format(accountSince!)}' : 'Since account created';
    final (currentCycle, previousCycle) = _recentCyclePair(store);
    final categories = _categoryTotals(orders, store);
    final catEntries = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    final maxY = top.fold<double>(1, (m, e) => e.qty > m ? e.qty : m) * 1.15;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights_rounded, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your ordering activity', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(sinceLine, style: t.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Place your first order to see what you buy most.', style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ActivityStat(value: '${orders.length}', label: orders.length == 1 ? 'order' : 'orders'),
                _ActivityStat(value: '${entries.length}', label: entries.length == 1 ? 'item' : 'items'),
                _ActivityStat(value: fmtNum(totalQty), label: 'total qty'),
              ],
            ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Top items ordered', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SizedBox(
                height: 168,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                          fmtNum(rod.toY),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, m) => Text(fmtNum(v), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i < 0 || i >= top.length) return const SizedBox.shrink();
                            final label = top[i].emoji;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(label, style: const TextStyle(fontSize: 16)),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (v) => FlLine(color: scheme.outline.withValues(alpha: 0.35), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < top.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: top[i].qty,
                              color: AppColors.brand,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (catEntries.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('By category', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...catEntries.take(5).map((e) {
                final cat = categoryOf(e.key);
                final share = (e.value / catEntries.first.value).clamp(0.08, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 16, color: cat.color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key, style: t.bodyMedium)),
                      Text(fmtNum(e.value), style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: share, minHeight: 6, color: cat.color, backgroundColor: scheme.surfaceContainerHighest),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 6),
            Text('What you buy more', style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...itemEntries.take(8).map((kv) {
              final e = kv.value;
              final itemId = kv.key;
              final nowQty = currentCycle.isNotEmpty ? _itemQtyInCycle(orders, currentCycle, itemId) : e.qty;
              final prevQty = previousCycle != null ? _itemQtyInCycle(orders, previousCycle, itemId) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(e.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.name, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    _TrendBadge(current: nowQty, previous: prevQty),
                    const SizedBox(width: 10),
                    Text(fmtQty(e.qty, e.unit), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  final String value;
  final String label;
  const _ActivityStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary)),
          Text(label, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double current;
  final double previous;
  const _TrendBadge({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    if (previous <= 0 && current <= 0) return const SizedBox.shrink();
    final up = current >= previous;
    final color = up ? AppColors.success : AppColors.danger;
    final icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    String label;
    if (previous <= 0) {
      label = 'new';
    } else {
      final pct = ((current - previous) / previous * 100).abs();
      label = '${pct.round()}%';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Shortcuts to re-order items this customer buys most.
class _ReorderShortcuts extends StatelessWidget {
  final List<Order> orders;
  final VoidCallback onOrderNow;
  const _ReorderShortcuts({required this.orders, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final top = _consumptionByItem(orders).values.toList()..sort((a, b) => b.qty.compareTo(a.qty));
    final picks = top.take(4).toList();
    if (picks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order again', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...picks.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: onOrderNow,
                child: Row(
                  children: [
                    Text(e.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: t.titleSmall),
                          Text('You ordered ${fmtQty(e.qty, e.unit)} total', style: t.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}


class _LastOrderStrip extends StatelessWidget {
  final Order order;
  const _LastOrderStrip({required this.order});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: scheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last order · ${order.id}', style: t.titleSmall),
                Text('${order.itemCount} items · ${orderStatusLabel(order.status)}', style: t.bodySmall),
              ],
            ),
          ),
          Pill(orderStatusLabel(order.status), color: orderStatusColor(order.status)),
        ],
      ),
    );
  }
}

// ---------------- Available items ----------------

class _AvailableItemsCard extends StatelessWidget {
  final AppStore store;
  final VoidCallback onOrderNow;
  const _AvailableItemsCard({required this.store, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final available = store.items.where((i) => i.currentQty > 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (available.isEmpty) return const SizedBox.shrink();

    final preview = available.take(10).toList();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_rounded, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available this week', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${available.length} items in stock', style: t.bodySmall),
                  ],
                ),
              ),
              if (store.canPlaceOrders)
                TextButton(
                  onPressed: onOrderNow,
                  child: const Text('Order now'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in preview)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 17)),
                        const SizedBox(width: 6),
                        Text(item.name, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Text(fmtQty(item.currentQty, item.unit),
                            style: t.bodySmall?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                if (available.length > 10)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.brandWash,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text('+${available.length - 10} more',
                          style: t.bodySmall?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- How to order ----------------

class _HowToOrderCard extends StatelessWidget {
  const _HowToOrderCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How ordering works', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _OrderStep(
            step: 1,
            icon: Icons.event_rounded,
            title: 'Order window opens',
            subtitle: 'A new order link is published each week',
            color: AppColors.brand,
          ),
          _OrderStep(
            step: 2,
            icon: Icons.shopping_cart_rounded,
            title: 'Pick your items',
            subtitle: 'Browse stock and set quantities for your unit',
            color: AppColors.accent,
          ),
          _OrderStep(
            step: 3,
            icon: Icons.check_circle_rounded,
            title: 'Review and confirm',
            subtitle: 'Submit before the deadline — done',
            color: AppColors.success,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _OrderStep extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool last;
  const _OrderStep({required this.step, required this.icon, required this.title, required this.subtitle, required this.color, this.last = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(icon, size: 18, color: color),
          ),
          if (!last)
            Container(width: 2, height: 28, color: scheme.outline.withValues(alpha: 0.4)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- My Orders ----------------

class _MyOrdersTab extends StatelessWidget {
  final String name;
  final String phone;
  final VoidCallback onOrderNow;
  const _MyOrdersTab({required this.name, required this.phone, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context).textTheme;
    final orders = _customerOrders(store, name, phone);

    // Group orders by their cycle (week), newest week first.
    final byCycle = <String, List<Order>>{};
    for (final o in orders) {
      byCycle.putIfAbsent(o.cycleId, () => []).add(o);
    }
    final cycleOrder = store.cyclesByRecent.map((c) => c.id).toList();
    final groupedIds = byCycle.keys.toList()
      ..sort((a, b) {
        final ia = cycleOrder.indexOf(a);
        final ib = cycleOrder.indexOf(b);
        return (ia == -1 ? 9999 : ia).compareTo(ib == -1 ? 9999 : ib);
      });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Orders', style: t.headlineSmall),
              const SizedBox(height: 4),
              Text('Your orders grouped by week, with status', style: t.bodyMedium),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: Column(children: [
                    const EmptyState(icon: Icons.receipt_long_rounded, title: 'No orders yet', subtitle: 'Place your first order to see it here.'),
                    const SizedBox(height: 12),
                    if (store.canPlaceOrders)
                      FilledButton.icon(onPressed: onOrderNow, icon: const Icon(Icons.add_shopping_cart_rounded, size: 18), label: const Text('Start an order')),
                  ]),
                )
              else
                ...groupedIds.map((cid) => _WeekGroup(
                      store: store,
                      cycleId: cid,
                      orders: byCycle[cid]!..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
                    )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// One week's worth of orders with a header showing the week + live/closed state.
class _WeekGroup extends StatelessWidget {
  final AppStore store;
  final String cycleId;
  final List<Order> orders;
  const _WeekGroup({required this.store, required this.cycleId, required this.orders});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cycle = store.cycles.where((c) => c.id == cycleId).firstOrNull;
    final title = cycle?.title ?? 'Earlier orders';
    final open = cycle?.status == CycleStatus.open;
    final range = cycle != null
        ? '${DateFormat('d MMM').format(cycle.weekStart)} – ${DateFormat('d MMM').format(cycle.weekEnd)}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week header
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    if (range != null) Text(range, style: t.bodySmall),
                  ],
                ),
              ),
              Pill(open ? 'Live' : 'Closed', color: open ? AppColors.success : scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 10),
          ...orders.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.id, style: t.titleSmall),
                              const SizedBox(height: 2),
                              Text(DateFormat('EEE, d MMM · h:mm a').format(o.createdAt.toLocal()),
                                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Pill(orderStatusLabel(o.status), color: orderStatusColor(o.status)),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final l in o.lines)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.pill)),
                            child: Text('${l.emoji} ${l.name} · ${fmtQty(l.qty, l.unit)}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                      ]),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------- Profile ----------------

class _ProfileTab extends StatelessWidget {
  final String name;
  final String phone;
  final String email;
  final String address;
  const _ProfileTab({required this.name, required this.phone, required this.email, required this.address});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final theme = context.watch<ThemeController>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(children: [
                  CircleAvatar(radius: 36, backgroundColor: AppColors.brand, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28))),
                  const SizedBox(height: 12),
                  Text(name, style: t.titleLarge),
                  Text('Customer account', style: t.bodyMedium),
                ]),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(children: [
                  _row(context, Icons.phone_rounded, 'Phone', phone.isEmpty ? 'Not set' : phone),
                  const Divider(height: 20),
                  _row(context, Icons.mail_outline_rounded, 'Email', email.isEmpty ? 'Not set' : email),
                  const Divider(height: 20),
                  _row(context, Icons.location_on_outlined, 'Delivery address', address.isEmpty ? 'Not set' : address),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: SwitchListTile(
                  value: theme.isDark,
                  onChanged: (_) => theme.toggle(),
                  secondary: Icon(theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.brand),
                  title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final store = context.read<AppStore>();
                    SavedProfile.clear();
                    await store.signOut();
                    if (!context.mounted) return;
                    if (kIsWeb) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const CustomerRegister()),
                        (r) => false,
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: t.bodyMedium),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: t.titleSmall, textAlign: TextAlign.end)),
      ],
    );
  }
}
