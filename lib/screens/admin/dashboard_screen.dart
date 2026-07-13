import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notify_customers_sheet.dart';
import '../../widgets/ui_kit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cycle = store.orderingCycle;
    final isLive = cycle.status == CycleStatus.open;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLive) ...[
                _LiveOrderBanner(store: store, cycle: cycle),
                const SizedBox(height: 18),
              ],
              _AlertBanner(store: store),
              _StatGrid(store: store),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 860;
                final left = Column(
                  children: [
                    _RecentOrders(store: store),
                  ],
                );
                final right = _AttentionCard(store: store);
                if (!wide) {
                  return Column(children: [right, const SizedBox(height: 16), left]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: right),
                  ],
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent live order link — impossible to miss when the window is open.
class _LiveOrderBanner extends StatelessWidget {
  final AppStore store;
  final OrderCycle cycle;
  const _LiveOrderBanner({required this.store, required this.cycle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final deadline = DateFormat('EEE, d MMM').format(cycle.weekEnd);
    final orderCount = store.orders.where((o) => o.cycleId == cycle.id).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D7A52), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: const Color(0xFF0D7A52).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF7CFFB2), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('LIVE NOW', style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text('$orderCount orders', style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('${cycle.title} — order link is open', style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Customers can order until $deadline · closes 11:59 PM', style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(cycle.link, style: t.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: 'Copy link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cycle.link));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order link copied')));
                  },
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF065F46)),
            onPressed: () async {
              const body = 'Place your weekly order before the window closes.';
              final result = await showNotifyCustomersSheet(
                context,
                title: '${cycle.title} order link is open',
                body: body,
              );
              if (result != null && context.mounted) {
                await showBroadcastDeliveryDialog(
                  context,
                  result,
                  message: '${cycle.title} order link is open. $body',
                  subject: 'StockFlow — ${cycle.title} order window is open',
                );
              }
            },
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: const Text('Notify all customers'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }
}

class _AlertBanner extends StatelessWidget {
  final AppStore store;
  const _AlertBanner({required this.store});

  @override
  Widget build(BuildContext context) {
    final out = store.outCount;
    final low = store.lowCount;
    if (out == 0 && low == 0) return const SizedBox.shrink();
    final critical = out > 0;
    final color = critical ? AppColors.danger : AppColors.warning;
    final wash = critical ? AppColors.dangerWash : AppColors.warningWash;
    final t = Theme.of(context).textTheme;

    final parts = <String>[];
    if (out > 0) parts.add('$out out of stock');
    if (low > 0) parts.add('$low running low');

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: wash,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(critical ? Icons.error_rounded : Icons.warning_amber_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(critical ? 'Action needed' : 'Heads up', style: t.titleSmall?.copyWith(color: color)),
                  const SizedBox(height: 2),
                  Text('${parts.join(' · ')}. Restock soon to avoid missed orders.', style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final AppStore store;
  const _StatGrid({required this.store});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      StatTile(icon: Icons.inventory_2_rounded, label: 'Total items', value: '${store.totalItems}', color: AppColors.brand, info: 'Products in catalogue.'),
      StatTile(icon: Icons.trending_down_rounded, label: 'Running low', value: '${store.lowCount}', color: AppColors.warning, info: 'Below reorder level.'),
      StatTile(icon: Icons.error_outline_rounded, label: 'Out of stock', value: '${store.outCount}', color: AppColors.danger, info: 'Zero stock items.'),
      StatTile(icon: Icons.receipt_long_rounded, label: 'Orders this week', value: '${store.ordersThisCycle.length}', color: AppColors.cDairy, info: 'Orders in active cycle.'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 2 : 2);
      final w = (c.maxWidth - (cols - 1) * 14) / cols;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _AttentionCard extends StatelessWidget {
  final AppStore store;
  const _AttentionCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final items = [...store.outOfStockItems, ...store.lowStockItems];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Needs attention',
            subtitle: 'Predicted to run out soon',
            action: Pill('${items.length}', color: AppColors.warning),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: EmptyState(icon: Icons.verified_rounded, title: 'Everything stocked', subtitle: 'No items below reorder level.'),
            )
          else
            ...items.take(6).map((i) => _AttentionRow(item: i, store: store)),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final Item item;
  final AppStore store;
  const _AttentionRow({required this.item, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = store.daysLeft(item);
    final out = item.status == StockStatus.out;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          EmojiTile(item.emoji, color: item.cat.color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                    StatusBadge(item.status, dense: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  out ? 'Out of stock' : '${fmtQty(item.currentQty, item.unit)} left${d != null ? ' · ~$d days' : ''}',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              store.restock(item, item.openingQty - item.currentQty <= 0 ? item.openingQty : item.openingQty - item.currentQty);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} restocked')));
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }
}

class _RecentOrders extends StatelessWidget {
  final AppStore store;
  const _RecentOrders({required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final orders = store.orders.take(4).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recent orders', subtitle: 'Latest activity from customers'),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: EmptyState(icon: Icons.receipt_long_rounded, title: 'No orders yet'))
          else
            ...orders.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.brandWash,
                        child: Text(o.customerName.substring(0, 1), style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.customerName, style: t.titleSmall),
                            Text('${o.itemCount} items · ${relTime(o.createdAt)}', style: t.bodySmall),
                          ],
                        ),
                      ),
                      Pill(orderStatusLabel(o.status), color: orderStatusColor(o.status)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
