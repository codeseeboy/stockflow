import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/entitlement_import.dart';
import '../../utils/file_picker.dart';
import '../../widgets/ui_kit.dart';
import 'demand_builder_screen.dart';
import 'link_detail_screen.dart';

({Color color, IconData icon}) _zoneStyle(String level) {
  switch (level) {
    case 'Officers':
      return (color: AppColors.brand, icon: Icons.military_tech_rounded);
    case 'High':
      return (color: AppColors.brand, icon: Icons.workspace_premium_rounded);
    case 'Medium':
      return (color: AppColors.cDairy, icon: Icons.verified_user_rounded);
    default:
      return (color: AppColors.accent, icon: Icons.shield_outlined);
  }
}

Future<void> _editNumber(
  BuildContext context, {
  required String title,
  required double current,
  required String unit,
  required ValueChanged<double> onSave,
}) async {
  final ctrl = TextEditingController(text: fmtNum(current));
  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: unit, prefixIcon: const Icon(Icons.tune_rounded)),
        onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v.trim())),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())), child: const Text('Save')),
      ],
    ),
  );
  if (result != null) onSave(result);
}

/// Lists the ration zones. Each opens to a full management page.
class ZonesScreen extends StatelessWidget {
  const ZonesScreen({super.key});

  Future<void> _newZone(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController();
    String copyFrom = store.zoneNames.isNotEmpty ? store.zoneNames.first : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New zone / designation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A zone is a designation — Officers, Commanders, Sailors — with its own entitlement scale.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.shield_moon_outlined)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: copyFrom,
              decoration: const InputDecoration(labelText: 'Start from', prefixIcon: Icon(Icons.copy_all_outlined)),
              items: [for (final z in store.zoneNames) DropdownMenuItem(value: z, child: Text('$z scale'))],
              onChanged: (v) => copyFrom = v ?? copyFrom,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true) {
      final created = store.addZone(ctrl.text, copyFrom: copyFrom.isEmpty ? null : copyFrom);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(created ? '${ctrl.text.trim()} zone created' : 'That zone already exists'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Zones',
                subtitle: 'Designations — each with its own RIK entitlement scale, customers and demands',
                action: FilledButton.icon(
                  onPressed: () => _newZone(context, store),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New zone'),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 940 ? 3 : (c.maxWidth > 600 ? 2 : 1);
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final name in store.zoneNames)
                      SizedBox(width: w, child: _ZoneCard(zone: store.zoneFor(name), store: store)),
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

class _ZoneCard extends StatelessWidget {
  final RationZone zone;
  final AppStore store;
  const _ZoneCard({required this.zone, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final style = _zoneStyle(zone.level);
    final customers = store.customersInZone(zone.name).length;
    final links = store.linksForZone(zone.name).length;
    final orders = store.ordersInZone(zone.name).length;

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ZoneDetailScreen(zoneName: zone.name))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(style.icon, color: style.color),
              ),
              const Spacer(),
              Pill('${zone.level} tier', color: style.color),
            ],
          ),
          const SizedBox(height: 14),
          Text(zone.name, style: t.titleLarge),
          const SizedBox(height: 2),
          Text('${fmtNum(zone.monthlyTotal(store.currentMonth))} units / person · ${store.currentMonth.label}', style: t.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(icon: Icons.group_rounded, value: '$customers', label: 'customers'),
              const SizedBox(width: 8),
              _MiniStat(icon: Icons.link_rounded, value: '$links', label: 'links'),
              const SizedBox(width: 8),
              _MiniStat(icon: Icons.receipt_long_rounded, value: '$orders', label: 'orders'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Manage zone', style: t.labelLarge?.copyWith(color: style.color, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: style.color),
              const Spacer(),
              Text('${zone.perDay.length} category rates', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Column(
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Full management page for one zone: customers, ration criteria, links.
class ZoneDetailScreen extends StatelessWidget {
  final String zoneName;
  const ZoneDetailScreen({super.key, required this.zoneName});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final zone = store.zoneFor(zoneName);
    final style = _zoneStyle(zone.level);
    final customers = store.customersInZone(zoneName);
    final links = store.linksForZone(zoneName);
    final orders = store.ordersInZone(zoneName);
    final units = orders.fold<double>(0, (s, o) => s + o.totalUnits);

    return Scaffold(
      appBar: AppBar(
        title: Text(zone.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Pill('${zone.level} tier', color: style.color)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Summary stats ----
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 720 ? 4 : 2;
                  final w = (c.maxWidth - (cols - 1) * 12) / cols;
                  final tiles = [
                    StatTile(icon: Icons.shield_moon_rounded, label: '${store.currentMonth.shortLabel} entitlement', value: fmtNum(zone.monthlyTotal(store.currentMonth)), color: style.color, info: 'Total units per person this month (per-day rate × days in the month).'),
                    StatTile(icon: Icons.group_rounded, label: 'Customers', value: '${customers.length}', color: AppColors.cDairy),
                    StatTile(icon: Icons.link_rounded, label: 'Demands', value: '${links.length}', color: AppColors.accent),
                    StatTile(icon: Icons.inventory_2_rounded, label: 'Units ordered', value: fmtNum(units), color: AppColors.brand),
                  ];
                  return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
                }),
                const SizedBox(height: 20),

                // ---- Ration criteria ----
                _CriteriaCard(store: store, zone: zone),
                const SizedBox(height: 16),

                // ---- Customers ----
                _CustomersCard(customers: customers, zoneName: zoneName),
                const SizedBox(height: 16),

                // ---- Links ----
                _ZoneLinksCard(store: store, zoneName: zoneName, links: links),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CriteriaCard extends StatelessWidget {
  final AppStore store;
  final RationZone zone;
  const _CriteriaCard({required this.store, required this.zone});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final month = store.currentMonth;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Entitlement scale',
            subtitle: 'RIK ${zone.name} · per-person-per-day rates. A month = rate × ${month.days} days for ${month.label}.',
            info: 'Tap a rate to edit, or import the unit’s Excel. Every allowance — a demand or a whole month — is derived from these per-day rates.',
            action: OutlinedButton.icon(
              onPressed: () => _importSheet(context, store, zone),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Import Excel'),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(child: Text('Month total per person: ${fmtNum(zone.monthlyTotal(month))} units', style: t.bodySmall)),
            ]),
          ),
          const Divider(height: 22),
          Row(children: [
            Expanded(child: Text('Per-category entitlement', style: t.titleSmall)),
            Text('per day → ${month.shortLabel}', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          for (final cat in kCategories)
            _EditRow(
              icon: cat.icon,
              iconColor: cat.color,
              label: cat.name,
              value: '${fmtNum(zone.perDayFor(cat.name))}/day · ${fmtNum(zone.monthlyAllowance(cat.name, month))}',
              onTap: () => _editNumber(context, title: '${cat.name} per day — ${zone.name}', current: zone.perDayFor(cat.name), unit: 'per day',
                  onSave: (v) => store.setZonePerDay(zone.name, cat.name, v)),
            ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(child: Text('Per-item maximums', style: t.titleSmall)),
              TextButton.icon(
                onPressed: () => _addItemMax(context, store, zone),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (zone.itemMax.isEmpty)
            Text('No per-item limits. Add one to cap a specific item (e.g. wheat ≤ 8 kg).', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
          else
            for (final entry in zone.itemMax.entries)
              _EditRow(
                icon: Icons.straighten_rounded,
                label: entry.key,
                value: '${fmtNum(entry.value)} max',
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => store.setZoneItemMax(zone.name, entry.key, 0),
                ),
                onTap: () => _editNumber(context, title: '${entry.key} max — ${zone.name}', current: entry.value, unit: 'max',
                    onSave: (v) => store.setZoneItemMax(zone.name, entry.key, v)),
              ),
        ],
      ),
    );
  }

  /// Import the unit's entitlement Excel and apply it to this zone's per-day
  /// scale. Unmatched categories are reported, not silently dropped.
  Future<void> _importSheet(BuildContext context, AppStore store, RationZone zone) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await pickStockFile();
    if (file == null) return;
    final result = parseEntitlementFile(file.name, file.bytes);
    if (!context.mounted) return;

    final valid = result.valid;
    if (valid.isEmpty) {
      final why = result.warnings.isNotEmpty ? result.warnings.first : 'No entitlement rows recognised.';
      messenger.showSnackBar(SnackBar(content: Text(why)));
      return;
    }

    final apply = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply to ${zone.name}?'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${valid.length} categories recognised from ${file.name}:'),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in valid)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• ${r.category} — ${fmtNum(r.perDay)}/day', style: Theme.of(ctx).textTheme.bodySmall),
                        ),
                      for (final w in result.warnings)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(w, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.warning)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (apply == true) {
      final summary = store.importEntitlement(zone.name, valid);
      messenger.showSnackBar(SnackBar(content: Text('Updated ${summary.updated} categories for ${zone.name}')));
    }
  }

  Future<void> _addItemMax(BuildContext context, AppStore store, RationZone zone) async {
    final names = store.items.map((i) => i.name).where((n) => !zone.itemMax.containsKey(n)).toList()..sort();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All items already have a cap')));
      return;
    }
    String selected = names.first;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add per-item cap'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatefulBuilder(
              builder: (ctx, setSt) => DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Item', prefixIcon: Icon(Icons.inventory_2_outlined)),
                items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
                onChanged: (v) => selected = v ?? selected,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Maximum', suffixText: 'units'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text.trim()) ?? 0;
      if (v > 0) store.setZoneItemMax(zone.name, selected, v);
    }
  }
}

class _EditRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  const _EditRow({required this.icon, required this.label, required this.value, required this.onTap, this.iconColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: t.bodyLarge)),
            Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            if (trailing != null) trailing! else Icon(Icons.edit_rounded, size: 15, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}

class _CustomersCard extends StatelessWidget {
  final List<AppUser> customers;
  final String zoneName;
  const _CustomersCard({required this.customers, required this.zoneName});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Customers', subtitle: 'Users assigned to this zone', action: Pill('${customers.length}', color: AppColors.cDairy)),
          const SizedBox(height: 12),
          if (customers.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: EmptyState(icon: Icons.group_outlined, title: 'No customers in this zone yet'))
          else
            ...customers.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 18, backgroundColor: AppColors.brandWash, child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase(), style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: t.titleSmall),
                            Text([if (u.unit.isNotEmpty) u.unit, if (u.phone.isNotEmpty) u.phone].join(' · '), style: t.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _ZoneLinksCard extends StatelessWidget {
  final AppStore store;
  final String zoneName;
  final List<OrderCycle> links;
  const _ZoneLinksCard({required this.store, required this.zoneName, required this.links});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Demands',
            subtitle: 'Fresh & dry demands scoped to this zone',
            action: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DemandBuilderScreen(zone: zoneName)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Raise demand'),
            ),
          ),
          const SizedBox(height: 12),
          if (links.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: EmptyState(icon: Icons.link_off_rounded, title: 'No demands for this zone'))
          else
            ...links.map((c) {
              final open = c.status == CycleStatus.open;
              final count = store.orders.where((o) => o.cycleId == c.id).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinkDetailScreen(cycleId: c.id))),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: scheme.outline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: AppColors.brandWash, borderRadius: BorderRadius.circular(AppRadius.sm)),
                          child: const Icon(Icons.link_rounded, size: 18, color: AppColors.brand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, style: t.titleSmall),
                              Text('$count orders', style: t.bodySmall),
                            ],
                          ),
                        ),
                        Pill(open ? 'Live' : 'Closed', color: open ? AppColors.success : scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
