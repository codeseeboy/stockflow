import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

final _num = NumberFormat.decimalPattern();

String fmtNum(num v) {
  if (v == v.roundToDouble()) return _num.format(v.toInt());
  return v.toStringAsFixed(1);
}

String fmtQty(double qty, String unit) => '${fmtNum(qty)} $unit';

/// Plain bordered surface used everywhere — flat, no shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: scheme.outline),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// An "i" icon that explains a term — shows on hover (web) or tap (touch).
class InfoTip extends StatelessWidget {
  final String message;
  final double size;
  const InfoTip(this.message, {super.key, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      preferBelow: true,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadius.sm)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500, height: 1.35),
      child: Icon(Icons.info_outline_rounded, size: size, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? info;
  const SectionHeader({super.key, required this.title, this.subtitle, this.action, this.info});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(title, style: t.titleLarge, overflow: TextOverflow.ellipsis)),
                  if (info != null) ...[const SizedBox(width: 6), InfoTip(info!)],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: t.bodyMedium),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final StockStatus status;
  final bool dense;
  const StatusBadge(this.status, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    late final Color fg;
    late final Color bg;
    late final String label;
    switch (status) {
      case StockStatus.inStock:
        fg = dark ? const Color(0xFF4ADE80) : AppColors.success;
        bg = dark ? AppColors.dSuccessWash : AppColors.successWash;
        label = 'In stock';
        break;
      case StockStatus.low:
        fg = dark ? const Color(0xFFFBBF24) : AppColors.warning;
        bg = dark ? AppColors.dWarningWash : AppColors.warningWash;
        label = 'Low';
        break;
      case StockStatus.out:
        fg = dark ? const Color(0xFFFF6B6F) : AppColors.danger;
        bg = dark ? AppColors.dDangerWash : AppColors.dangerWash;
        label = 'Out';
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 12)),
        ],
      ),
    );
  }
}

/// Coloured emoji avatar tile.
class EmojiTile extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;
  const EmojiTile(this.emoji, {super.key, required this.color, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Thin rounded stock-level bar coloured by status.
class StockBar extends StatelessWidget {
  final double fraction;
  final StockStatus status;
  const StockBar({super.key, required this.fraction, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      StockStatus.inStock => AppColors.success,
      StockStatus.low => AppColors.warning,
      StockStatus.out => AppColors.danger,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: status == StockStatus.out ? 1 : fraction.clamp(0.04, 1),
        minHeight: 7,
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(status == StockStatus.out ? scheme.surfaceContainerHighest : color),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? trend;
  final String? info;
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.trend,
    this.info,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (trend != null)
                Text(trend!, style: t.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: t.headlineMedium),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(child: Text(label, style: t.bodyMedium, overflow: TextOverflow.ellipsis)),
              if (info != null) ...[const SizedBox(width: 5), InfoTip(info!, size: 13)],
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact label tag — soft colour wash, coloured text.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Icon(icon, size: 30, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center, style: t.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Faint "StockFlow" mark for the bottom of every page — deliberately quiet.
class BrandFooter extends StatelessWidget {
  const BrandFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 13, color: c),
            const SizedBox(width: 5),
            Text('StockFlow', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

/// Traffic-light colour for a usage fraction (0 = untouched, 1 = all used):
/// green while comfortable, amber past half, red near the limit.
Color usageColor(double used01) {
  if (used01 < 0.5) return AppColors.success;
  if (used01 < 0.85) return AppColors.warning;
  return AppColors.danger;
}

/// A usage bar that starts empty and fills left→right as entitlement is
/// consumed, changing colour green → amber → red.
class UsageBar extends StatelessWidget {
  final double used01;
  final double height;
  const UsageBar({super.key, required this.used01, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final v = used01.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: v),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, val, _) => LinearProgressIndicator(
          value: val,
          minHeight: height,
          color: usageColor(v),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

String relTime(DateTime time) {
  final d = DateTime.now().difference(time);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

String orderStatusLabel(OrderStatus s) => switch (s) {
      OrderStatus.pending => 'Pending',
      OrderStatus.viewed => 'Viewed',
      OrderStatus.accepted => 'Accepted',
      OrderStatus.rejected => 'Rejected',
      OrderStatus.processing => 'Processing',
      OrderStatus.fulfilled => 'Fulfilled',
      OrderStatus.cancelled => 'Cancelled',
    };

Color orderStatusColor(OrderStatus s) => switch (s) {
      OrderStatus.pending => AppColors.warning,
      OrderStatus.viewed => AppColors.cDairy,
      OrderStatus.accepted => AppColors.cEssentials,
      OrderStatus.rejected => AppColors.danger,
      OrderStatus.processing => AppColors.accent,
      OrderStatus.fulfilled => AppColors.success,
      OrderStatus.cancelled => AppColors.danger,
    };

IconData orderStatusIcon(OrderStatus s) => switch (s) {
      OrderStatus.pending => Icons.hourglass_top_rounded,
      OrderStatus.viewed => Icons.visibility_outlined,
      OrderStatus.accepted => Icons.thumb_up_outlined,
      OrderStatus.rejected => Icons.cancel_outlined,
      OrderStatus.processing => Icons.autorenew_rounded,
      OrderStatus.fulfilled => Icons.check_circle_rounded,
      OrderStatus.cancelled => Icons.block_rounded,
    };

/// The order lifecycle in the sequence it's meant to move through — used to
/// draw a timeline and to know what "still ahead" means for a given status.
/// (Rejected/cancelled are terminal branches, not part of the main sequence.)
const kOrderStatusSequence = [
  OrderStatus.pending,
  OrderStatus.viewed,
  OrderStatus.accepted,
  OrderStatus.processing,
  OrderStatus.fulfilled,
];
