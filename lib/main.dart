import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
bool isCustomerOrderLink() {
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
      // Theme changes must NOT recreate MaterialApp's navigator / home gate —
      // only swap themeMode. A full MaterialApp rebuild was remounting the
      // splash routers and flashing signup over the admin dashboard.
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
              ? (isCustomerOrderLink() ? const CustomerWelcome() : const WebSplashScreen())
              : const SplashScreen(),
        ),
      ),
    );
  }
}

/// Shared splash chrome only — no routing. Used by both web and mobile gates.
class SplashBody extends StatelessWidget {
  const SplashBody({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 64),
              const SizedBox(height: 18),
              Text('StockFlow', textAlign: TextAlign.center, style: t.headlineMedium),
              const SizedBox(height: 6),
              Text(
                'Ration inventory and demand system',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 140,
                child: LinearProgressIndicator(minHeight: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web launch gate: restores admin session and opens the console directly.
///
/// IMPORTANT: must NOT embed [SplashScreen] — that widget runs mobile customer
/// routing and was racing this gate, flashing "Create your account" over the
/// admin dashboard in a loop.
class WebSplashScreen extends StatefulWidget {
  const WebSplashScreen({super.key});

  @override
  State<WebSplashScreen> createState() => _WebSplashScreenState();
}

class _WebSplashScreenState extends State<WebSplashScreen> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    if (_routed) return;
    final store = context.read<AppStore>();
    while (!store.bootstrapped) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _routed) return;
    _routed = true;

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
  Widget build(BuildContext context) => const SplashBody();
}

/// Mobile launch gate: restores the saved session, then routes straight to
/// the customer shell (still logged in) or to the welcome screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    if (_routed) return;
    final store = context.read<AppStore>();
    final started = DateTime.now();

    while (!store.bootstrapped) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
    // A short minimum so the transition doesn't flash.
    final elapsed = DateTime.now().difference(started);
    const minSplash = Duration(milliseconds: 500);
    if (elapsed < minSplash) await Future<void>.delayed(minSplash - elapsed);
    if (!mounted || _routed) return;
    _routed = true;

    final profile = SavedProfile.load();
    final hasSession = store.isSignedIn || !SupabaseConfig.isConfigured;
    Widget next;
    if (profile != null && (profile.guest || hasSession)) {
      next = CustomerShell(name: profile.name, phone: profile.phone, email: profile.email, address: profile.address, designation: profile.designation);
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
  Widget build(BuildContext context) => const SplashBody();
}
