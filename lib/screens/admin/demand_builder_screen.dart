import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import 'link_detail_screen.dart';

/// The admin's "raise a demand" flow — exactly what the unit described:
/// pick fresh or dry, the zone, the month and span, then tick the varieties to
/// put on the list ("30 varieties in fruit, I'll allow 9 or 10"). Whatever is
/// left unticked, the customer never sees.
class DemandBuilderScreen extends StatefulWidget {
  final String? zone; // pre-scoped when opened from a zone
  const DemandBuilderScreen({super.key, this.zone});

  @override
  State<DemandBuilderScreen> createState() => _DemandBuilderScreenState();
}

class _DemandBuilderScreenState extends State<DemandBuilderScreen> {
  DemandType _type = DemandType.fresh;
  late String _zone;
  late RationMonth _month;
  late int _days;
  int _week = 1; // week of the month (1..5) a fresh demand starts in
  final Set<String> _selected = {};
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _zone = widget.zone ?? '';
    _month = RationMonth.of(DateTime.now());
    _days = _type.defaultDays;
  }

  int get _weeksInMonth => ((_month.days + 6) ~/ 7);

  /// The date this demand starts: Week N of the chosen month for fresh,
  /// always the 1st for dry.
  DateTime get _startDate => _type == DemandType.dry
      ? _month.firstDay
      : _month.firstDay.add(Duration(days: (_week - 1) * 7));

  /// Items valid for the current ration type, grouped by category. Once a
  /// zone is picked, only that zone's own stock (plus items that predate
  /// zone-scoped stock) is offered — a demand for Officers must never let
  /// the admin curate it from Sailors' separate stock pool.
  Map<String, List<Item>> _grouped(AppStore store) {
    final map = <String, List<Item>>{};
    for (final cat in kCategories) {
      final inCat = store.items
          .where((i) =>
              i.category == cat.name &&
              itemAllowedIn(_type, i.category, i.name) &&
              (_zone.isEmpty || i.zone.isEmpty || i.zone == _zone))
          .toList();
      if (inCat.isNotEmpty) map[cat.name] = inCat;
    }
    return map;
  }

  void _reseedForType(AppStore store) {
    // Default to everything valid for the type selected, so the common case
    // (allow all) is one tap; the admin then unticks what they don't want.
    _selected
      ..clear()
      ..addAll(_grouped(store).values.expand((l) => l).map((i) => i.id));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    if (!_seeded) {
      _reseedForType(store);
      _seeded = true;
    }
    final t = Theme.of(context).textTheme;
    final grouped = _grouped(store);
    final totalValid = grouped.values.fold<int>(0, (s, l) => s + l.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Raise a demand')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'What are you accepting?',
                  subtitle: 'Fresh runs in ~10-day demands; dry covers the whole month. Only ticked items reach the customer.',
                ),
                const SizedBox(height: 14),

                // ---- Fresh / dry ----
                Row(
                  children: [
                    Expanded(child: _TypeCard(
                      type: DemandType.fresh,
                      selected: _type == DemandType.fresh,
                      onTap: () => setState(() {
                        _type = DemandType.fresh;
                        _days = _type.defaultDays;
                        _reseedForType(store);
                      }),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _TypeCard(
                      type: DemandType.dry,
                      selected: _type == DemandType.dry,
                      onTap: () => setState(() {
                        _type = DemandType.dry;
                        _days = _type.defaultDays;
                        _reseedForType(store);
                      }),
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                // ---- Zone / month / days ----
                AppCard(
                  child: Column(
                    children: [
                      _fieldRow(
                        icon: Icons.shield_moon_outlined,
                        label: 'Zone',
                        child: DropdownButton<String>(
                          value: _zone,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('All zones (everyone)')),
                            for (final z in store.zoneNames) DropdownMenuItem(value: z, child: Text(z)),
                          ],
                          onChanged: (v) => setState(() {
                            _zone = v ?? '';
                            // Zones don't share stock — re-default the ticked
                            // items to whatever's actually available for the
                            // newly picked zone rather than leaving stale
                            // ticks from a different zone's pool.
                            _reseedForType(store);
                          }),
                        ),
                      ),
                      const Divider(height: 18),
                      _fieldRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Entitlement month',
                        child: DropdownButton<String>(
                          value: _month.key,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [for (final m in _monthChoices()) DropdownMenuItem(value: m.key, child: Text(m.label))],
                          onChanged: (v) => setState(() => _month = RationMonth.tryParse(v ?? '') ?? _month),
                        ),
                      ),
                      if (_type == DemandType.fresh) ...[
                        const Divider(height: 18),
                        _fieldRow(
                          icon: Icons.date_range_outlined,
                          label: 'Starts in week',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var w = 1; w <= _weeksInMonth; w++)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    label: Text('W$w'),
                                    selected: _week == w,
                                    onSelected: (_) => setState(() => _week = w),
                                    shape: const StadiumBorder(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 18),
                      _fieldRow(
                        icon: Icons.event_repeat_outlined,
                        label: 'Days this demand covers',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final d in const [5, 10, 15, 30])
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text('$d'),
                                  selected: _days == d,
                                  onSelected: (_) => setState(() => _days = d),
                                  shape: const StadiumBorder(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 18),
                      _fieldRow(
                        icon: Icons.today_outlined,
                        label: 'Runs',
                        child: Text(
                          '${DateFormat('d MMM').format(_startDate)} – ${DateFormat('d MMM').format(_startDate.add(Duration(days: _days - 1)))}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Variety picker ----
                Row(
                  children: [
                    Expanded(child: Text('Items on this demand', style: t.titleMedium)),
                    Text('${_selected.length} / $totalValid', style: t.titleSmall?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tick the varieties to put on the list. Bread appears in both fresh and dry.',
                    style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                if (grouped.isEmpty)
                  const EmptyState(icon: Icons.inventory_2_outlined, title: 'No items for this ration type')
                else
                  ...grouped.entries.map((e) => _CategoryPicker(
                        category: categoryOf(e.key),
                        items: e.value,
                        selected: _selected,
                        onToggleItem: (id, on) => setState(() => on ? _selected.add(id) : _selected.remove(id)),
                        onToggleAll: (on) => setState(() {
                          final ids = e.value.map((i) => i.id);
                          on ? _selected.addAll(ids) : _selected.removeAll(ids);
                        }),
                      )),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty ? null : () => _raise(store),
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: Text('Open ${_type.label.toLowerCase()} demand · ${_selected.length} items'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
      ),
    );
  }

  List<RationMonth> _monthChoices() {
    final now = RationMonth.of(DateTime.now());
    return [now.previous, now, now.next];
  }

  Widget _fieldRow({required IconData icon, required String label, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(width: 16),
        Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
      ],
    );
  }

  void _raise(AppStore store) {
    final cycle = store.openNewCycle(
      designation: _zone,
      closeOthers: false,
      type: _type,
      days: _days,
      month: _month,
      itemIds: Set<String>.of(_selected),
      start: _startDate,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${cycle.title} opened')));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LinkDetailScreen(cycleId: cycle.id)),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final DemandType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fresh = type == DemandType.fresh;
    final color = fresh ? AppColors.success : AppColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? color : scheme.outline, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(fresh ? Icons.eco_rounded : Icons.grain_rounded, color: color),
                const Spacer(),
                if (selected) Icon(Icons.check_circle_rounded, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text('${type.label} ration', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(type.blurb, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final Category category;
  final List<Item> items;
  final Set<String> selected;
  final void Function(String id, bool on) onToggleItem;
  final void Function(bool on) onToggleAll;
  const _CategoryPicker({
    required this.category,
    required this.items,
    required this.selected,
    required this.onToggleItem,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final chosen = items.where((i) => selected.contains(i.id)).length;
    final allOn = chosen == items.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(category.icon, size: 18, color: category.color),
                const SizedBox(width: 8),
                Text(category.name, style: t.titleSmall),
                const SizedBox(width: 8),
                Pill('$chosen/${items.length}', color: category.color),
                const Spacer(),
                TextButton(
                  onPressed: () => onToggleAll(!allOn),
                  child: Text(allOn ? 'Clear all' : 'All'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final i in items)
                  FilterChip(
                    selected: selected.contains(i.id),
                    onSelected: (on) => onToggleItem(i.id, on),
                    avatar: Text(i.emoji, style: const TextStyle(fontSize: 15)),
                    label: Text(i.name, style: TextStyle(color: selected.contains(i.id) ? scheme.onPrimaryContainer : null)),
                    showCheckmark: false,
                    selectedColor: scheme.primaryContainer,
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
