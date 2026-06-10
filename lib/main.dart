import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'config/supabase_config.dart';
import 'data/app_store.dart';
import 'data/supabase_service.dart';
import 'models/models.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/customer_app.dart';
import 'screens/customer/customer_auth.dart' show CustomerRegister, CustomerWelcome;
import 'screens/entry_screen.dart';
import 'theme/app_theme.dart';
import 'data/food_icon_brain_loader.dart';
import 'utils/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.init();
  await FoodIconBrainLoader.init();
  runApp(const StockFlowApp());
}

/// Holds the light/dark preference for the whole app.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  bool get isDark => mode == ThemeMode.dark;
  void toggle() {
    mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

/// True when the website was opened via a shared order link (e.g. /c/abc123),
/// meaning a customer — not staff — landed here and should see the order flow.
bool _isCustomerOrderLink() {
  final seg = Uri.base.pathSegments;
  return seg.isNotEmpty && seg.first == 'c';
}

class StockFlowApp extends StatelessWidget {
  const StockFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final store = AppStore();
          // Auto-connect once real Supabase keys are pasted into supabase_config.dart.
          if (SupabaseConfig.isConfigured) {
            store.connectSupabase(SupabaseService());
          } else {
            store.markReady();
          }
          return store;
        }),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'StockFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          // Website root = admin console. A shared order link (/c/<token>) on the
          // web opens the customer ordering flow instead. The app = customer.
          home: kIsWeb
              ? (_isCustomerOrderLink() ? const CustomerWelcome() : const WebSplashScreen())
              : const SplashScreen(),
        ),
      ),
    );
  }
}

/// Web launch gate: restores admin session and opens the console directly.
class WebSplashScreen extends StatefulWidget {
  const WebSplashScreen({super.key});

  @override
  State<WebSplashScreen> createState() => _WebSplashScreenState();
}

class _WebSplashScreenState extends State<WebSplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final store = context.read<AppStore>();
    while (!store.bootstrapped) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // The website is the admin console only — customers use the mobile app.
    final admin = SavedAdminSession.load();
    Widget next;

    if (!SupabaseConfig.isConfigured) {
      next = AdminShell(role: admin?.role ?? UserRole.admin);
    } else if (store.isSignedIn) {
      final role = await store.currentRole() ?? admin?.role ?? UserRole.admin;
      next = AdminShell(role: role);
    } else {
      next = LoginScreen(fallbackRole: admin?.role ?? UserRole.admin, initialEmail: admin?.email);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, _) => next,
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}

/// Mobile launch gate: restores the saved session, then routes straight to
/// the customer shell (still logged in) or to the welcome screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final store = context.read<AppStore>();
    final started = DateTime.now();

    while (!store.bootstrapped) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    // Let the splash breathe so the transition feels intentional, not glitchy.
    final elapsed = DateTime.now().difference(started);
    const minSplash = Duration(milliseconds: 1500);
    if (elapsed < minSplash) await Future<void>.delayed(minSplash - elapsed);
    if (!mounted) return;

    final profile = SavedProfile.load();
    final hasSession = store.isSignedIn || !SupabaseConfig.isConfigured;
    Widget next;
    if (profile != null && (profile.guest || hasSession)) {
      next = CustomerShell(name: profile.name, phone: profile.phone, email: profile.email, address: profile.address);
    } else {
      if (profile != null) SavedProfile.clear(); // stale account profile without a session
      next = const CustomerRegister();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, anim, secondaryAnimation, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? [const Color(0xFF10241C), scheme.surface] : [AppColors.brandWash, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -60,
                child: _SplashGlow(color: scheme.primary.withValues(alpha: dark ? 0.18 : 0.16), size: 180),
              ),
              Positioned(
                left: -80,
                bottom: 70,
                child: _SplashGlow(color: AppColors.accent.withValues(alpha: dark ? 0.12 : 0.18), size: 210),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 78)
                            .animate()
                            .fadeIn(duration: 280.ms)
                            .scale(begin: const Offset(0.74, 0.74), duration: 520.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 22),
                        Text('StockFlow', textAlign: TextAlign.center, style: t.displaySmall?.copyWith(letterSpacing: -0.8))
                            .animate()
                            .fadeIn(delay: 160.ms, duration: 380.ms)
                            .slideY(begin: 0.12, duration: 380.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 8),
                        Text(
                          'Inventory & weekly ordering',
                          textAlign: TextAlign.center,
                          style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ).animate().fadeIn(delay: 280.ms, duration: 360.ms),
                        const SizedBox(height: 34),
                        _SplashProgress(color: scheme.primary)
                            .animate()
                            .fadeIn(delay: 420.ms, duration: 300.ms)
                            .slideY(begin: 0.18, delay: 420.ms, duration: 360.ms, curve: Curves.easeOutCubic),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    'Preparing your store',
                    style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ).animate().fadeIn(delay: 600.ms, duration: 350.ms),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _SplashGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _SplashProgress extends StatelessWidget {
  final Color color;

  const _SplashProgress({required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 132,
      height: 6,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.42,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .slideX(begin: -1.2, end: 2.8, duration: 1200.ms, curve: Curves.easeInOutCubic),
        ),
      ),
    );
  }
}
