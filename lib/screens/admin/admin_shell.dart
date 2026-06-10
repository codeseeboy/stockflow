import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../entry_screen.dart';
import 'analytics_screen.dart';
import 'cycles_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

String dashboardGreeting() {
  final hour = DateTime.now().hour;
  final greet = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
  return '$greet, Arjun';
}

class _Dest {
  final IconData icon;
  final IconData selected;
  final String label;
  final Widget page;
  const _Dest(this.icon, this.selected, this.label, this.page);
}

class AdminShell extends StatefulWidget {
  final UserRole role;
  const AdminShell({super.key, required this.role});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  bool get _isAdmin => widget.role == UserRole.admin;

  // Full admin lives on the website. The app keeps a lean set; analytics,
  // weekly-link management, reports and users are web-only.
  late final List<_Dest> _dests = [
    const _Dest(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard', DashboardScreen()),
    if (kIsWeb)
      const _Dest(Icons.insights_outlined, Icons.insights_rounded, 'Analytics', AnalyticsScreen()),
    const _Dest(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory', InventoryScreen()),
    const _Dest(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders', OrdersScreen()),
    if (kIsWeb && _isAdmin)
      const _Dest(Icons.link_rounded, Icons.link_rounded, 'Weekly Link', CyclesScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = IndexedStack(index: _index, children: [for (final d in _dests) d.page]);

    if (wide) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        body: Row(
          children: [
            _SideNav(
              dests: _dests,
              index: _index,
              role: widget.role,
              onSelect: (i) => setState(() => _index = i),
            ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(role: widget.role, title: _dests[_index].label, subtitle: _index == 0 ? dashboardGreeting() : null),
                  if (!kIsWeb) const _AppLimitedBanner(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _TopBar(role: widget.role, title: _dests[_index].label, subtitle: _index == 0 ? dashboardGreeting() : null),
          if (!kIsWeb) const _AppLimitedBanner(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _dests)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final List<_Dest> dests;
  final int index;
  final UserRole role;
  final ValueChanged<int> onSelect;
  const _SideNav({required this.dests, required this.index, required this.role, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    const dark = Color(0xFF0F221C);
    const dark2 = Color(0xFF122820);
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [dark, dark2],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Row(
              children: [
                const BrandMark(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('StockFlow', style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text('Admin Console', style: t.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (var i = 0; i < dests.length; i++)
                  _NavItem(
                    dest: dests[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('MANAGE', style: t.labelMedium?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Colors.white54)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                if (kIsWeb)
                  _ManageRow(icon: Icons.bar_chart_rounded, label: 'Reports', onTap: () => _push(context, const ReportsScreen())),
                if (kIsWeb && role == UserRole.admin)
                  _ManageRow(icon: Icons.group_rounded, label: 'Users', onTap: () => _push(context, const UsersScreen())),
                _ManageRow(icon: Icons.settings_rounded, label: 'Settings', onTap: () => _push(context, SettingsScreen(role: role))),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              color: scheme.surfaceContainerHighest,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brand,
                    child: Text(
                      role == UserRole.admin ? 'A' : 'S',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role == UserRole.admin ? 'Arjun Mehta' : 'Priya Nair',
                            style: t.titleSmall, overflow: TextOverflow.ellipsis),
                        Text(role == UserRole.admin ? 'Administrator' : 'Store Staff', style: t.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: () async {
                      await context.read<AppStore>().signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EntryScreen()),
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ManageRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.white60),
                const SizedBox(width: 12),
                Text(label, style: t.titleSmall?.copyWith(color: Colors.white70)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

/// Shown on the mobile app for admin/staff: full management lives on the website.
class _AppLimitedBanner extends StatelessWidget {
  const _AppLimitedBanner();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: AppColors.accentWash,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.computer_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'App view. Analytics, reports, users and weekly link are on the website.',
              style: t.bodySmall?.copyWith(color: const Color(0xFF8A5A12), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.dest, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(selected ? dest.selected : dest.icon,
                    size: 21, color: selected ? const Color(0xFF9DF3C7) : Colors.white60),
                const SizedBox(width: 12),
                Text(
                  dest.label,
                  style: t.titleSmall?.copyWith(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final UserRole role;
  final String title;
  final String? subtitle;
  const _TopBar({required this.role, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final theme = context.watch<ThemeController>();
    final store = context.watch<AppStore>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final alertCount = store.alerts.length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          if (!wide) ...[
            const BrandMark(size: 32),
            const SizedBox(width: 10),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.titleLarge),
              if (subtitle != null)
                Text(subtitle!, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: 10),
          if (role == UserRole.worker) const Pill('Staff', color: AppColors.cDairy),
          const Spacer(),
          IconButton(
            tooltip: 'Theme',
            onPressed: theme.toggle,
            icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Alerts',
                onPressed: () => _showAlerts(context, store),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              if (alertCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$alertCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              switch (v) {
                case 'reports':
                  _push(context, const ReportsScreen());
                case 'users':
                  _push(context, const UsersScreen());
                case 'settings':
                  _push(context, SettingsScreen(role: role));
              }
            },
            itemBuilder: (_) => [
              if (kIsWeb)
                const PopupMenuItem(value: 'reports', child: _MenuRow(Icons.bar_chart_rounded, 'Reports')),
              if (kIsWeb && role == UserRole.admin)
                const PopupMenuItem(value: 'users', child: _MenuRow(Icons.group_rounded, 'Users')),
              const PopupMenuItem(value: 'settings', child: _MenuRow(Icons.settings_rounded, 'Settings')),
            ],
          ),
        ],
      ),
    );
  }

  void _showAlerts(BuildContext context, AppStore store) {
    final t = Theme.of(context).textTheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final alerts = store.alerts;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text('Stock alerts', style: t.titleLarge),
                    const Spacer(),
                    Pill('${alerts.length} active', color: AppColors.warning),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Workers also receive these as push notifications.', style: t.bodySmall),
                const SizedBox(height: 12),
                Expanded(
                  child: alerts.isEmpty
                      ? const EmptyState(icon: Icons.check_circle_rounded, title: 'All good', subtitle: 'No stock alerts right now.')
                      : ListView.separated(
                          controller: controller,
                          itemCount: alerts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final a = alerts[i];
                            return AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(color: a.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.sm)),
                                    child: Icon(a.icon, color: a.color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.title, style: t.titleSmall),
                                        const SizedBox(height: 2),
                                        Text(a.body, style: t.bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
