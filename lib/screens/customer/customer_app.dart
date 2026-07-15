import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_prefs.dart';
import '../../utils/customer_orders.dart';
import '../../utils/notification_service.dart';
import '../../widgets/ui_kit.dart';
import '../entry_screen.dart';
import 'balance_screen.dart';
import 'customer_auth.dart';
import 'order_form.dart';

/// The customer-facing app: Home, Order, Balance, Orders, Profile.
class CustomerShell extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String designation;
  const CustomerShell({super.key, required this.name, required this.phone, this.email = '', this.address = '', this.designation = ''});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> with WidgetsBindingObserver {
  int _index = 0;
  int _seenBroadcasts = 0;
  Timer? _refreshTimer;
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
      // Immediate fetch + safety-net polling so the app stays in sync even if
      // a realtime event is dropped (flaky mobile networks).
      store.reload();
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) store.reload();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
      _HomeTab(
        name: widget.name,
        phone: widget.phone,
        designation: widget.designation,
        onOrderNow: () => setState(() => _index = 1),
        onOpenBalance: () => setState(() => _index = 2),
      ),
      OrderForm(name: widget.name, phone: widget.phone, designation: widget.designation),
      BalanceScreen(name: widget.name, phone: widget.phone, designation: widget.designation),
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
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Balance'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
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
  final orders = customerOrdersFor(store, name, phone);
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

/// Home keeps to three things: is a demand open, how much balance is left,
/// and the last order. Everything else lives in its own tab.
class _HomeTab extends StatelessWidget {
  final String name;
  final String phone;
  final String designation;
  final VoidCallback onOrderNow;
  final VoidCallback onOpenBalance;
  const _HomeTab({
    required this.name,
    required this.phone,
    required this.designation,
    required this.onOrderNow,
    required this.onOpenBalance,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final displayName = _homeDisplayName(name);
    final myOrders = customerOrdersFor(store, name, phone);
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
              const SizedBox(height: 16),
              _OrderStatusCard(store: store, designation: designation, onOrderNow: onOrderNow),
              const SizedBox(height: 12),
              _BalanceSnapshot(store: store, name: name, phone: phone, designation: designation, onOpen: onOpenBalance),
              if (lastOrder != null) ...[
                const SizedBox(height: 12),
                _LastOrderStrip(order: lastOrder),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact balance teaser: the headline figure and a tap-through to the
/// Balance tab where the full breakdown lives.
class _BalanceSnapshot extends StatelessWidget {
  final AppStore store;
  final String name;
  final String phone;
  final String designation;
  final VoidCallback onOpen;
  const _BalanceSnapshot({
    required this.store,
    required this.name,
    required this.phone,
    required this.designation,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final month = store.currentMonth;
    final balances = store
        .balancesFor(name: name, phone: phone, zone: designation, month: month)
        .where((b) => b.total > 0)
        .toList();
    if (balances.isEmpty) return const SizedBox.shrink();

    final remaining = balances.fold<double>(0, (s, b) => s + b.remaining);
    final total = balances.fold<double>(0, (s, b) => s + b.total);
    final ratio = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);

    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance · ${month.shortLabel}', style: t.bodySmall),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtNum(remaining), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDark)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text('of ${fmtNum(total)} left', style: t.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: AppColors.brand,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
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
    final greet = _timeGreeting();
    final dateLine = DateFormat('EEEE, d MMM').format(DateTime.now());
    final showName = name != 'there';

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(showName ? '$greet, $name' : greet, style: t.headlineSmall),
          const SizedBox(height: 3),
          Text(dateLine, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _OrderStatusCard extends StatelessWidget {
  final AppStore store;
  final String designation;
  final VoidCallback onOrderNow;
  const _OrderStatusCard({required this.store, required this.designation, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final windows = store.openCyclesFor(designation);
    final open = windows.isNotEmpty && store.items.isNotEmpty;
    final multi = windows.length > 1;
    final cycle = windows.isNotEmpty ? windows.first : null;
    final closeLine = cycle != null ? DateFormat('d MMM').format(cycle.weekEnd) : '';
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    final washOpen = dark ? AppColors.dSuccessWash : AppColors.successWash;
    final fresh = cycle?.type == DemandType.fresh;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: open ? washOpen : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: open ? AppColors.success.withValues(alpha: 0.4) : scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: open ? AppColors.success.withValues(alpha: 0.16) : scheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  open ? (fresh ? Icons.eco_rounded : Icons.grain_rounded) : Icons.lock_clock_rounded,
                  color: open ? AppColors.success : scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      open
                          ? (multi ? '${windows.length} demands open' : '${cycle!.type.label} demand open')
                          : 'Demand not started',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      open
                          ? (multi ? 'Pick one on the Order tab' : '${cycle!.days} days · closes $closeLine')
                          : 'You will be notified when it opens',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              Pill(open ? 'OPEN' : 'CLOSED', color: open ? AppColors.success : scheme.onSurfaceVariant),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOrderNow,
                child: const Text('Place demand'),
              ),
            ),
          ],
        ],
      ),
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
    final orders = customerOrdersFor(store, name, phone);

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
