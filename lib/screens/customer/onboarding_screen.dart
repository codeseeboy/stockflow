import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_prefs.dart';
import 'customer_app.dart';

/// First-run onboarding shown right after account creation.
///
/// Instead of stock illustrations, each page is a live miniature of the app
/// itself — stock cards filling in, an order being composed, a delivery
/// timeline progressing — so new users see exactly what they'll get.
class OnboardingScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String designation;

  const OnboardingScreen({
    super.key,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.designation = '',
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    }
  }

  void _finish() {
    SavedProfile.markOnboardingDone();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => CustomerShell(
          name: widget.name,
          phone: widget.phone,
          email: widget.email,
          address: widget.address,
          designation: widget.designation,
        ),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: child,
        ),
      ),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final washes = dark
        ? const [Color(0xFF10241C), Color(0xFF241D10), Color(0xFF101C24)]
        : const [AppColors.brandWash, AppColors.accentWash, Color(0xFFE3EEFA)];

    final pages = [
      _PageData(
        title: 'See live stock before you order',
        subtitle:
            'Quantities in the central store update in real time, so you always know what\'s available before the window closes.',
        scene: (active) => _StockScene(active: active),
      ),
      _PageData(
        title: 'Your weekly order, done in minutes',
        subtitle:
            'Add items, set quantities, submit. Your unit\'s details are remembered — no calls and no paperwork.',
        scene: (active) => _OrderScene(active: active),
      ),
      _PageData(
        title: 'Track it to your doorstep',
        subtitle:
            'Follow every order from pending to delivered, with status updates from the store team as it moves.',
        scene: (active) => _TrackScene(active: active),
      ),
    ];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [washes[_page], Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: progress + skip.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 8, 0),
                child: Row(
                  children: [
                    Text('Hi ${widget.name.split(' ').first}', style: t.titleMedium),
                    const Spacer(),
                    TextButton(onPressed: _finish, child: const Text('Skip')),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pageCount,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final p = pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          Expanded(child: Center(child: p.scene(_page == i))),
                          Text(p.title, textAlign: TextAlign.center, style: t.headlineSmall)
                              .animate(key: ValueKey('title$i-${_page == i}'))
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.2, curve: Curves.easeOutCubic),
                          const SizedBox(height: 10),
                          Text(p.subtitle,
                                  textAlign: TextAlign.center,
                                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5))
                              .animate(key: ValueKey('sub$i-${_page == i}'))
                              .fadeIn(delay: 120.ms, duration: 400.ms),
                          const SizedBox(height: 28),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Bottom controls.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  children: [
                    for (var i = 0; i < _pageCount; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 7),
                        width: i == _page ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? scheme.primary : scheme.outline,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                        child: Text(
                          _page == _pageCount - 1 ? 'Get started' : 'Next',
                          key: ValueKey(_page == _pageCount - 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageData {
  final String title;
  final String subtitle;
  final Widget Function(bool active) scene;
  const _PageData({required this.title, required this.subtitle, required this.scene});
}

// ---------------- Scene shared pieces ----------------

class _SceneCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _SceneCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline),
        boxShadow: [BoxShadow(color: const Color(0xFF12201C).withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

/// A stock bar that fills to [fraction] with an ease-out sweep.
class _FillBar extends StatelessWidget {
  final double fraction;
  final Color color;
  const _FillBar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 7,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

// ---------------- Scene 1: live stock ----------------

class _StockScene extends StatelessWidget {
  final bool active;
  const _StockScene({required this.active});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('🍚', 'Basmati Rice', '920 kg', 0.78, AppColors.success),
      ('🍅', 'Tomato', '70 kg', 0.23, AppColors.warning),
      ('🥛', 'Milk', '250 L', 0.62, AppColors.success),
    ];
    final t = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SceneCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rows[i].$5.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(rows[i].$1, style: const TextStyle(fontSize: 21)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(rows[i].$2, style: t.titleSmall)),
                              Text(rows[i].$3, style: t.labelMedium?.copyWith(color: rows[i].$5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _FillBar(fraction: rows[i].$4, color: rows[i].$5),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate(key: ValueKey('stock$i$active'))
                .fadeIn(delay: (150 + i * 160).ms, duration: 450.ms)
                .slideX(begin: i.isEven ? -0.15 : 0.15, delay: (150 + i * 160).ms, duration: 450.ms, curve: Curves.easeOutCubic),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.3, end: 1, duration: 900.ms, curve: Curves.easeInOut),
                const SizedBox(width: 7),
                const Text('Updating live',
                    style: TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          )
              .animate(key: ValueKey('live$active'))
              .fadeIn(delay: 700.ms, duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8), delay: 700.ms, curve: Curves.easeOutBack, duration: 400.ms),
        ],
      ),
    );
  }
}

// ---------------- Scene 2: compose an order ----------------

class _OrderScene extends StatelessWidget {
  final bool active;
  const _OrderScene({required this.active});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lines = [
      ('🍚', 'Basmati Rice', '40 kg'),
      ('🥛', 'Milk', '30 L'),
      ('🥚', 'Eggs', '12 dz'),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SceneCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Week 24 order', style: t.titleSmall),
                    const Spacer(),
                    Text('Alpha Mess', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text(lines[i].$1, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(lines[i].$2, style: t.bodyLarge)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(lines[i].$3, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  )
                      .animate(key: ValueKey('line$i$active'))
                      .fadeIn(delay: (200 + i * 150).ms, duration: 400.ms)
                      .slideY(begin: 0.4, delay: (200 + i * 150).ms, duration: 400.ms, curve: Curves.easeOutCubic),
                const Divider(height: 20),
                Row(
                  children: [
                    Text('3 items', style: t.bodyMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Text('Place order',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ).animate(key: ValueKey('cta$active')).fadeIn(delay: 750.ms, duration: 400.ms),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.successWash,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                SizedBox(width: 7),
                Text('Order placed · ORD-1042',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          )
              .animate(key: ValueKey('done$active'))
              .fadeIn(delay: 1100.ms, duration: 350.ms)
              .scale(begin: const Offset(0.6, 0.6), delay: 1100.ms, duration: 500.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

// ---------------- Scene 3: order tracking ----------------

class _TrackScene extends StatelessWidget {
  final bool active;
  const _TrackScene({required this.active});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final steps = [
      (Icons.receipt_long_rounded, 'Order placed', 'Sunday, 7:42 PM', true),
      (Icons.task_alt_rounded, 'Confirmed by store', 'Monday, 9:10 AM', true),
      (Icons.inventory_2_rounded, 'Packed & dispatched', 'Tuesday, 8:30 AM', true),
      (Icons.local_shipping_rounded, 'Delivered to Block A', 'Tuesday, 11:05 AM', false),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: _SceneCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ORD-1042', style: t.titleSmall),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successWash,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text('Delivered',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
                )
                    .animate(key: ValueKey('badge$active'))
                    .fadeIn(delay: 1350.ms, duration: 350.ms)
                    .scale(begin: const Offset(0.6, 0.6), delay: 1350.ms, curve: Curves.easeOutBack, duration: 450.ms),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: steps[i].$4 ? AppColors.brand.withValues(alpha: 0.13) : AppColors.successWash,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(steps[i].$1, size: 17, color: steps[i].$4 ? AppColors.brand : AppColors.success),
                        ),
                        if (i != steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2.4,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(steps[i].$2, style: t.titleSmall),
                            const SizedBox(height: 2),
                            Text(steps[i].$3, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate(key: ValueKey('step$i$active'))
                  .fadeIn(delay: (250 + i * 280).ms, duration: 420.ms)
                  .slideY(begin: 0.3, delay: (250 + i * 280).ms, duration: 420.ms, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}
