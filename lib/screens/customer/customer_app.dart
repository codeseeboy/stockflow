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
import '../../utils/app_tour.dart';
import '../../utils/customer_orders.dart';
import '../../utils/notification_service.dart';
import '../../utils/tour_keys.dart';
import '../../widgets/tour_overlay.dart';
import '../../widgets/ui_kit.dart';
import '../entry_screen.dart';
import 'balance_screen.dart';
import 'customer_auth.dart';
import 'order_detail_screen.dart';
import 'order_form.dart';

/// The customer-facing app: Home, Order, Balance, Orders, Profile.
class CustomerShell extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String designation;
  // Only true for the mount right after a brand-new signup completes — the
  // guided tour auto-starts once for that specific mount, never for a
  // returning user logging back in.
  final bool isNewUser;
  const CustomerShell({
    super.key,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.designation = '',
    this.isNewUser = false,
  });

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

  final TourController _tour = TourController();

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _tour.onSwitchTab = (i) => setState(() => _index = i);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = context.read<AppStore>();
      _seenBroadcasts = store.customerBroadcasts.length;
      store.addListener(_onStoreUpdate);
      // Immediate fetch + safety-net polling so the app stays in sync even if
      // a realtime event is dropped (flaky mobile networks).
      store.reload();
      // Re-fetch the profile so that if an admin updated this customer's zone
      // in Supabase after their last login, the new designation takes effect
      // immediately without requiring a sign-out/sign-in.
      _syncDesignationFromServer(store);
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) store.reload();
      });
      // Auto-start only right after a brand-new signup (never on a returning
      // login) and only the first time ever on this device. The earlier
      // freeze traced back to signup leaving the profile's zone unset on the
      // server, which made the very next sync think it had changed and
      // rebuild this whole shell mid-tour — now fixed at the source in
      // signUpCustomer, so the tour no longer races a surprise rebuild.
      if (widget.isNewUser && !TourPrefs.seen) {
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _tour.start(buildAppTour());
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tour.dispose();
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

  /// Pull the latest zone/designation from Supabase and update the locally
  /// saved profile so the customer sees the correct demand cycles without
  /// having to sign out and sign back in.
  Future<void> _syncDesignationFromServer(AppStore store) async {
    try {
      final p = await store.myProfile();
      if (p == null || !mounted) return;
      final serverZone = p.zone.trim();
      final saved = SavedProfile.load();
      if (saved == null) return;
      if (serverZone != saved.designation.trim()) {
        SavedProfile(
          name: saved.name,
          phone: saved.phone,
          email: saved.email,
          address: saved.address,
          designation: serverZone,
          guest: saved.guest,
          accountCreatedAt: saved.accountCreatedAt,
        ).save();
        // Restart the shell so openCyclesFor() picks up the new designation.
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, _, _) => CustomerShell(
                name: saved.name,
                phone: saved.phone,
                email: saved.email,
                address: saved.address,
                designation: serverZone,
              ),
              transitionsBuilder: (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
            (r) => false,
          );
        }
      }
    } catch (_) {
      // Network failure — keep existing designation, silently ignore.
    }
  }

  /// Rule-based nudges — the app knows the ration cycle, so it speaks up at
  /// the two moments that matter, without the admin doing anything:
  ///  * a demand for this customer's zone just opened;
  ///  * a demand closes within 24 h and they haven't placed theirs yet.
  /// Each fires once per demand (remembered on-device).
  void _smartNudges(AppStore store) {
    const seenKey = 'nudge_seen_open';
    const closeKey = 'nudge_closing';
    final seenOpen = (AppPrefs.getString(seenKey) ?? '').split(',').toSet();
    final nudgedClose = (AppPrefs.getString(closeKey) ?? '').split(',').toSet();
    final myOrders = customerOrdersFor(store, widget.name, widget.phone).map((o) => o.cycleId).toSet();
    var changed = false;

    for (final c in store.openCyclesFor(widget.designation)) {
      final closesAt = DateTime(c.weekEnd.year, c.weekEnd.month, c.weekEnd.day, 23, 59);
      final left = closesAt.difference(DateTime.now());

      if (!seenOpen.contains(c.id)) {
        seenOpen.add(c.id);
        changed = true;
        // Don't re-announce demands that were already open on first launch.
        if (DateTime.now().difference(_sessionStart).inSeconds > 20) {
          NotificationService.show(
            '${c.type.label} demand is open',
            'Place your demand before ${DateFormat('d MMM').format(c.weekEnd)}.',
          );
        }
      }

      if (!left.isNegative && left.inHours < 24 && !myOrders.contains(c.id) && !nudgedClose.contains(c.id)) {
        nudgedClose.add(c.id);
        changed = true;
        NotificationService.show(
          'Closing soon — ${c.title}',
          'You haven\'t placed your demand yet. It closes in ${left.inHours}h ${left.inMinutes % 60}m.',
        );
      }
    }
    if (changed) {
      AppPrefs.setString(seenKey, seenOpen.where((s) => s.isNotEmpty).join(','));
      AppPrefs.setString(closeKey, nudgedClose.where((s) => s.isNotEmpty).join(','));
    }
  }

  void _onStoreUpdate() {
    if (!mounted) return;
    final store = context.read<AppStore>();
    _smartNudges(store);
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
        onOpenHistory: () => setState(() => _index = 3),
      ),
      OrderForm(
        name: widget.name,
        phone: widget.phone,
        designation: widget.designation,
        onOpenBalance: () => setState(() => _index = 2),
      ),
      BalanceScreen(name: widget.name, phone: widget.phone, designation: widget.designation),
      _MyOrdersTab(name: widget.name, phone: widget.phone, designation: widget.designation, onOrderNow: () => setState(() => _index = 1)),
      _ProfileTab(
        name: widget.name,
        phone: widget.phone,
        email: widget.email,
        address: widget.address,
        onReplayTour: () => _tour.start(buildAppTour()),
      ),
    ];

    return SpotlightOverlay(controller: _tour, child: _shellScaffold(tabs));
  }

  Widget _shellScaffold(List<Widget> tabs) {
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
        key: TourKeys.navBar,
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Data is kept fresh by the 15-second polling timer and Supabase
          // realtime — no need to fire a full reload on every tab tap, which
          // was causing a visible flash each time the user switched tabs.
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_shopping_cart_outlined), selectedIcon: Icon(Icons.add_shopping_cart_rounded), label: 'Demand'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Balance'),
          NavigationDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history_rounded), label: 'History'),
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
      'Order ${o.displayId} is ${orderStatusLabel(o.status).toLowerCase()}',
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

/// Home keeps to what matters at a glance: is a demand open, how much
/// balance is left, one-tap shortcuts to everything else, and the last
/// order. Everything deeper lives in its own tab, a single tap away.
class _HomeTab extends StatelessWidget {
  final String name;
  final String phone;
  final String designation;
  final VoidCallback onOrderNow;
  final VoidCallback onOpenBalance;
  final VoidCallback onOpenHistory;
  const _HomeTab({
    required this.name,
    required this.phone,
    required this.designation,
    required this.onOrderNow,
    required this.onOpenBalance,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final displayName = _homeDisplayName(name);
    final myOrders = customerOrdersFor(store, name, phone);
    final lastOrder = myOrders.isNotEmpty ? myOrders.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeyedSubtree(key: TourKeys.greeting, child: _HomeGreeting(name: displayName)),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: TourKeys.quickActions,
                child: _QuickActions(onOrderNow: onOrderNow, onOpenBalance: onOpenBalance, onOpenHistory: onOpenHistory),
              ),
              const SizedBox(height: 18),
              KeyedSubtree(
                key: TourKeys.demandStatus,
                child: _OrderStatusCard(store: store, designation: designation, onOrderNow: onOrderNow),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('THIS MONTH AT A GLANCE'),
              const SizedBox(height: 8),
              KeyedSubtree(key: TourKeys.monthTimeline, child: _MonthTimelineCard(store: store, designation: designation)),
              const SizedBox(height: 22),
              const _SectionLabel('YOUR BALANCE'),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: TourKeys.balanceSnapshot,
                child: _BalanceSnapshot(store: store, name: name, phone: phone, designation: designation, onOpen: onOpenBalance),
              ),
              if (lastOrder != null) ...[
                const SizedBox(height: 22),
                const _SectionLabel('RECENT'),
                const SizedBox(height: 8),
                _LastOrderStrip(order: lastOrder),
              ],
              const BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small uppercase section label — gives the page scannable structure
/// without adding sentences.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// One-tap shortcuts to the three things a customer reaches for most —
/// nothing here needs a second screen or a menu, just a thumb.
class _QuickActions extends StatelessWidget {
  final VoidCallback onOrderNow;
  final VoidCallback onOpenBalance;
  final VoidCallback onOpenHistory;
  const _QuickActions({required this.onOrderNow, required this.onOpenBalance, required this.onOpenHistory});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionChip(icon: Icons.add_shopping_cart_rounded, label: 'Place demand', color: AppColors.brand, onTap: onOrderNow)),
        const SizedBox(width: 10),
        Expanded(child: _ActionChip(icon: Icons.account_balance_wallet_rounded, label: 'My balance', color: AppColors.cDairy, onTap: onOpenBalance)),
        const SizedBox(width: 10),
        Expanded(child: _ActionChip(icon: Icons.history_rounded, label: 'My orders', color: AppColors.accent, onTap: onOpenHistory)),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final carried = balances.fold<double>(0, (s, b) => s + b.carriedIn);
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
                UsageBar(used01: 1 - ratio, height: 6),
                // Carry-forward must always be visible — this is the figure
                // that rolled in from last month's leftover.
                if (carried > 0) ...[
                  const SizedBox(height: 8),
                  Pill('+${fmtNum(carried)} carried from ${month.previous.shortLabel}', color: AppColors.accent, icon: Icons.move_up_rounded),
                ],
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

/// The calendar-anchored heart of Home: which month and week we're in, and
/// what that means for ordering right now. Everything in this app revolves
/// around the monthly entitlement and the weekly demand window, so this card
/// leads with the calendar, not a generic status pill.
class _OrderStatusCard extends StatelessWidget {
  final AppStore store;
  final String designation;
  final VoidCallback onOrderNow;
  const _OrderStatusCard({required this.store, required this.designation, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final now = DateTime.now();

    final windows = store.openCyclesFor(designation);
    final open = windows.isNotEmpty && store.items.isNotEmpty;
    final multi = windows.length > 1;
    final cycle = windows.isNotEmpty ? windows.first : null;
    final fresh = cycle?.type == DemandType.fresh;

    // Always-visible calendar context: "July 2026" / "Week 2 · Mon 6 – Sun 12 Jul".
    final month = store.currentMonth;
    final week = calendarWeekOf(now);
    final weekRange = week.start.month == week.end.month
        ? 'Mon ${DateFormat('d').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}'
        : 'Mon ${DateFormat('d MMM').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}';

    // The demand's own window (its actual dates, whatever span the admin set).
    final closesAt = cycle == null
        ? null
        : DateTime(cycle.weekEnd.year, cycle.weekEnd.month, cycle.weekEnd.day, 23, 59);
    final windowRange = cycle == null
        ? ''
        : '${DateFormat('EEE, d MMM').format(cycle.weekStart)} – ${DateFormat('EEE, d MMM').format(cycle.weekEnd)}';
    final leftDur = closesAt?.difference(now);
    final String countdown;
    if (leftDur == null || leftDur.isNegative) {
      countdown = 'closing';
    } else if (leftDur.inDays >= 1) {
      countdown = '${leftDur.inDays}d ${leftDur.inHours % 24}h left';
    } else if (leftDur.inHours >= 1) {
      countdown = '${leftDur.inHours}h ${leftDur.inMinutes % 60}m left';
    } else {
      countdown = '${leftDur.inMinutes}m left';
    }
    final closingSoon = leftDur != null && leftDur.inHours < 24;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Calendar context: always visible, regardless of demand state ----
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(month.label, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text('Week ${week.number} · $weekRange', style: t.bodyMedium),
          ),
          const SizedBox(height: 14),
          Divider(color: scheme.outline, height: 1),
          const SizedBox(height: 14),

          // ---- Demand window state ----
          Row(
            children: [
              Icon(
                open ? (fresh ? Icons.eco_rounded : Icons.grain_rounded) : Icons.lock_clock_rounded,
                size: 17,
                color: open ? AppColors.success : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  open
                      ? (multi ? '${windows.length} demand windows open' : '${cycle!.type.label} demand window open')
                      : 'Demand window closed',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Pill(open ? 'OPEN' : 'CLOSED', color: open ? AppColors.success : scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          if (open && !multi && cycle != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text(windowRange, style: t.bodySmall),
            ),
            const SizedBox(height: 10),
            // The closing moment — highlighted, with a live countdown.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: dark ? AppColors.dSurfaceMuted : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: (closingSoon ? AppColors.danger : AppColors.success).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 17, color: closingSoon ? AppColors.danger : AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Closes ${DateFormat('EEE, d MMM · h:mm a').format(closesAt!)}', style: t.titleSmall?.copyWith(fontSize: 13)),
                  ),
                  Pill(countdown, color: closingSoon ? AppColors.danger : AppColors.success, icon: Icons.hourglass_bottom_rounded),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOrderNow,
                child: const Text('Place demand'),
              ),
            ),
          ] else if (open && multi) ...[
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text('Pick one on the Order tab', style: t.bodySmall),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOrderNow,
                child: const Text('Place demand'),
              ),
            ),
          ] else ...[
            // Closed: no future demand is scheduled ahead of time in this
            // system — the unit opens the next one when they're ready — so
            // this is honestly "to be announced" rather than a guessed date.
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Next window: TBD — you\'ll be notified when it opens', style: t.bodySmall)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Every calendar week of the current month in one glance: which ones are
/// done, which one is active right now, and which haven't arrived yet — so
/// the user always knows where they stand in the monthly demand cycle
/// without doing the arithmetic themselves. A month has 4 or 5 weeks
/// depending on how the days fall (weeksOfMonth computes this for real,
/// nothing here assumes a fixed count).
class _MonthTimelineCard extends StatelessWidget {
  final AppStore store;
  final String designation;
  const _MonthTimelineCard({required this.store, required this.designation});

  @override
  Widget build(BuildContext context) {
    final month = store.currentMonth;
    final weeks = weeksOfMonth(month);
    final today = DateTime.now();
    final cycles = store.cycles.where((c) => c.isPublic || c.designation.toLowerCase() == designation.trim().toLowerCase()).toList();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (var i = 0; i < weeks.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6)),
            _WeekRow(
              week: weeks[i],
              today: today,
              // A demand overlapping this calendar week, if the unit opened one.
              cycle: cycles.where((c) => !c.weekEnd.isBefore(weeks[i].start) && !c.weekStart.isAfter(weeks[i].end)).firstOrNull,
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  final CalendarWeek week;
  final DateTime today;
  final OrderCycle? cycle;
  const _WeekRow({required this.week, required this.today, this.cycle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final d = DateTime(today.year, today.month, today.day);
    final completed = week.end.isBefore(d);
    final active = !completed && !week.start.isAfter(d);
    final range = week.start.month == week.end.month
        ? 'Mon ${DateFormat('d').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}'
        : 'Mon ${DateFormat('d MMM').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}';

    final Color dotColor;
    final IconData icon;
    final String state;
    if (completed) {
      dotColor = scheme.onSurfaceVariant;
      icon = Icons.check_circle_rounded;
      state = 'Completed';
    } else if (active) {
      dotColor = AppColors.success;
      icon = Icons.radio_button_checked_rounded;
      state = 'Active';
    } else {
      dotColor = scheme.outline;
      icon = Icons.lock_outline_rounded;
      state = 'Upcoming';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: dotColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Week ${week.number}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: active ? scheme.onSurface : scheme.onSurfaceVariant)),
                Text(range, style: t.bodySmall),
              ],
            ),
          ),
          if (cycle != null)
            Pill(
              cycle!.status == CycleStatus.open ? 'Demand open' : 'Demand closed',
              color: cycle!.status == CycleStatus.open ? AppColors.success : scheme.onSurfaceVariant,
            )
          else
            Text(state, style: t.bodySmall?.copyWith(color: dotColor, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.receipt_long_rounded, color: scheme.onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last demand · ${order.displayId}', style: t.titleSmall),
                Text(DateFormat('d MMM, h:mm a').format(order.createdAt.toLocal()), style: t.bodySmall),
              ],
            ),
          ),
          Pill(orderStatusLabel(order.status), color: orderStatusColor(order.status)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ---------------- My Orders ----------------

/// The complete tracking record of every demand ever placed — not just a
/// list. Every card carries its month, week and exact submission time, and
/// tapping one opens the full created→viewed→accepted→processing→fulfilled
/// timeline so the customer never has to ask the admin where things stand.
class _MyOrdersTab extends StatelessWidget {
  final String name;
  final String phone;
  final String designation;
  final VoidCallback onOrderNow;
  const _MyOrdersTab({required this.name, required this.phone, required this.designation, required this.onOrderNow});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context).textTheme;
    final orders = customerOrdersFor(store, name, phone);

    // Newest first, grouped by month.
    final byMonth = <String, List<Order>>{};
    for (final o in orders) {
      byMonth.putIfAbsent(store.monthOfOrder(o).key, () => []).add(o);
    }
    final monthKeys = byMonth.keys.toList()
      ..sort((a, b) => (RationMonth.tryParse(b) ?? store.currentMonth).compareTo(RationMonth.tryParse(a) ?? store.currentMonth));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(
                key: TourKeys.historyList,
                child: Text('My Order History', style: t.headlineSmall),
              ),
              const SizedBox(height: 4),
              Text('Every demand you\'ve placed, with full status tracking', style: t.bodyMedium),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: Column(children: [
                    const EmptyState(icon: Icons.history_rounded, title: 'No demands yet', subtitle: 'Place your first demand to see it tracked here.'),
                    const SizedBox(height: 12),
                    if (store.canPlaceOrders)
                      FilledButton.icon(onPressed: onOrderNow, icon: const Icon(Icons.add_shopping_cart_rounded, size: 18), label: const Text('Place a demand')),
                  ]),
                )
              else
                for (final mk in monthKeys) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Text((RationMonth.tryParse(mk) ?? store.currentMonth).label, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  for (final o in byMonth[mk]!..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
                    _OrderHistoryCard(store: store, order: o, designation: designation, allOrders: orders),
                  const SizedBox(height: 8),
                ],
              const BrandFooter(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// One demand: month, week, exact date range, submission time, what was
/// ordered, current status, and what was left of the balance right after it.
class _OrderHistoryCard extends StatelessWidget {
  final AppStore store;
  final Order order;
  final String designation;
  final List<Order> allOrders;
  const _OrderHistoryCard({required this.store, required this.order, required this.designation, required this.allOrders});

  /// Point-in-time remaining balance, per category this order touched,
  /// counting only demands placed up to and including this one.
  Map<String, double> _balanceAfter() {
    final month = store.monthOfOrder(order);
    final zone = store.zoneFor(designation);
    final carried = store.carriedInto(order.customerName, order.customerPhone, designation, month);
    final categories = <String>{};
    for (final l in order.lines) {
      final c = store.categoryOfLine(l);
      if (c != null) categories.add(c);
    }
    final out = <String, double>{};
    for (final cat in categories) {
      var consumedUpTo = 0.0;
      for (final o in allOrders) {
        if (o.status == OrderStatus.cancelled || o.status == OrderStatus.rejected) continue;
        if (store.monthOfOrder(o) != month) continue;
        if (o.createdAt.isAfter(order.createdAt)) continue;
        for (final l in o.lines) {
          if (store.categoryOfLine(l) == cat) consumedUpTo += l.qty;
        }
      }
      final left = zone.monthlyAllowance(cat, month) + (carried[cat] ?? 0) - consumedUpTo;
      out[cat] = left < 0 ? 0 : left;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final month = store.monthOfOrder(order);
    final week = calendarWeekOf(order.createdAt.toLocal());
    final weekRange = week.start.month == week.end.month
        ? 'Mon ${DateFormat('d').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}'
        : 'Mon ${DateFormat('d MMM').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}';
    final balanceAfter = _balanceAfter();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(orderStatusIcon(order.status), size: 20, color: orderStatusColor(order.status)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.displayId, style: t.titleSmall),
                    Text('${month.shortLabel} · Week ${week.number} · $weekRange', style: t.bodySmall),
                  ],
                ),
              ),
              Pill(orderStatusLabel(order.status), color: orderStatusColor(order.status)),
            ]),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text('Submitted ${DateFormat('EEE, d MMM · h:mm a').format(order.createdAt.toLocal())}', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final l in order.lines)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('${l.emoji} ${l.name} · ${fmtQty(l.qty, l.unit)}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
            ]),
            if (balanceAfter.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text('Balance left after this demand', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final e in balanceAfter.entries)
                  Pill('${e.key}: ${fmtNum(e.value)}', color: AppColors.brand),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------- Profile ----------------

class _ProfileTab extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String address;
  final VoidCallback onReplayTour;
  const _ProfileTab({required this.name, required this.phone, required this.email, required this.address, required this.onReplayTour});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late String _email = widget.email;
  late String _address = widget.address;

  /// Edit the contact details. Name and phone stay locked — orders and the
  /// balance are keyed on them, so changing them would orphan the history.
  Future<void> _edit() async {
    final emailCtrl = TextEditingController(text: _email);
    final addressCtrl = TextEditingController(text: _address);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 10),
            Text(
              'Name and phone are fixed to your account — ask the admin to change them.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _email = emailCtrl.text.trim();
      _address = addressCtrl.text.trim();
    });
    final saved = SavedProfile.load();
    SavedProfile(
      name: widget.name,
      phone: widget.phone,
      email: _email,
      address: _address,
      designation: saved?.designation ?? '',
      guest: saved?.guest ?? false,
      accountCreatedAt: saved?.accountCreatedAt,
    ).save();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final theme = context.watch<ThemeController>();
    final name = widget.name;
    final zone = SavedProfile.load()?.designation ?? '';
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
                  Text(zone.isEmpty ? 'Customer account' : '$zone zone', style: t.bodyMedium),
                ]),
              ),
              const SizedBox(height: 24),
              KeyedSubtree(
                key: TourKeys.profileCard,
                child: AppCard(
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: Text('Contact details', style: t.titleSmall)),
                      TextButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    _row(context, Icons.phone_rounded, 'Phone', widget.phone.isEmpty ? 'Not set' : widget.phone),
                    const Divider(height: 20),
                    _row(context, Icons.mail_outline_rounded, 'Email', _email.isEmpty ? 'Not set' : _email),
                    const Divider(height: 20),
                    _row(context, Icons.location_on_outlined, 'Delivery address', _address.isEmpty ? 'Not set' : _address),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: TourKeys.profileDarkMode,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: SwitchListTile(
                    value: theme.isDark,
                    onChanged: (_) => theme.toggle(),
                    secondary: Icon(theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.brand),
                    title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onReplayTour,
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('Replay app tour'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final store = context.read<AppStore>();
                    SavedProfile.clear();
                    // Leave immediately — the server sign-out finishes in the
                    // background instead of blocking the button.
                    unawaited(store.signOut().catchError((Object _) {}));
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
              const BrandFooter(),
              const SizedBox(height: 12),
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
