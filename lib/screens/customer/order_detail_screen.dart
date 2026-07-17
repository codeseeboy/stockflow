import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

/// One order, in full: every item and quantity, when it was placed, and which
/// demand it belongs to. Reads only the order's own lines — nothing joined in.
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context).textTheme;
    final cycle = store.cycles.where((c) => c.id == order.cycleId).firstOrNull;
    final placed = DateFormat('EEE, d MMM yyyy · h:mm a').format(order.createdAt.toLocal());

    Item? itemOf(OrderLine l) => store.items.where((i) => i.id == l.itemId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(order.displayId)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(order.displayId, style: t.titleLarge)),
                          Pill(orderStatusLabel(order.status), color: orderStatusColor(order.status)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _infoRow(context, Icons.event_outlined, placed),
                      if (cycle != null) ...[
                        const SizedBox(height: 6),
                        _infoRow(context, Icons.receipt_long_outlined, cycle.title),
                      ],
                      const SizedBox(height: 6),
                      _infoRow(context, Icons.inventory_2_outlined,
                          '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · ${fmtNum(order.totalUnits)} units'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Items in this demand', style: t.titleMedium),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < order.lines.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              EmojiTile(
                                order.lines[i].emoji,
                                color: itemOf(order.lines[i])?.cat.color ?? AppColors.brand,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.lines[i].name, style: t.titleSmall),
                                    if (itemOf(order.lines[i]) != null)
                                      Text(itemOf(order.lines[i])!.category, style: t.bodySmall),
                                  ],
                                ),
                              ),
                              Text(
                                fmtQty(order.lines[i].qty, order.lines[i].unit),
                                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Order timeline', style: t.titleMedium),
                const SizedBox(height: 4),
                Text('Where this demand stands, and who moved it there', style: t.bodySmall),
                const SizedBox(height: 10),
                AppCard(child: _OrderTimeline(order: order)),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                ),
                const BrandFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: t.bodyMedium)),
      ],
    );
  }
}

/// Created → Submitted → Viewed by admin → Accepted → Processing → Fulfilled
/// (or Rejected), each with exactly who and exactly when — so the customer
/// always knows where their demand stands without asking anyone.
class _OrderTimeline extends StatelessWidget {
  final Order order;
  const _OrderTimeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final history = order.timeline;
    final byStatus = {for (final e in history) e.status: e};
    final terminal = order.status == OrderStatus.rejected || order.status == OrderStatus.cancelled;

    // The main sequence, up to wherever this order actually is; a rejection
    // or cancellation branches off instead of continuing it.
    final steps = <_TimelineStep>[];
    for (final s in kOrderStatusSequence) {
      final event = byStatus[s];
      if (event != null) {
        steps.add(_TimelineStep(status: s, event: event, done: true));
      } else if (terminal && s != OrderStatus.pending) {
        // Nothing beyond submission happened before it was rejected/cancelled.
        break;
      } else {
        steps.add(_TimelineStep(status: s, event: null, done: false));
      }
    }
    if (terminal) {
      steps.add(_TimelineStep(status: order.status, event: byStatus[order.status], done: true));
    }

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineTile(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _TimelineStep {
  final OrderStatus status;
  final OrderStatusEvent? event;
  final bool done;
  const _TimelineStep({required this.status, required this.event, required this.done});
}

class _TimelineTile extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;
  const _TimelineTile({required this.step, required this.isLast});

  String _label(OrderStatus s) => switch (s) {
        OrderStatus.pending => 'Submitted by you',
        OrderStatus.viewed => 'Viewed by admin',
        OrderStatus.accepted => 'Accepted',
        OrderStatus.processing => 'Processing',
        OrderStatus.fulfilled => 'Fulfilled',
        OrderStatus.rejected => 'Rejected',
        OrderStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = step.done ? orderStatusColor(step.status) : scheme.outline;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: step.done ? color.withValues(alpha: 0.14) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: step.done ? 0 : 1.4),
                ),
                child: Icon(
                  step.done ? orderStatusIcon(step.status) : Icons.circle_outlined,
                  size: 14,
                  color: color,
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: scheme.outline.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _label(step.status),
                    style: t.titleSmall?.copyWith(
                      fontWeight: step.done ? FontWeight.w700 : FontWeight.w500,
                      color: step.done ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (step.event != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('EEE, d MMM · h:mm a').format(step.event!.at.toLocal())} · ${step.event!.by}',
                      style: t.bodySmall,
                    ),
                  ] else
                    Text('Not yet', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
