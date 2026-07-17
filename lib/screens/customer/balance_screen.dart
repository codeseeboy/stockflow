import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/customer_orders.dart';
import '../../widgets/ui_kit.dart';
import 'order_detail_screen.dart';

enum _FilterMode { currentWeek, previousWeek, currentMonth, previousMonths, allHistory }

/// The customer's entitlement dashboard — the most important screen in the
/// app, so it gets the deepest tracking: a full month/week picture, nine
/// summary figures, a per-category breakdown down to the week level, a trend
/// chart, and — filtered any way the customer wants — exactly which demand
/// consumed what and when.
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
  RationMonth? _pickedMonth;
  CalendarWeek? _pickedWeek;

  List<Order> _activeOrders(AppStore store) => customerOrdersFor(store, widget.name, widget.phone)
      .where((o) => o.status != OrderStatus.cancelled && o.status != OrderStatus.rejected)
      .toList();

  /// Quantity ordered (optionally in one category) between [start] and [end]
  /// inclusive — the one building block every figure on this page is made of.
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

  List<Order> _ordersInRange(List<Order> orders, DateTime start, DateTime end) => orders.where((o) {
        final d = o.createdAt.toLocal();
        final day = DateTime(d.year, d.month, d.day);
        return !day.isBefore(start) && !day.isAfter(end);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    if (_mode == _FilterMode.allHistory) {
      return _HistoryView(store: store, name: widget.name, phone: widget.phone);
    }

    final now = DateTime.now();
    final currentMonth = store.currentMonth;
    final currentWeek = calendarWeekOf(now);

    late final RationMonth month;
    CalendarWeek? week;
    switch (_mode) {
      case _FilterMode.currentWeek:
        month = currentMonth;
        week = currentWeek;
      case _FilterMode.previousWeek:
        week = _pickedWeek ?? calendarWeekOf(currentWeek.start.subtract(const Duration(days: 1)));
        month = RationMonth.of(week.start);
      case _FilterMode.currentMonth:
        month = currentMonth;
        week = null;
      case _FilterMode.previousMonths:
        month = _pickedMonth ?? currentMonth.previous;
        week = null;
      case _FilterMode.allHistory:
        month = currentMonth; // unreachable, handled above
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

    double weekRequested(String category, CalendarWeek w) =>
        _consumed(activeOrders, store, w.start, w.end, category: category);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text('Track exactly how your entitlement is used', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),

              _FilterBar(
                mode: _mode,
                onMode: (m) => setState(() => _mode = m),
              ),
              if (_mode == _FilterMode.previousWeek) ...[
                const SizedBox(height: 10),
                _WeekPicker(
                  store: store,
                  around: currentWeek,
                  selected: week!,
                  onSelect: (w) => setState(() => _pickedWeek = w),
                ),
              ],
              if (_mode == _FilterMode.previousMonths) ...[
                const SizedBox(height: 10),
                _MonthPicker(
                  current: currentMonth,
                  selected: month,
                  onSelect: (m) => setState(() => _pickedMonth = m),
                ),
              ],
              const SizedBox(height: 16),

              _SummaryGrid(
                store: store,
                zone: zone,
                month: month,
                week: week,
                balances: balances,
                activeOrders: activeOrders,
                consumedInRange: (s, e, {cat}) => _consumed(activeOrders, store, s, e, category: cat),
              ),
              const SizedBox(height: 22),

              Text('Weekly trend · ${month.label}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Total units demanded, week by week', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              _WeeklyTrendChart(
                month: month,
                highlight: week,
                weeklyTotal: (w) {
                  var sum = 0.0;
                  for (final b in balances) {
                    sum += weekRequested(b.category, w);
                  }
                  return sum;
                },
              ),
              const SizedBox(height: 22),

              Row(children: [
                Expanded(child: Text('By category', style: Theme.of(context).textTheme.titleMedium)),
                Pill(zone.name, color: AppColors.brand, icon: Icons.shield_moon_outlined),
              ]),
              const SizedBox(height: 4),
              Text(
                week != null ? 'Tap a category to see how it was calculated' : 'Pick a week above for the full weekly breakdown',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              ...balances.map((b) => _CategoryCard(
                    balance: b,
                    week: week,
                    weekMax: week == null ? 0 : weekMaxAllowed(b.category, week),
                    weekRequested: week == null ? 0 : weekRequested(b.category, week),
                    onTap: () => _explain(context, store, b, month),
                  )),

              if (week != null) ...[
                const SizedBox(height: 22),
                Text('Demands in Week ${week.number}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Status and submission time for each one', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                ..._weekOrderCards(context, _ordersInRange(activeOrders, week.start, week.end)),
              ],

              const BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _weekOrderCards(BuildContext context, List<Order> orders) {
    if (orders.isEmpty) {
      return [const EmptyState(icon: Icons.receipt_long_outlined, title: 'No demand placed in this week')];
    }
    return orders
        .map((o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                child: Row(
                  children: [
                    Icon(orderStatusIcon(o.status), size: 20, color: orderStatusColor(o.status)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.displayId, style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            DateFormat('EEE, d MMM · h:mm a').format(o.createdAt.toLocal()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Pill(orderStatusLabel(o.status), color: orderStatusColor(o.status)),
                  ],
                ),
              ),
            ))
        .toList();
  }

  void _explain(BuildContext context, AppStore store, CategoryBalance b, RationMonth month) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ExplainSheet(
        store: store,
        balance: b,
        month: month,
        name: widget.name,
        phone: widget.phone,
        designation: widget.designation,
      ),
    );
  }
}

/// The five ways to look at this page — a plain filter row, no nesting.
class _FilterBar extends StatelessWidget {
  final _FilterMode mode;
  final ValueChanged<_FilterMode> onMode;
  const _FilterBar({required this.mode, required this.onMode});

  static const _labels = {
    _FilterMode.currentWeek: 'This week',
    _FilterMode.previousWeek: 'Previous week',
    _FilterMode.currentMonth: 'This month',
    _FilterMode.previousMonths: 'Previous months',
    _FilterMode.allHistory: 'All history',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
      ),
    );
  }
}

class _WeekPicker extends StatelessWidget {
  final AppStore store;
  final CalendarWeek around;
  final CalendarWeek selected;
  final ValueChanged<CalendarWeek> onSelect;
  const _WeekPicker({required this.store, required this.around, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final weeks = <CalendarWeek>[];
    var w = calendarWeekOf(around.start.subtract(const Duration(days: 1)));
    for (var i = 0; i < 8; i++) {
      weeks.add(w);
      w = calendarWeekOf(w.start.subtract(const Duration(days: 1)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final wk in weeks)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: wk.start == selected.start,
                onSelected: (_) => onSelect(wk),
                label: Text('Wk ${wk.number} · ${DateFormat('d MMM').format(wk.start)}'),
                selectedColor: AppColors.brandWash,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: wk.start == selected.start ? AppColors.brandDark : null),
                shape: const StadiumBorder(),
                side: BorderSide(color: wk.start == selected.start ? AppColors.brand : Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
      ),
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
    final months = <RationMonth>[];
    var m = current.previous;
    for (var i = 0; i < 6; i++) {
      months.add(m);
      m = m.previous;
    }
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

/// The nine tracking figures, laid out as compact stat tiles.
class _SummaryGrid extends StatelessWidget {
  final AppStore store;
  final RationZone zone;
  final RationMonth month;
  final CalendarWeek? week;
  final List<CategoryBalance> balances;
  final List<Order> activeOrders;
  final double Function(DateTime start, DateTime end, {String? cat}) consumedInRange;
  const _SummaryGrid({
    required this.store,
    required this.zone,
    required this.month,
    required this.week,
    required this.balances,
    required this.activeOrders,
    required this.consumedInRange,
  });

  @override
  Widget build(BuildContext context) {
    final entitlement = balances.fold<double>(0, (s, b) => s + b.allowance);
    final used = balances.fold<double>(0, (s, b) => s + b.consumed);
    final remaining = balances.fold<double>(0, (s, b) => s + b.remaining);
    final carried = balances.fold<double>(0, (s, b) => s + b.carriedIn);
    final expectedNext = balances.fold<double>(0, (s, b) => s + zone.monthlyAllowance(b.category, month.next) + b.remaining);

    final tiles = <_StatTileData>[
      _StatTileData('Current month', month.label, Icons.calendar_month_rounded, AppColors.brand),
      week != null
          ? _StatTileData('Current week', 'Week ${week!.number}', Icons.view_week_rounded, AppColors.cDairy)
          : _StatTileData('Weeks in month', '${weeksOfMonth(month).length} weeks', Icons.view_week_rounded, AppColors.cDairy),
      _StatTileData('Monthly entitlement', fmtNum(entitlement), Icons.assignment_outlined, AppColors.brand),
      _StatTileData('Used this month', fmtNum(used), Icons.shopping_basket_outlined, usageColor(entitlement <= 0 ? 0 : used / (entitlement + carried))),
      _StatTileData('Remaining balance', fmtNum(remaining), Icons.savings_outlined, usageColor(entitlement + carried <= 0 ? 0 : 1 - (remaining / (entitlement + carried)))),
      _StatTileData('Carried from ${month.previous.shortLabel}', fmtNum(carried), Icons.move_up_rounded, AppColors.accent),
      _StatTileData('Expected ${month.next.shortLabel} balance', fmtNum(expectedNext), Icons.trending_up_rounded, AppColors.success),
      if (week != null) ...[
        _StatTileData(
          'Week ${week!.number} usage',
          fmtNum(balances.fold<double>(0, (s, b) => s + consumedInRange(week!.start, week!.end, cat: b.category))),
          Icons.today_rounded,
          AppColors.warning,
        ),
        _StatTileData(
          'Week ${week!.number} remaining',
          fmtNum(balances.fold<double>(0, (s, b) {
            final before = consumedInRange(month.firstDay, week!.start.subtract(const Duration(days: 1)), cat: b.category);
            final head = b.total - before;
            final used = consumedInRange(week!.start, week!.end, cat: b.category);
            final left = head - used;
            return s + (left < 0 ? 0 : left);
          })),
          Icons.event_available_rounded,
          AppColors.success,
        ),
      ] else
        _StatTileData('Demands placed', '${activeOrders.where((o) => store.monthOfOrder(o) == month).length}', Icons.receipt_long_outlined, AppColors.cVeg),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 640 ? 3 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in tiles) SizedBox(width: w, child: t.build(context))],
      );
    });
  }
}

class _StatTileData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTileData(this.label, this.value, this.icon, this.color);

  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(label, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// One bar per calendar week of the month — a quick visual read on which
/// weeks the customer used more or less of their entitlement.
class _WeeklyTrendChart extends StatelessWidget {
  final RationMonth month;
  final CalendarWeek? highlight;
  final double Function(CalendarWeek) weeklyTotal;
  const _WeeklyTrendChart({required this.month, required this.highlight, required this.weeklyTotal});

  @override
  Widget build(BuildContext context) {
    final weeks = weeksOfMonth(month);
    final totals = [for (final w in weeks) weeklyTotal(w)];
    final maxY = (totals.fold<double>(0, (m, v) => v > m ? v : m)) * 1.25;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY <= 0 ? 1 : maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(fmtNum(rod.toY), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text(fmtNum(v), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= weeks.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 6), child: Text('W${weeks[i].number}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)));
                  },
                ),
              ),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY <= 0 ? 1 : maxY / 4, getDrawingHorizontalLine: (v) => FlLine(color: scheme.outline.withValues(alpha: 0.4), strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < weeks.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: totals[i],
                    color: highlight != null && weeks[i].start == highlight!.start ? AppColors.brand : scheme.outline,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category, fully broken down. In week view every field asked for is
/// present; in month view it's just the three monthly figures.
class _CategoryCard extends StatelessWidget {
  final CategoryBalance balance;
  final CalendarWeek? week;
  final double weekMax;
  final double weekRequested;
  final VoidCallback onTap;
  const _CategoryCard({required this.balance, required this.week, required this.weekMax, required this.weekRequested, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cat = categoryOf(balance.category);
    final emoji = rikCategoryByName(balance.category)?.emoji ?? '📦';
    final weekLeft = week == null ? 0.0 : (weekMax - weekRequested).clamp(0.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmojiTile(emoji, color: cat.color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(balance.category, style: t.titleSmall),
                      const SizedBox(height: 5),
                      UsageBar(used01: balance.usedFraction, height: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _figure(context, 'Monthly entitlement', fmtNum(balance.allowance), balance.unit),
                _figure(context, 'Used this month', fmtNum(balance.consumed), balance.unit),
                _figure(context, 'Remaining this month', fmtNum(balance.remaining), balance.unit, color: usageColor(balance.usedFraction)),
                if (week != null) ...[
                  _figure(context, 'Current week demand', fmtNum(weekRequested), balance.unit),
                  _figure(context, 'Maximum allowed', fmtNum(weekMax), balance.unit),
                  _figure(context, 'Already requested', fmtNum(weekRequested), balance.unit),
                  _figure(context, 'Still available', fmtNum(weekLeft), balance.unit, color: usageColor(weekMax <= 0 ? 0 : weekRequested / weekMax)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _figure(BuildContext context, String label, String value, String unit, {Color? color}) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$value $unit', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
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
  const _ExplainSheet({
    required this.store,
    required this.balance,
    required this.month,
    required this.name,
    required this.phone,
    required this.designation,
  });

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

/// "All history" — every demand ever placed, newest first, each carrying its
/// month/week context. No category math here; this is the full paper trail.
class _HistoryView extends StatelessWidget {
  final AppStore store;
  final String name;
  final String phone;
  const _HistoryView({required this.store, required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    final orders = customerOrdersFor(store, name, phone);
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance', style: t.headlineSmall),
              const SizedBox(height: 2),
              Text('Track exactly how your entitlement is used', style: t.bodyMedium),
              const SizedBox(height: 14),
              _FilterBar(mode: _FilterMode.allHistory, onMode: (m) {
                if (m != _FilterMode.allHistory) Navigator.of(context).maybePop();
              }),
              const SizedBox(height: 16),
              if (orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(icon: Icons.history_rounded, title: 'No demands placed yet'),
                )
              else
                for (final o in orders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o))),
                      child: Row(
                        children: [
                          Icon(orderStatusIcon(o.status), size: 20, color: orderStatusColor(o.status)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.displayId, style: t.titleSmall),
                                Text(
                                  '${store.monthOfOrder(o).label} · Week ${calendarWeekOf(o.createdAt.toLocal()).number} · ${DateFormat('d MMM, h:mm a').format(o.createdAt.toLocal())}',
                                  style: t.bodySmall,
                                ),
                                Text('${o.itemCount} items · ${fmtNum(o.totalUnits)} units', style: t.bodySmall),
                              ],
                            ),
                          ),
                          Pill(orderStatusLabel(o.status), color: orderStatusColor(o.status)),
                        ],
                      ),
                    ),
                  ),
              const BrandFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
