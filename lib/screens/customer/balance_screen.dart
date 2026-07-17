import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/customer_orders.dart';
import '../../widgets/ui_kit.dart';
import 'order_detail_screen.dart';

enum _FilterMode { currentWeek, previousWeek, allHistory }
enum _CategoryScope { week, total }

/// The customer's entitlement balance — kept to exactly what's asked at any
/// moment: pick a week from a plain list, see its limit bar and what's left,
/// compare against last week, and drill into a category only when wanted.
/// No charts, no card walls, no projected/future numbers — only what has
/// actually happened.
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
  CalendarWeek? _selectedWeek;

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

    // Which month's weeks are on screen, and whether the picker shows.
    final RationMonth month;
    final bool showMonthPicker;
    switch (_mode) {
      case _FilterMode.currentWeek:
        month = currentMonth;
        showMonthPicker = false;
      case _FilterMode.previousWeek:
      case _FilterMode.allHistory:
        month = _pickedMonth ?? currentMonth.previous;
        showMonthPicker = true;
    }

    final weeks = weeksOfMonth(month);
    final selected = _mode == _FilterMode.currentWeek
        ? currentWeek
        : (_selectedWeek != null && weeksOfMonth(month).any((w) => w.start == _selectedWeek!.start) ? _selectedWeek! : weeks.last);

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

              _FilterBar(
                mode: _mode,
                onMode: (m) => setState(() {
                  _mode = m;
                  _selectedWeek = null;
                }),
              ),
              if (showMonthPicker) ...[
                const SizedBox(height: 10),
                _MonthPicker(current: currentMonth, selected: month, onSelect: (m) => setState(() {
                  _pickedMonth = m;
                  _selectedWeek = null;
                })),
              ],
              const SizedBox(height: 16),

              // ---- Overall limit bar: what's left right now, nothing projected ----
              _LimitBar(
                title: month == currentMonth ? 'Remaining this month' : 'Remaining in ${month.shortLabel}',
                remaining: monthRemaining,
                total: monthTotal,
              ),
              if (carried > 0) ...[
                const SizedBox(height: 8),
                Pill('+${fmtNum(carried)} carried from ${month.previous.shortLabel}', color: AppColors.accent, icon: Icons.move_up_rounded),
              ],
              const SizedBox(height: 20),

              Text(
                _mode == _FilterMode.allHistory ? 'Every week this month' : 'Pick a week',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_mode == _FilterMode.allHistory)
                for (final w in weeks)
                  _WeekListRow(
                    week: w,
                    isCurrent: w.start == currentWeek.start,
                    selected: false,
                    remaining: totalWeekRemaining(w),
                    total: totalWeekMax(w),
                    onTap: () {},
                  )
              else
                for (final w in weeks)
                  _WeekListRow(
                    week: w,
                    isCurrent: w.start == currentWeek.start,
                    selected: w.start == selected.start,
                    remaining: totalWeekRemaining(w),
                    total: totalWeekMax(w),
                    onTap: _mode == _FilterMode.currentWeek ? null : () => setState(() => _selectedWeek = w),
                  ),

              if (_mode != _FilterMode.allHistory) ...[
                const SizedBox(height: 22),
                _WeekDetail(
                  store: store,
                  week: selected,
                  previousWeek: calendarWeekOf(selected.start.subtract(const Duration(days: 1))),
                  balances: balances,
                  weekRemaining: totalWeekRemaining(selected),
                  weekMax: totalWeekMax(selected),
                  previousWeekRemaining: totalWeekRemaining(calendarWeekOf(selected.start.subtract(const Duration(days: 1)))),
                  activeOrders: activeOrders,
                ),
              ],

              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: Text('By category', style: Theme.of(context).textTheme.titleMedium)),
                Pill(zone.name, color: AppColors.brand, icon: Icons.shield_moon_outlined),
              ]),
              const SizedBox(height: 10),
              _CategoryScopeToggle(scope: _catScope, onChange: (s) => setState(() => _catScope = s)),
              const SizedBox(height: 10),
              ...balances.map((b) => _CategoryRow(
                    balance: b,
                    scope: _catScope,
                    weekRemaining: _catScope == _CategoryScope.week ? (weekMaxAllowed(b.category, selected) - weekRequested(b.category, selected)).clamp(0, double.infinity) : 0,
                    weekTotal: _catScope == _CategoryScope.week ? weekMaxAllowed(b.category, selected) : 0,
                    onTap: () => _explain(context, store, b, month),
                  )),

              const BrandFooter(),
            ],
          ),
        ),
      ),
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

class _FilterBar extends StatelessWidget {
  final _FilterMode mode;
  final ValueChanged<_FilterMode> onMode;
  const _FilterBar({required this.mode, required this.onMode});

  static const _labels = {
    _FilterMode.currentWeek: 'This week',
    _FilterMode.previousWeek: 'Previous week',
    _FilterMode.allHistory: 'All history',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in _FilterMode.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: mode == m,
              onSelected: (_) => onMode(m),
              label: Text(_labels[m]!),
              selectedColor: AppColors.brandWash,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, color: mode == m ? AppColors.brandDark : null),
              shape: const StadiumBorder(),
              side: BorderSide(color: mode == m ? AppColors.brand : Theme.of(context).colorScheme.outline),
            ),
          ),
      ],
    );
  }
}

class _MonthPicker extends StatelessWidget {
  final RationMonth current;
  final RationMonth selected;
  final ValueChanged<RationMonth> onSelect;
  const _MonthPicker({required this.current, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final months = <RationMonth>[current, for (var m = current.previous, i = 0; i < 5; m = m.previous, i++) m];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final mo in months)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: mo == selected,
                onSelected: (_) => onSelect(mo),
                label: Text(mo.shortLabel),
                selectedColor: AppColors.brandWash,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: mo == selected ? AppColors.brandDark : null),
                shape: const StadiumBorder(),
                side: BorderSide(color: mo == selected ? AppColors.brand : Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

/// One big, honest "how much is left" bar — a fuel gauge, not a dashboard.
class _LimitBar extends StatelessWidget {
  final String title;
  final double remaining;
  final double total;
  const _LimitBar({required this.title, required this.remaining, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final used01 = total <= 0 ? 0.0 : ((total - remaining) / total).clamp(0.0, 1.0);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.bodyMedium),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtNum(remaining), style: t.displaySmall?.copyWith(color: AppColors.brandDark, fontSize: 36, height: 1)),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('of ${fmtNum(total)}', style: t.bodyMedium)),
            ],
          ),
          const SizedBox(height: 10),
          UsageBar(used01: used01, height: 10),
        ],
      ),
    );
  }
}

/// A plain list row — a week, its date range, and a thin bar showing what's
/// left of it. This is "the list" the customer picks from.
class _WeekListRow extends StatelessWidget {
  final CalendarWeek week;
  final bool isCurrent;
  final bool selected;
  final double remaining;
  final double total;
  final VoidCallback? onTap;
  const _WeekListRow({required this.week, required this.isCurrent, required this.selected, required this.remaining, required this.total, this.onTap});

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
      child: Material(
        color: selected ? AppColors.brandWash : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: selected ? AppColors.brand : scheme.outline),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('W${week.number}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: selected ? AppColors.brandDark : null)),
                      if (isCurrent) Text('Now', style: t.bodySmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 10)),
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
        ),
      ),
    );
  }
}

/// The selected week's numbers, plus last week for a quick comparison, plus
/// exactly what was ordered that week — nothing projected forward.
class _WeekDetail extends StatelessWidget {
  final AppStore store;
  final CalendarWeek week;
  final CalendarWeek previousWeek;
  final List<CategoryBalance> balances;
  final double weekRemaining;
  final double weekMax;
  final double previousWeekRemaining;
  final List<Order> activeOrders;
  const _WeekDetail({
    required this.store,
    required this.week,
    required this.previousWeek,
    required this.balances,
    required this.weekRemaining,
    required this.weekMax,
    required this.previousWeekRemaining,
    required this.activeOrders,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final weekOrders = activeOrders.where((o) {
      final d = o.createdAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(week.start) && !day.isAfter(week.end);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This week', style: t.bodySmall),
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
              Text('${fmtNum(balance.remaining)} $unit', style: t.titleLarge?.copyWith(color: AppColors.brandDark, fontWeight: FontWeight.w700)),
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
