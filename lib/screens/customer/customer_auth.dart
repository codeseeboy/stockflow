import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../main.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_prefs.dart';
import '../entry_screen.dart';
import 'customer_app.dart';
import 'onboarding_screen.dart';

/// Web guard: customer screens may only appear at the ROOT of the website when
/// reached via a shared order link (/c/...). If one ends up as the first route
/// on the clean URL (stale cache, session restore), bounce to the admin side.
/// Screens pushed on top of others (canPop) are always allowed.
void _bounceIfWebRoot(BuildContext context) {
  if (!kIsWeb || isCustomerOrderLink()) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    if (route?.canPop ?? false) return; // intentionally navigated here
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WebSplashScreen()),
    );
  });
}

/// Save the profile locally (so the session survives restarts) and enter the
/// app — through onboarding for brand-new users, straight to the shell otherwise.
void enterCustomerApp(
  BuildContext context, {
  required String name,
  required String phone,
  String email = '',
  String address = '',
  String designation = '',
  bool guest = false,
  bool isNewUser = false,
}) {
  final existing = SavedProfile.load();
  // Keep an existing designation if this entry didn't supply one (e.g. login).
  final desig = designation.trim().isNotEmpty ? designation.trim() : (existing?.designation ?? '');
  SavedProfile(
    name: name,
    phone: phone,
    email: email,
    address: address,
    designation: desig,
    guest: guest,
    accountCreatedAt: isNewUser ? DateTime.now() : existing?.accountCreatedAt,
  ).save();
  final Widget target = (isNewUser && !SavedProfile.onboardingDone)
      ? OnboardingScreen(name: name, phone: phone, email: email, address: address, designation: desig)
      : CustomerShell(name: name, phone: phone, email: email, address: address, designation: desig, isNewUser: isNewUser);
  final route = PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, animation, secondaryAnimation) => target,
    transitionsBuilder: (context, anim, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
  if (kIsWeb) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).pushAndRemoveUntil(route, (r) => false);
  }
}
String _friendly(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('at least') || s.contains('6 char') || s.contains('weak') || (s.contains('password') && s.contains('short'))) {
    return 'Password must be at least 6 characters.';
  }
  if (s.contains('already') || s.contains('registered') || s.contains('exists')) return 'This email is already registered. Try logging in.';
  if (s.contains('invalid') || s.contains('credential')) return 'Wrong email or password.';
  if (s.contains('not confirmed')) return 'Account created. Please confirm your email, then log in.';
  if (s.contains('network') || s.contains('socket') || s.contains('failed host')) return 'Network issue. Check your connection.';
  return 'Could not complete. $e';
}

// ---------------- Shared hero scaffold ----------------

/// Full-bleed produce illustration with overlay, floating ingredient chips and
/// a rounded sheet panel that slides up over it — the visual frame all three
/// auth screens share.
class _HeroScaffold extends StatelessWidget {
  final double heroFraction;
  final Widget panel;
  final Widget? heroOverlay;
  final bool showBack;

  const _HeroScaffold({
    required this.heroFraction,
    required this.panel,
    this.heroOverlay,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          final heroH = keyboardOpen ? 96.0 : (c.maxHeight * heroFraction).clamp(118.0, 260.0);
          return Column(
            children: [
              SizedBox(
                height: heroH,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/auth_hero.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.30),
                            Colors.black.withValues(alpha: 0.04),
                            Colors.black.withValues(alpha: 0.34),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                    if (heroOverlay != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: heroOverlay!,
                        ),
                      ),
                    if (showBack)
                      SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: _GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.maybePop(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: bg,
                  child: panel,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 21)),
      ),
    );
  }
}

/// Centered brand lockup shown over the hero image — the small piece of text
/// that sits in the open space of the illustration.
class _HeroBrand extends StatelessWidget {
  final String tagline;
  const _HeroBrand(this.tagline);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 46),
        const SizedBox(height: 12),
        Text(
          'StockFlow',
          textAlign: TextAlign.center,
          style: t.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2))],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          tagline,
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.94),
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1))],
          ),
        ),
      ],
    );
  }
}

/// Previously staggered entrance animations — now a plain passthrough.
/// Content appears immediately; nothing moves unless it means something.
List<Widget> _staggered(List<Widget> children, {int fromMs = 150, int stepMs = 70}) => children;

// ---------------- Welcome ----------------

class CustomerWelcome extends StatefulWidget {
  const CustomerWelcome({super.key});

  @override
  State<CustomerWelcome> createState() => _CustomerWelcomeState();
}

class _CustomerWelcomeState extends State<CustomerWelcome> {
  @override
  void initState() {
    super.initState();
    _bounceIfWebRoot(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return _HeroScaffold(
      heroFraction: 0.38,
      heroOverlay: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('StockFlow',
                        style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, shadows: [
                          const Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
                        ])),
                    Text('Central Store Ordering',
                        style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.90), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Place your ration demand and see your balance',
            style: t.headlineSmall?.copyWith(color: Colors.white, height: 1.15, shadows: [
              const Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2)),
            ]),
          ),
        ],
      ),
      panel: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _staggered([
                Text(
                  'Choose how you want to continue',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fast ordering for registered units, with a quick mode for one-time requests.',
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _SignalChip(icon: Icons.inventory_2_rounded, label: 'Live stock'),
                    _SignalChip(icon: Icons.schedule_rounded, label: 'Weekly window'),
                    _SignalChip(icon: Icons.verified_rounded, label: 'Tracked orders'),
                  ],
                ),
                const SizedBox(height: 22),
                _WelcomeActionCard(
                  icon: Icons.login_rounded,
                  title: 'Log in',
                  subtitle: 'For registered units and returning users',
                  color: AppColors.brand,
                  filled: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerLogin())),
                ),
                const SizedBox(height: 12),
                _WelcomeActionCard(
                  icon: Icons.person_add_alt_rounded,
                  title: 'Create account',
                  subtitle: 'Save your unit details for future orders',
                  color: AppColors.accent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerRegister())),
                ),
                const SizedBox(height: 12),
                _WelcomeActionCard(
                  icon: Icons.flash_on_rounded,
                  title: 'Continue without account',
                  subtitle: 'Place a quick request without saving login details',
                  color: AppColors.cDairy,
                  compact: true,
                  onTap: () => quickStartSheet(context),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.desktop_windows_rounded, color: scheme.onSurfaceVariant, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Store staff can manage stock, orders and reports from the web console.',
                          style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

}

class _SignalChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SignalChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _WelcomeActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final bool compact;

  const _WelcomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = filled ? Colors.white : scheme.onSurface;
    final bg = filled ? color : scheme.surface;
    final sub = filled ? Colors.white.withValues(alpha: 0.86) : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: filled ? color : scheme.outline),
            boxShadow: filled ? [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))] : null,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 42 : 48,
                height: compact ? 42 : 48,
                decoration: BoxDecoration(
                  color: filled ? Colors.white.withValues(alpha: 0.18) : color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: filled ? Colors.white : color, size: compact ? 20 : 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: t.bodySmall?.copyWith(color: sub, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, color: filled ? Colors.white : color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Login ----------------

class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});
  @override
  State<CustomerLogin> createState() => _CustomerLoginState();
}

class _CustomerLoginState extends State<CustomerLogin> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bounceIfWebRoot(context);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await store.signIn(_email.text.trim(), _password.text);
      final p = await store.myProfile();
      final email = _email.text.trim();
      final profileName = p?.name.trim() ?? '';
      final name = profileName.isNotEmpty && !profileName.contains('@') ? profileName : 'Unit';
      if (!mounted) return;
      enterCustomerApp(context, name: name, phone: p?.phone ?? '', email: email, designation: p?.zone ?? '');
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return _HeroScaffold(
      heroFraction: 0.32,
      showBack: true,
      heroOverlay: const _HeroBrand("This week's order, made simple"),
      panel: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._staggered([
                  Text('Welcome back', textAlign: TextAlign.center, style: t.headlineSmall),
                  const SizedBox(height: 6),
                  Text("Log in to place this week's order.", textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBox(_error!),
                ],
                const SizedBox(height: 22),
                ..._staggered(fromMs: 360, [
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                      child: _loading
                          ? const SizedBox(key: ValueKey('l'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Log in', key: ValueKey('t')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('New here?', style: t.bodyMedium),
                      TextButton(
                        onPressed: () => Navigator.canPop(context)
                            ? Navigator.pop(context)
                            : Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CustomerRegister())),
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Register ----------------

class CustomerRegister extends StatefulWidget {
  const CustomerRegister({super.key});
  @override
  State<CustomerRegister> createState() => _CustomerRegisterState();
}

class _CustomerRegisterState extends State<CustomerRegister> {
  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+91 ');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();
  String _zone = kZoneNames.first;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bounceIfWebRoot(context);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name or unit.');
      return;
    }
    final store = context.read<AppStore>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await store.signUpCustomer(_email.text.trim(), _password.text, name, _phone.text.trim(), zone: _zone);
      if (!mounted) return;
      enterCustomerApp(context,
          name: name,
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          designation: _zone,
          isNewUser: true);
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return _HeroScaffold(
      heroFraction: 0.28,
      showBack: Navigator.canPop(context),
      heroOverlay: const _HeroBrand('Supplies for your unit, every week'),
      panel: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._staggered(stepMs: 55, [
                  Text('Create your account', textAlign: TextAlign.center, style: t.headlineSmall),
                  const SizedBox(height: 6),
                  Text('Order every week without re-entering details.',
                      textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name / unit', prefixIcon: Icon(Icons.storefront_rounded))),
                  const SizedBox(height: 14),
                  TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded))),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _zone,
                    decoration: const InputDecoration(
                      labelText: 'Ration scale',
                      helperText: 'Your RIK entitlement scale — decides what you can draw',
                      prefixIcon: Icon(Icons.shield_moon_outlined),
                    ),
                    items: [
                      for (final z in kZoneNames) DropdownMenuItem(value: z, child: Text(z)),
                    ],
                    onChanged: (v) => setState(() => _zone = v ?? _zone),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined))),
                  const SizedBox(height: 14),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded))),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBox(_error!),
                ],
                const SizedBox(height: 22),
                ..._staggered(fromMs: 500, [
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                      child: _loading
                          ? const SizedBox(key: ValueKey('l'), height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create account', key: ValueKey('t')),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: t.bodyMedium),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerLogin())),
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => quickStartSheet(context),
                      style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
                      child: const Text('Continue without an account'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quick guest order sheet — name, phone, address, no login. Shared by the
/// register screen and the web welcome screen.
void quickStartSheet(BuildContext context) {
  final nameC = TextEditingController();
  final phoneC = TextEditingController(text: '+91 ');
  final addrC = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheetCtx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick start', style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('No account needed — just tell us who the order is for.', style: Theme.of(sheetCtx).textTheme.bodyMedium),
          const SizedBox(height: 18),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Your name / unit', prefixIcon: Icon(Icons.storefront_rounded))),
          const SizedBox(height: 12),
          TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_rounded))),
          const SizedBox(height: 12),
          TextField(controller: addrC, maxLines: 2, decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.location_on_outlined))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(sheetCtx);
              enterCustomerApp(context,
                  name: name, phone: phoneC.text.trim(), address: addrC.text.trim(), designation: kZoneNames.first, guest: true, isNewUser: true);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.dangerWash, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
    );
  }
}
