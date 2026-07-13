import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notify_customers_sheet.dart';
import '../../widgets/ui_kit.dart';

/// Full management page for a single order link (cycle): status, share URL,
/// the zone it belongs to, every order placed against it, and actions.
class LinkDetailScreen extends StatelessWidget {
  final String cycleId;
  const LinkDetailScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cycle = store.cycles.where((c) => c.id == cycleId).firstOrNull;
    if (cycle == null) {
      return const Scaffold(body: Center(child: Text('Link not found')));
    }
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final open = cycle.status == CycleStatus.open;
    final orders = store.orders.where((o) => o.cycleId == cycle.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final range = '${DateFormat('d MMM').format(cycle.weekStart)} – ${DateFormat('d MMM yyyy').format(cycle.weekEnd)}';
    final units = orders.fold<double>(0, (s, o) => s + o.totalUnits);
    final zoneLabel = cycle.isPublic ? 'All zones' : cycle.designation;

    return Scaffold(
      appBar: AppBar(title: Text(cycle.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Status header ----
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(color: AppColors.brandWash, borderRadius: BorderRadius.circular(AppRadius.md)),
                            child: const Icon(Icons.link_rounded, color: AppColors.brand),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cycle.title, style: t.titleLarge, overflow: TextOverflow.ellipsis),
                                Text(range, style: t.bodyMedium),
                              ],
                            ),
                          ),
                          Pill(open ? 'Live' : 'Closed', color: open ? AppColors.success : scheme.onSurfaceVariant, icon: open ? Icons.circle : Icons.lock_rounded),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Pill(zoneLabel, color: AppColors.accent, icon: Icons.shield_moon_rounded),
                        Pill('${orders.length} orders', color: AppColors.cDairy, icon: Icons.receipt_long_rounded),
                        Pill('${fmtNum(units)} units', color: AppColors.brand, icon: Icons.inventory_2_rounded),
                      ]),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Row(
                          children: [
                            const Icon(Icons.public_rounded, size: 18, color: AppColors.brand),
                            const SizedBox(width: 10),
                            Expanded(child: Text(cycle.link, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                            IconButton(
                              tooltip: 'Copy link',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: cycle.link));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _notify(context, store, cycle),
                            icon: const Icon(Icons.campaign_rounded, size: 18),
                            label: const Text('Notify customers'),
                          ),
                          if (open)
                            OutlinedButton.icon(
                              onPressed: () {
                                store.closeCycle(cycle);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link closed')));
                              },
                              icon: const Icon(Icons.lock_rounded, size: 18),
                              label: const Text('Close link'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () {
                                store.reopenCycle(cycle);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link reopened')));
                              },
                              icon: const Icon(Icons.lock_open_rounded, size: 18),
                              label: const Text('Reopen link'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(title: 'Orders on this link', subtitle: '${orders.length} placed · ${fmtNum(units)} total units'),
                const SizedBox(height: 12),
                if (orders.isEmpty)
                  const EmptyState(icon: Icons.receipt_long_rounded, title: 'No orders yet', subtitle: 'Orders placed on this link will appear here.')
                else
                  ...orders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OrderCard(order: o),
                      )),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _notify(BuildContext context, AppStore store, OrderCycle cycle) async {
    final body = 'Place your ${cycle.title} ration order before the link closes.';
    final result = await showNotifyCustomersSheet(context, title: '${cycle.title} is open', body: body);
    if (result != null && context.mounted) {
      await showBroadcastDeliveryDialog(
        context,
        result,
        message: '${cycle.title} ration link is open. $body Order here: ${cycle.link}',
        subject: 'Ration order — ${cycle.title}',
      );
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.brandWash,
                child: Text(order.customerName.isEmpty ? '?' : order.customerName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName, style: t.titleSmall),
                    Text('${order.id} · ${order.itemCount} items · ${relTime(order.createdAt)}', style: t.bodySmall),
                  ],
                ),
              ),
              Pill(orderStatusLabel(order.status), color: orderStatusColor(order.status)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in order.lines)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text('${l.emoji} ${l.name} · ${fmtQty(l.qty, l.unit)}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
          ]),
        ],
      ),
    );
  }
}
