import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../config/supabase_config.dart';
import '../data/app_store.dart';
import '../main.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/app_prefs.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'customer/customer_auth.dart';

/// Brand logo mark — a rounded tile with a stacked-boxes glyph.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandLight, AppColors.brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(color: AppColors.brand.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Icon(Icons.inventory_2_rounded, color: Colors.white, size: size * 0.52),
    );
  }
}

class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final theme = context.watch<ThemeController>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.isDark
                ? [const Color(0xFF10241C), scheme.surface]
                : [AppColors.brandWash, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: IconButton.filledTonal(
                    onPressed: theme.toggle,
                    icon: Icon(theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 64),
                        const SizedBox(height: 20),
                        Text('StockFlow', style: t.displaySmall?.copyWith(fontSize: 38))
                            .animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
                        const SizedBox(height: 8),
                        Text(
                          'Live inventory · weekly ordering · smart notifications',
                          textAlign: TextAlign.center,
                          style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
                        if (kIsWeb) ...[
                          const SizedBox(height: 28),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _FeaturePill(Icons.auto_awesome_rounded, 'Smart item icons'),
                              _FeaturePill(Icons.sync_rounded, 'Real-time sync'),
                              _FeaturePill(Icons.sms_rounded, 'SMS & WhatsApp'),
                              _FeaturePill(Icons.table_chart_rounded, 'Excel import'),
                            ],
                          ).animate().fadeIn(delay: 180.ms, duration: 400.ms),
                        ],
                        const SizedBox(height: 36),
                        Text('How would you like to continue?', style: t.titleMedium),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, c) {
                            final wide = c.maxWidth > 720;
                            final adminCard = _RoleCard(
                              icon: Icons.dashboard_rounded,
                              color: AppColors.brand,
                              title: 'Admin Console',
                              subtitle: kIsWeb
                                  ? 'Full control over stock, orders, analytics and reports'
                                  : 'Limited on the app. Full tools on the website',
                              onTap: () => _enterStaff(context, UserRole.admin),
                            );
                            final staffCard = _RoleCard(
                              icon: Icons.badge_rounded,
                              color: AppColors.cDairy,
                              title: 'Store Staff',
                              subtitle: 'Update stock and fulfil incoming orders',
                              onTap: () => _enterStaff(context, UserRole.worker),
                            );
                            final customerCard = _RoleCard(
                              icon: Icons.shopping_basket_rounded,
                              color: AppColors.accent,
                              title: 'Customer Order',
                              subtitle: 'Browse live stock and place this week\'s order',
                              onTap: () => _go(context, const CustomerWelcome()),
                            );
                            // App = customers first; Website = admin first.
                            final cards = kIsWeb
                                ? [adminCard, staffCard, customerCard]
                                : [customerCard, staffCard, adminCard];
                            return wide
                                ? IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        for (var i = 0; i < cards.length; i++) ...[
                                          Expanded(child: cards[i]),
                                          if (i != cards.length - 1) const SizedBox(width: 14),
                                        ],
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (var i = 0; i < cards.length; i++) ...[
                                        cards[i],
                                        if (i != cards.length - 1) const SizedBox(height: 12),
                                      ],
                                    ],
                                  );
                          },
                        ).animate().fadeIn(delay: 220.ms, duration: 450.ms).slideY(begin: 0.1),
                        const SizedBox(height: 28),
                        Text(
                          'Prototype · sample data · no real accounts needed',
                          style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: 160.ms,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: _hover ? widget.color.withValues(alpha: 0.6) : scheme.outline),
          boxShadow: _hover
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 12))]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.title, style: t.titleLarge),
                  const SizedBox(height: 6),
                  Text(widget.subtitle, style: t.bodyMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Continue', style: t.labelLarge?.copyWith(color: widget.color)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: widget.color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
