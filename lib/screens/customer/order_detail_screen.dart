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
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to orders'),
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
