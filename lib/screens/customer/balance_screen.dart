import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/customer_orders.dart';
import '../../utils/tour_keys.dart';
import '../../widgets/ui_kit.dart';
import 'order_detail_screen.dart';

enum _FilterMode { currentWeek, previousWeek, allHistory }
enum _CategoryScope { week, total }

/// The customer's entitlement balance. Three clear numbers, one honest bar,
/// and two plain fields (Month, Week) when looking at anything other than
/// right now — no chip rows, no charts, no projected numbers.
class BalanceScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String designation;
  const BalanceScreen({super.key, required this.name, required this.phone, this.designation = ''});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  _FilterMode _mode = _FilterMode.currentWeek;
  _CategoryScope _catScope = _CategoryScope.week;
  RationMonth? _pickedMonth;
  CalendarWeek? _pickedWeek;

  List<Order> _activeOrders(AppStore store) => customerOrdersFor(store, widget.name, widget.phone)
      .where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.rejected)
      .toList();

  double _consumed(List<Order> orders, AppStore store, DateTime start, DateTime end, {String? category}) {
    if (end.isBefore(start)) return 0;
    var sum = 0.0;
    for (final o in orders) {
      final d = o.createdAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      for (final l in o.lines) {
        if (category != null && store.categoryOfLine(l) != category) continue;
        sum += l.qty;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final currentMonth = store.currentMonth;
    final currentWeek = calendarWeekOf(DateTime.now());
    final lastCompletedWeek = calendarWeekOf(currentWeek.start.subtract(const Duration(days: 1)));

    // Which month is on screen, and — for "previous week" — which week.
    final RationMonth month;
    CalendarWeek? week;
    switch (_mode) {
      case _FilterMode.currentWeek:
        month = currentMonth;
        week = currentWeek;
      case _FilterMode.previousWeek:
        month = _pickedMonth ?? RationMonth.of(lastCompletedWeek.start);
        week = _pickedWeek ?? lastCompletedWeek;
        if (RationMonth.of(week.start) != month) week = weeksOfMonth(month).last;
      case _FilterMode.allHistory:
        month = _pickedMonth ?? currentMonth;
        week = null;
    }

    final zone = store.zoneFor(widget.designation);
    final balances = store
        .balancesFor(name: widget.name, phone: widget.phone, zone: widget.designation, month: month)
        .where((b) => b.total > 0)
        .toList();

    if (balances.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No balance yet',
        subtitle: 'Your entitlement appears here once the unit sets it up.',
      );
    }

    final activeOrders = _activeOrders(store);

    double weekMaxAllowed(String category, CalendarWeek w) {
      final b = balances.firstWhere((x) => x.category == category);
      final before = _consumed(activeOrders, store, month.firstDay, w.start.subtract(const Duration(days: 1)), category: category);
      final head = b.total - before;
      return head < 0 ? 0 : head;
    }

    double weekRequested(String category, CalendarWeek w) => _consumed(activeOrders, store, w.start, w.end, category: category);

    double totalWeekRemaining(CalendarWeek w) {
      var s = 0.0;
      for (final b in balances) {
        final left = weekMaxAllowed(b.category, w) - weekRequested(b.category, w);
        s += left < 0 ? 0 : left;
      }
      return s;
    }

    double totalWeekMax(CalendarWeek w) => balances.fold<double>(0, (s, b) => s + weekMaxAllowed(b.category, w));

    final monthEntitlement = balances.fold<double>(0, (s, b) => s + b.allowance);
    final monthUsed = balances.fold<double>(0, (s, b) => s + b.consumed);
    final monthRemaining = balances.fold<double>(0, (s, b) => s + b.remaining);
    final monthTotal = balances.fold<double>(0, (s, b) => s + b.total);
    final carried = balances.fold<double>(0, (s, b) => s + b.carriedIn);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(month.label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),

              KeyedSubtree(
                key: TourKeys.balanceModeSwitch,
                child: _ModeSwitch(mode: _mode, onChange: (m) => setState(() {
                  _mode = m;
                  _pickedMonth = null;
                  _pickedWeek = null;
                })),
              ),

              if (_mode == _FilterMode.previousWeek) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _PickerField(
                      label: 'Month',
                      value: month.label,
                      onTap: () async {
                        final picked = await _pickMonth(context, current: currentMonth, selected: month);
                        if (picked != null) setState(() { _pickedMonth = picked; _pickedWeek = null; });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      label: 'Week',
                      value: 'Week ${week!.number}',
                      onTap: () async {
                        final picked = await _pickWeek(context, month: month, selected: week!, currentWeekStart: currentWeek.start);
                        if (picked != null) setState(() => _pickedWeek = picked);
                      },
                    ),
                  ),
                ]),
              ],
              if (_mode == _FilterMode.allHistory) ...[
                const SizedBox(height: 12),
                _PickerField(
                  label: 'Month',
                  value: month.label,
                  onTap: () async {
                    final picked = await _pickMonth(context, current: currentMonth, selected: month);
                    if (picked != null) setState(() => _pickedMonth = picked);
                  },
                ),
              ],
              const SizedBox(height: 18),

              // ---- Three numbers, one bar. Nothing projected. ----
              KeyedSubtree(
                key: TourKeys.balanceSummary,
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _stat(context, 'Entitlement', fmtNum(monthEntitlement)),
                        _stat(context, 'Used', fmtNum(monthUsed)),
                        _stat(context, 'Remaining', fmtNum(monthRemaining), emphasize: true),
                      ]),
                      const SizedBox(height: 12),
                      UsageBar(used01: monthTotal <= 0 ? 0 : ((monthTotal - monthRemaining) / monthTotal).clamp(0.0, 1.0), height: 10),
                      if (carried > 0) ...[
                        const SizedBox(height: 10),
                        Pill('+${fmtNum(carried)} carried from ${month.previous.shortLabel}', color: AppColors.accent, icon: Icons.move_up_rounded),
                      ],
                    ],
                  ),
                ),
              ),

              if (_mode != _FilterMode.allHistory) ...[
                const SizedBox(height: 20),
                Text('This week vs last week', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                _WeekCompare(
                  store: store,
                  week: week!,
                  isCurrent: week.start == currentWeek.start,
                  weekRemaining: totalWeekRemaining(week),
                  weekMax: totalWeekMax(week),
                  previousWeekRemaining: totalWeekRemaining(calendarWeekOf(week.start.subtract(const Duration(days: 1)))),
                  activeOrders: activeOrders,
                ),
              ] else ...[
                const SizedBox(height: 20),
                Text('Every week in ${month.shortLabel}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                for (final w in weeksOfMonth(month))
                  _WeekSummaryRow(
                    week: w,
                    isCurrent: w.start == currentWeek.start,
                    remaining: totalWeekRemaining(w),
                    total: totalWeekMax(w),
                  ),
              ],

              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: Text('By category', style: Theme.of(context).textTheme.titleMedium)),
                Pill(zone.name, color: AppColors.brand, icon: Icons.shield_moon_outlined),
              ]),
              const SizedBox(height: 10),
              KeyedSubtree(
                key: TourKeys.balanceCategoryToggle,
                child: _CategoryScopeToggle(scope: _catScope, onChange: (s) => setState(() => _catScope = s)),
              ),
              const SizedBox(height: 10),
              ...balances.map((b) => _CategoryRow(
                    balance: b,
                    scope: _catScope,
                    weekRemaining: _catScope == _CategoryScope.week && week != null ? (weekMaxAllowed(b.category, week) - weekRequested(b.category, week)).clamp(0, double.infinity) : 0,
                    weekTotal: _catScope == _CategoryScope.week && week != null ? weekMaxAllowed(b.category, week) : 0,
                    onTap: () => _explain(context, store, b, month),
                  )),

              const BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, {bool emphasize = false}) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: emphasize ? scheme.primary : null)),
        ],
      ),
    );
  }

  Future<RationMonth?> _pickMonth(BuildContext context, {required RationMonth current, required RationMonth selected}) {
    final months = <RationMonth>[current, for (var m = current.previous, i = 0; i < 8; m = m.previous, i++) m];
    return _pickFromSheet<RationMonth>(
      context,
      title: 'Choose a month',
      options: months,
      labelOf: (m) => m == current ? '${m.label} (current)' : m.label,
      isSelected: (m) => m == selected,
    );
  }

  Future<CalendarWeek?> _pickWeek(BuildContext context, {required RationMonth month, required CalendarWeek selected, required DateTime currentWeekStart}) {
    final weeks = weeksOfMonth(month);
    return _pickFromSheet<CalendarWeek>(
      context,
      title: 'Choose a week in ${month.label}',
      options: weeks,
      labelOf: (w) {
        final range = w.start.month == w.end.month
            ? 'Mon ${DateFormat('d').format(w.start)} – Sun ${DateFormat('d MMM').format(w.end)}'
            : 'Mon ${DateFormat('d MMM').format(w.start)} – Sun ${DateFormat('d MMM').format(w.end)}';
        final tag = w.start == currentWeekStart ? ' · current' : '';
        return 'Week ${w.number} · $range$tag';
      },
      isSelected: (w) => w.start == selected.start,
    );
  }

  void _explain(BuildContext context, AppStore store, CategoryBalance b, RationMonth month) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExplainSheet(store: store, balance: b, month: month, name: widget.name, phone: widget.phone, designation: widget.designation),
    );
  }
}

/// A clean, theme-aware picker sheet — a plain list, checkmark on the
/// selected row. No colour is hardcoded, so it reads correctly in dark mode.
Future<T?> _pickFromSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  required bool Function(T) isSelected,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      title: Text(labelOf(o), style: TextStyle(fontWeight: isSelected(o) ? FontWeight.w700 : FontWeight.w500)),
                      trailing: isSelected(o) ? Icon(Icons.check_circle_rounded, color: scheme.primary) : null,
                      selected: isSelected(o),
                      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      onTap: () => Navigator.pop(ctx, o),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Simple three-way switch — This week / Previous week / All history.
class _ModeSwitch extends StatelessWidget {
  final _FilterMode mode;
  final ValueChanged<_FilterMode> onChange;
  const _ModeSwitch({required this.mode, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_FilterMode>(
      segments: const [
        ButtonSegment(value: _FilterMode.currentWeek, label: Text('This week')),
        ButtonSegment(value: _FilterMode.previousWeek, label: Text('Previous week')),
        ButtonSegment(value: _FilterMode.allHistory, label: Text('All history')),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChange(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

/// A bordered field that opens a picker sheet — label on top, value below,
/// a chevron to say "tap me". Fully theme-driven; no hardcoded colours.
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: scheme.outline)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: t.bodySmall),
                    Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// This week's remaining next to last week's, plus what was actually
/// demanded — a direct, side-by-side comparison.
class _WeekCompare extends StatelessWidget {
  final AppStore store;
  final CalendarWeek week;
  final bool isCurrent;
  final double weekRemaining;
  final double weekMax;
  final double previousWeekRemaining;
  final List<Order> activeOrders;
  const _WeekCompare({
    required this.store,
    required this.week,
    required this.isCurrent,
    required this.weekRemaining,
    required this.weekMax,
    required this.previousWeekRemaining,
    required this.activeOrders,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final range = week.start.month == week.end.month
        ? 'Mon ${DateFormat('d').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}'
        : 'Mon ${DateFormat('d MMM').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}';
    final weekOrders = activeOrders.where((o) {
      final d = o.createdAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(week.start) && !day.isAfter(week.end);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Week ${week.number}${isCurrent ? ' · current' : ''} · $range', style: t.bodySmall),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isCurrent ? 'This week' : 'Selected week', style: t.bodySmall),
                  Text(fmtNum(weekRemaining), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: usageColor(weekMax <= 0 ? 0 : 1 - weekRemaining / weekMax))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last week', style: t.bodySmall),
                  Text(fmtNum(previousWeekRemaining), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Demands this week', style: t.titleSmall),
        const SizedBox(height: 8),
        if (weekOrders.isEmpty)
          Text('No demand placed', style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
        else
          for (final o in weekOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                child: Row(
                  children: [
                    Icon(orderStatusIcon(o.status), size: 18, color: orderStatusColor(o.status)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.displayId, style: t.titleSmall),
                          Text(DateFormat('EEE, d MMM · h:mm a').format(o.createdAt.toLocal()), style: t.bodySmall),
                        ],
                      ),
                    ),
                    Pill(orderStatusLabel(o.status), color: orderStatusColor(o.status)),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// A read-only row for "All history" — every week of the picked month,
/// one line each. Fully theme-driven (fixes the dark-mode contrast bug).
class _WeekSummaryRow extends StatelessWidget {
  final CalendarWeek week;
  final bool isCurrent;
  final double remaining;
  final double total;
  const _WeekSummaryRow({required this.week, required this.isCurrent, required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final range = week.start.month == week.end.month
        ? 'Mon ${DateFormat('d').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}'
        : 'Mon ${DateFormat('d MMM').format(week.start)} – Sun ${DateFormat('d MMM').format(week.end)}';
    final used01 = total <= 0 ? 0.0 : ((total - remaining) / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isCurrent ? scheme.primary : scheme.outline),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('W${week.number}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  if (isCurrent) Text('Now', style: t.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 10)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(range, style: t.bodySmall),
                  const SizedBox(height: 5),
                  UsageBar(used01: used01, height: 5),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(fmtNum(remaining), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: usageColor(used01))),
          ],
        ),
      ),
    );
  }
}

class _CategoryScopeToggle extends StatelessWidget {
  final _CategoryScope scope;
  final ValueChanged<_CategoryScope> onChange;
  const _CategoryScopeToggle({required this.scope, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_CategoryScope>(
      segments: const [
        ButtonSegment(value: _CategoryScope.week, label: Text('This week')),
        ButtonSegment(value: _CategoryScope.total, label: Text('Total')),
      ],
      selected: {scope},
      onSelectionChanged: (s) => onChange(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

/// One category, one bar, one figure — scoped to whichever toggle is picked.
class _CategoryRow extends StatelessWidget {
  final CategoryBalance balance;
  final _CategoryScope scope;
  final double weekRemaining;
  final double weekTotal;
  final VoidCallback onTap;
  const _CategoryRow({required this.balance, required this.scope, required this.weekRemaining, required this.weekTotal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cat = categoryOf(balance.category);
    final emoji = rikCategoryByName(balance.category)?.emoji ?? '📦';
    final remaining = scope == _CategoryScope.week ? weekRemaining : balance.remaining;
    final total = scope == _CategoryScope.week ? weekTotal : balance.total;
    final used01 = total <= 0 ? 0.0 : ((total - remaining) / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            EmojiTile(emoji, color: cat.color, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(balance.category, style: t.titleSmall),
                  const SizedBox(height: 6),
                  UsageBar(used01: used01, height: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${fmtNum(remaining)} ${balance.unit}',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: usageColor(used01)),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// "How this balance came" — the plain math, line by line.
class _ExplainSheet extends StatelessWidget {
  final AppStore store;
  final CategoryBalance balance;
  final RationMonth month;
  final String name;
  final String phone;
  final String designation;
  const _ExplainSheet({required this.store, required this.balance, required this.month, required this.name, required this.phone, required this.designation});

  List<(Order, double)> _deductions() {
    final out = <(Order, double)>[];
    for (final o in customerOrdersFor(store, name, phone)) {
      if (o.status == OrderStatus.cancelled || o.status == OrderStatus.rejected) continue;
      if (store.monthOfOrder(o) != month) continue;
      var qty = 0.0;
      for (final l in o.lines) {
        if (store.categoryOfLine(l) == balance.category) qty += l.qty;
      }
      if (qty > 0) out.add((o, qty));
    }
    out.sort((a, b) => a.$1.createdAt.compareTo(b.$1.createdAt));
    return out;
  }

  String _demandTitle(Order o) => store.cycles.where((c) => c.id == o.cycleId).firstOrNull?.title ?? 'Order ${o.displayId}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rate = store.zoneFor(designation).perDayFor(balance.category);
    final deductions = _deductions();
    final unit = balance.unit;
    final emoji = rikCategoryByName(balance.category)?.emoji ?? '📦';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text('${balance.category} · ${month.label}', style: t.titleLarge)),
            ]),
            const SizedBox(height: 4),
            Text('How this balance came', style: t.bodySmall),
            const SizedBox(height: 16),
            _line(context, icon: Icons.assignment_outlined, label: 'Monthly entitlement', detail: '${fmtNum(rate)} $unit/day × ${month.days} days', value: '+${fmtNum(balance.allowance)}', color: AppColors.brand),
            if (balance.carriedIn > 0)
              _line(context, icon: Icons.move_up_rounded, label: 'Carried from ${month.previous.shortLabel}', detail: 'Left over last month, added on', value: '+${fmtNum(balance.carriedIn)}', color: AppColors.accent),
            if (deductions.isEmpty)
              _line(context, icon: Icons.shopping_basket_outlined, label: 'Nothing taken yet', detail: 'No demand placed this month', value: '−0', color: Theme.of(context).colorScheme.onSurfaceVariant)
            else
              for (final (o, qty) in deductions)
                _line(
                  context,
                  icon: Icons.shopping_basket_outlined,
                  label: _demandTitle(o),
                  detail: 'Week ${calendarWeekOf(o.createdAt.toLocal()).number} · ${DateFormat('d MMM, h:mm a').format(o.createdAt.toLocal())}',
                  value: '−${fmtNum(qty)}',
                  color: AppColors.danger,
                ),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text('Left with you', style: t.titleMedium)),
              Text('${fmtNum(balance.remaining)} $unit', style: t.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text('Whatever is left at month end is added to next month.', style: t.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, {required IconData icon, required String label, required String detail, required String value, required Color color}) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(detail, style: t.bodySmall),
              ],
            ),
          ),
          Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
