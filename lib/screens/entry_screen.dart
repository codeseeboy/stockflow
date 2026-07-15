import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/supabase_config.dart';
import '../data/app_store.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/app_prefs.dart';
import '../widgets/ui_kit.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'customer/customer_auth.dart';

/// Brand logo mark — a plain navy tile.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(Icons.inventory_2_outlined, color: Colors.white, size: size * 0.5),
    );
  }
}

/// First screen: pick how to enter. Kept deliberately plain — a name, one line
/// of purpose, and three clearly-labelled options.
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final theme = context.watch<ThemeController>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  onPressed: theme.toggle,
                  tooltip: theme.isDark ? 'Light mode' : 'Dark mode',
                  icon: Icon(theme.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandMark(size: 56)),
                      const SizedBox(height: 16),
                      Center(child: Text('StockFlow', style: t.headlineMedium)),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Ration inventory and demand system',
                          style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Sign in as', style: t.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      ..._options(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _options(BuildContext context) {
    final options = [
      _EntryOption(
        icon: Icons.shopping_basket_outlined,
        title: 'Customer',
        subtitle: 'Place your ration demand and see your balance',
        onTap: () => _go(context, const CustomerWelcome()),
      ),
      _EntryOption(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Admin',
        subtitle: 'Manage stock, demands, zones and reports',
        onTap: () => _enterStaff(context, UserRole.admin),
      ),
      _EntryOption(
        icon: Icons.badge_outlined,
        title: 'Store staff',
        subtitle: 'Update stock and fulfil incoming demands',
        onTap: () => _enterStaff(context, UserRole.worker),
      ),
    ];
    // App = customers first; website = admin first.
    final ordered = kIsWeb ? [options[1], options[2], options[0]] : options;
    return [
      for (var i = 0; i < ordered.length; i++) ...[
        ordered[i],
        if (i != ordered.length - 1) const SizedBox(height: 10),
      ],
    ];
  }

  static void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Demo mode → straight in. Live mode → reuse an existing session if signed
  /// in, otherwise show the login screen.
  static Future<void> _enterStaff(BuildContext context, UserRole role) async {
    if (!SupabaseConfig.isConfigured) {
      SavedAdminSession(email: '', role: role).save();
      _go(context, AdminShell(role: role));
      return;
    }
    final store = context.read<AppStore>();
    if (store.isSignedIn) {
      final resolved = await store.currentRole() ?? role;
      final email = store.isSignedIn ? (SavedAdminSession.load()?.email ?? '') : '';
      SavedAdminSession(email: email, role: resolved).save();
      if (context.mounted) _go(context, AdminShell(role: resolved));
    } else {
      final saved = SavedAdminSession.load();
      _go(context, LoginScreen(fallbackRole: role, initialEmail: saved?.email));
    }
  }
}

/// One sign-in option: icon, name, one line of explanation, chevron.
class _EntryOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EntryOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
