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
    final fresh = cycle.type == DemandType.fresh;
    final itemCount = store.itemsForCycle(cycle).length;

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
                        Pill('${cycle.type.label} · ${cycle.days} days', color: fresh ? AppColors.success : AppColors.accent, icon: fresh ? Icons.eco_rounded : Icons.grain_rounded),
                        Pill(cycle.month.label, color: AppColors.cBakery, icon: Icons.calendar_month_rounded),
                        Pill(zoneLabel, color: AppColors.brand, icon: Icons.shield_moon_rounded),
                        Pill('$itemCount items', color: AppColors.cVeg, icon: Icons.playlist_add_check_rounded),
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
                          OutlinedButton.icon(
                            onPressed: () => _editItems(context, store, cycle),
                            icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                            label: const Text('Edit items'),
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

  /// Edit which varieties are on this demand after it's opened — same "only
  /// ticked items reach the customer" rule as when raising it.
  Future<void> _editItems(BuildContext context, AppStore store, OrderCycle cycle) async {
    // Candidates = every article valid for this demand's ration type.
    final candidates = store.items
        .where((i) => itemAllowedIn(cycle.type, i.category, i.name))
        .toList();
    final selected = <String>{
      ...(cycle.hasCuratedList ? cycle.itemIds : candidates.map((i) => i.id)),
    };
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditItemsSheet(cycle: cycle, candidates: candidates, initial: selected),
    );
    if (result != null) {
      store.setCycleItems(cycle, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.length} items on ${cycle.title}')));
      }
    }
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

/// Tick/untick the varieties on a demand. Grouped by category, with a per-group
/// select-all — the same picker used when raising the demand.
class _EditItemsSheet extends StatefulWidget {
  final OrderCycle cycle;
  final List<Item> candidates;
  final Set<String> initial;
  const _EditItemsSheet({required this.cycle, required this.candidates, required this.initial});

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

class _EditItemsSheetState extends State<_EditItemsSheet> {
  late final Set<String> _selected = {...widget.initial};

  Map<String, List<Item>> get _grouped {
    final map = <String, List<Item>>{};
    for (final cat in kCategories) {
      final inCat = widget.candidates.where((i) => i.category == cat.name).toList();
      if (inCat.isNotEmpty) map[cat.name] = inCat;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final grouped = _grouped;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(widget.cycle.type == DemandType.fresh ? Icons.eco_rounded : Icons.grain_rounded, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(child: Text('Items on ${widget.cycle.title}', style: t.titleLarge)),
              Text('${_selected.length}', style: t.titleMedium?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text('Only ticked items appear to the customer.', style: t.bodySmall),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  for (final e in grouped.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(categoryOf(e.key).icon, size: 16, color: categoryOf(e.key).color),
                            const SizedBox(width: 8),
                            Text(e.key, style: t.titleSmall),
                            const Spacer(),
                            TextButton(
                              onPressed: () => setState(() {
                                final ids = e.value.map((i) => i.id);
                                final allOn = e.value.every((i) => _selected.contains(i.id));
                                allOn ? _selected.removeAll(ids) : _selected.addAll(ids);
                              }),
                              child: Text(e.value.every((i) => _selected.contains(i.id)) ? 'Clear' : 'All'),
                            ),
                          ]),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final i in e.value)
                              FilterChip(
                                selected: _selected.contains(i.id),
                                onSelected: (on) => setState(() => on ? _selected.add(i.id) : _selected.remove(i.id)),
                                avatar: Text(i.emoji, style: const TextStyle(fontSize: 15)),
                                label: Text(i.name),
                                showCheckmark: false,
                                selectedColor: AppColors.brandWash,
                                shape: const StadiumBorder(),
                              ),
                          ]),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
                  child: const Text('Save items'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
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
