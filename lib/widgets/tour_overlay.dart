import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_tour.dart';

/// Wraps the app with a guided-tour spotlight: dims everything except the
/// current step's target, with a short card explaining it and Back/Skip/Next
/// controls. Rect transitions between steps are animated smoothly; a null
/// target (intro/outro) just dims the whole screen with a centered card.
///
/// Deliberately built without an external package: a solid scrim (no
/// BackdropFilter blur) keeps this cheap to repaint every frame, so moving
/// between steps stays smooth even on modest devices.
class SpotlightOverlay extends StatefulWidget {
  final TourController controller;
  final Widget child;
  const SpotlightOverlay({super.key, required this.controller, required this.child});

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  Rect? _previousRect;
  Rect? _currentRect;
  bool _resolving = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStepChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStepChanged);
    super.dispose();
  }

  void _onStepChanged() {
    if (!widget.controller.isActive) {
      setState(() {
        _previousRect = null;
        _currentRect = null;
      });
      return;
    }
    _resolveTarget();
  }

  /// Waits for the tab switch / layout to settle, scrolls the target into
  /// view if it's inside a Scrollable, then measures its screen rect.
  Future<void> _resolveTarget() async {
    final myGen = ++_generation;
    final step = widget.controller.current;
    if (step == null) return;

    if (step.targetKey == null) {
      if (!mounted || myGen != _generation) return;
      setState(() {
        _previousRect = _currentRect;
        _currentRect = null;
      });
      return;
    }

    setState(() => _resolving = true);

    BuildContext? ctx;
    // Tab switches happen inside an IndexedStack, and post-frame timing can
    // land before that tab's subtree is attached — retry briefly. The common
    // case resolves on the first pass; this only matters when a target
    // genuinely isn't mounted (e.g. no demand window open right now), so it
    // stays short rather than holding a blank screen.
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 35));
      if (!mounted || myGen != _generation) return;
      ctx = step.targetKey!.currentContext;
      if (ctx != null) break;
    }

    if (ctx != null && ctx.mounted) {
      try {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        // Not inside a Scrollable, or already visible — fine either way.
      }
    }
    if (!mounted || myGen != _generation) return;

    Rect? rect;
    final box = ctx?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached) {
      final topLeft = box.localToGlobal(Offset.zero);
      rect = topLeft & box.size;
    }

    setState(() {
      _previousRect = _currentRect;
      _currentRect = rect;
      _resolving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            if (!widget.controller.isActive) return const SizedBox.shrink();
            return _TourLayer(
              controller: widget.controller,
              previousRect: _previousRect,
              currentRect: _currentRect,
              resolving: _resolving,
              onRectSettled: (r) => _previousRect = r,
            );
          },
        ),
      ],
    );
  }
}

class _TourLayer extends StatelessWidget {
  final TourController controller;
  final Rect? previousRect;
  final Rect? currentRect;
  final bool resolving;
  final ValueChanged<Rect?> onRectSettled;
  const _TourLayer({
    required this.controller,
    required this.previousRect,
    required this.currentRect,
    required this.resolving,
    required this.onRectSettled,
  });

  @override
  Widget build(BuildContext context) {
    final step = controller.current!;
    final size = MediaQuery.sizeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scrim = dark ? Colors.black.withValues(alpha: 0.82) : Colors.black.withValues(alpha: 0.72);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          // Swallow taps on the scrim so the app underneath can't be touched
          // mid-tour — the only way through is Back / Skip / Next.
          onTap: () {},
          child: TweenAnimationBuilder<Rect?>(
            tween: RectTween(begin: previousRect, end: currentRect),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            onEnd: () => onRectSettled(currentRect),
            builder: (context, rect, _) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SpotlightPainter(rect: resolving ? null : rect, scrim: scrim)),
                  ),
                  if (!resolving) _TourCard(step: step, controller: controller, targetRect: rect, screenSize: size),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? rect;
  final Color scrim;
  const _SpotlightPainter({required this.rect, required this.scrim});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    var combined = outer;
    if (rect != null) {
      final hole = Path()..addRRect(RRect.fromRectAndRadius(rect!.inflate(8), const Radius.circular(18)));
      combined = Path.combine(PathOperation.difference, outer, hole);
    }
    canvas.drawPath(combined, Paint()..color = scrim);
    if (rect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!.inflate(8), const Radius.circular(18)),
        Paint()
          ..color = AppColors.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.rect != rect || old.scrim != scrim;
}

/// The step's text card — placed above or below the target (whichever has
/// more room), or centered when there's no target.
class _TourCard extends StatelessWidget {
  final TourStep step;
  final TourController controller;
  final Rect? targetRect;
  final Size screenSize;
  const _TourCard({required this.step, required this.controller, required this.targetRect, required this.screenSize});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const cardWidth = 320.0;
    const margin = 18.0;

    final card = Container(
      width: cardWidth,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Icon(step.icon, size: 17, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(step.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Text(step.description, style: t.bodyMedium?.copyWith(height: 1.35)),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${controller.index + 1} / ${controller.total}', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: controller.skip, child: const Text('Skip')),
              if (!controller.isFirst) ...[
                const SizedBox(width: 2),
                TextButton(onPressed: controller.back, child: const Text('Back')),
              ],
              const SizedBox(width: 2),
              FilledButton(
                onPressed: controller.next,
                child: Text(controller.isLast ? 'Done' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );

    if (targetRect == null) {
      return Center(child: SizedBox(width: cardWidth, child: card));
    }

    final spaceBelow = screenSize.height - targetRect!.bottom;
    final spaceAbove = targetRect!.top;
    final below = spaceBelow >= 190 || spaceBelow >= spaceAbove;

    var left = targetRect!.center.dx - cardWidth / 2;
    left = left.clamp(margin, screenSize.width - cardWidth - margin);

    final top = below ? targetRect!.bottom + 20 : null;
    final bottom = below ? null : (screenSize.height - targetRect!.top + 20);

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      child: SafeArea(child: card),
    );
  }
}
