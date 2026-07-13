import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'link_detail_screen.dart';

/// Neat, scannable list of every ration link. Each row opens a full management
/// page ([LinkDetailScreen]).
class CyclesScreen extends StatelessWidget {
  const CyclesScreen({super.key});

  String _range(OrderCycle c) {
    final f = DateFormat('MMM d');
    return '${f.format(c.weekStart)} – ${f.format(c.weekEnd)}, ${c.weekEnd.year}';
  }

  /// Prompt for an optional zone, then open a new link alongside any already
  /// live (several links can be open at once).
  void _newLink(BuildContext context, AppStore store) {
    String? zone = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New order link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scope the link to a zone, or leave it open to everyone. Existing open links stay live.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: '',
              decoration: const InputDecoration(labelText: 'Zone', prefixIcon: Icon(Icons.shield_moon_outlined)),
              items: [
                const DropdownMenuItem(value: '', child: Text('All zones (everyone)')),
                for (final z in store.zoneNames) DropdownMenuItem(value: z, child: Text(z)),
              ],
              onChanged: (v) => zone = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final c = store.openNewCycle(designation: zone ?? '', closeOthers: false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.title} link generated')));
            },
            child: const Text('Generate link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context).textTheme;
    final all = store.cyclesByRecent;
    final live = all.where((c) => c.status == CycleStatus.open).toList();
    final past = all.where((c) => c.status != CycleStatus.open).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Order links',
                subtitle: 'Every ration link — tap one to manage it',
                action: FilledButton.icon(
                  onPressed: () => _newLink(context, store),
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text('New link'),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.circle, size: 9, color: AppColors.success),
                const SizedBox(width: 7),
                Text('Live now', style: t.titleMedium),
                const SizedBox(width: 8),
                Pill('${live.length}', color: AppColors.success),
              ]),
              const SizedBox(height: 10),
              if (live.isEmpty)
                const EmptyState(icon: Icons.link_off_rounded, title: 'No live links', subtitle: 'Generate a link to open ordering.')
              else
                ...live.map((c) => _LinkRow(store: store, cycle: c, range: _range(c))),
              const SizedBox(height: 24),
              Text('Past links', style: t.titleMedium),
              const SizedBox(height: 10),
              if (past.isEmpty)
                const EmptyState(icon: Icons.history_rounded, title: 'No past links yet')
              else
                ...past.map((c) => _LinkRow(store: store, cycle: c, range: _range(c))),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final AppStore store;
  final OrderCycle cycle;
  final String range;
  const _LinkRow({required this.store, required this.cycle, required this.range});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final open = cycle.status == CycleStatus.open;
    final count = store.orders.where((o) => o.cycleId == cycle.id).length;
    final zoneLabel = cycle.isPublic ? 'All zones' : cycle.designation;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinkDetailScreen(cycleId: cycle.id))),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: (open ? AppColors.brand : scheme.onSurfaceVariant).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(open ? Icons.link_rounded : Icons.history_rounded, color: open ? AppColors.brand : scheme.onSurfaceVariant, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle.title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(range, style: t.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pill(zoneLabel, color: AppColors.accent, icon: Icons.shield_moon_rounded),
                    Pill('$count orders', color: AppColors.cDairy, icon: Icons.receipt_long_rounded),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pill(open ? 'Live' : 'Closed', color: open ? AppColors.success : scheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
