import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../main.dart';
import '../entry_screen.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

class SettingsScreen extends StatefulWidget {
  final UserRole role;
  const SettingsScreen({super.key, required this.role});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _store = TextEditingController(text: context.read<AppStore>().storeName);
  bool _lowStock = true;
  bool _newOrders = true;
  bool _weekly = true;

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final t = Theme.of(context).textTheme;
    final isAdmin = widget.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.brand,
                        child: Text(isAdmin ? 'A' : 'S', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isAdmin ? 'Arjun Mehta' : 'Priya Nair', style: t.titleLarge),
                            const SizedBox(height: 2),
                            Text(isAdmin ? 'Administrator' : 'Store Staff', style: t.bodyMedium),
                          ],
                        ),
                      ),
                      Pill(isAdmin ? 'Admin' : 'Staff', color: isAdmin ? AppColors.brand : AppColors.cDairy),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle('Store'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Store name', style: t.labelMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _store,
                              enabled: isAdmin,
                              decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront_rounded)),
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: () {
                                context.read<AppStore>().setStoreName(_store.text.trim());
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store name saved')));
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle('Appearance'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: SwitchListTile(
                    value: theme.isDark,
                    onChanged: (_) => theme.toggle(),
                    secondary: Icon(theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.brand),
                    title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Switch between light and dark theme'),
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle('Notifications'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    children: [
                      _toggle('Low-stock alerts', 'Get notified before items run out', Icons.trending_down_rounded, _lowStock, (v) => setState(() => _lowStock = v)),
                      const Divider(height: 1),
                      _toggle('New orders', 'Alert when a customer places an order', Icons.receipt_long_rounded, _newOrders, (v) => setState(() => _newOrders = v)),
                      const Divider(height: 1),
                      _toggle('Weekly link reminders', 'Remind to generate the weekly link', Icons.link_rounded, _weekly, (v) => setState(() => _weekly = v)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _GroupTitle('About'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _aboutRow('Version', '1.6.4'),
                      const Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brandWash,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(Icons.school_rounded, color: AppColors.brand, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Built by', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 2),
                                Text(
                                  'St. John College of Engineering and Management (SJCEM)',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await context.read<AppStore>().signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EntryScreen()),
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Switch role / Sign out'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(String title, String sub, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: AppColors.brand),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub),
    );
  }

  Widget _aboutRow(String k, String v) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: t.bodyMedium),
        Text(v, style: t.titleSmall),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
    );
  }
}
