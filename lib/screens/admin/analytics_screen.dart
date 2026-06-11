import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

const _soldColor = AppColors.accent; // orange = sold / used
const _stockColor = AppColors.brand; // green = in stock

enum _View { category, item, unit }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _View _view = _View.category;

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
              const SectionHeader(
                title: 'Analytics',
                subtitle: 'See what sold and what is still in stock',
                info: '"Sold this cycle" means opening stock minus what is left now. '
                    'Current stock is what is available right now.',
              ),
              const SizedBox(height: 16),
              _StatRow(store: store),
              const SizedBox(height: 16),
              _ChartCard(store: store, view: _view, onView: (v) => setState(() => _view = v)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final AppStore store;
  const _StatRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final consumed = store.totalConsumed;
    final stock = store.totalInStock;
    final total = consumed + stock;
    final sellThrough = total <= 0 ? 0 : (consumed / total * 100).round();
    final tiles = [
      StatTile(icon: Icons.south_rounded, label: 'Sold this cycle', value: fmtNum(consumed), color: _soldColor, info: 'Opening stock minus what is left now, totalled across every item.'),
      StatTile(icon: Icons.inventory_2_rounded, label: 'In stock now', value: fmtNum(stock), color: _stockColor, info: 'Total units currently available across all items.'),
      StatTile(icon: Icons.percent_rounded, label: 'Sell-through', value: '$sellThrough%', color: AppColors.cPulses, info: 'Share of stock already sold. Sold divided by (sold plus in stock).'),
      StatTile(icon: Icons.receipt_long_rounded, label: 'Orders this week', value: '${store.ordersThisCycle.length}', color: AppColors.cDairy, info: 'Orders placed during the current weekly cycle.'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 720 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 14) / cols;
      return Wrap(spacing: 14, runSpacing: 14, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }
}

class _ChartCard extends StatelessWidget {
  final AppStore store;
  final _View view;
  final ValueChanged<_View> onView;
  const _ChartCard({required this.store, required this.view, required this.onView});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final filter = SegmentedButton<_View>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: _View.category, icon: Icon(Icons.category_rounded, size: 16), label: Text('Category')),
        ButtonSegment(value: _View.item, icon: Icon(Icons.inventory_2_rounded, size: 16), label: Text('Item')),
        ButtonSegment(value: _View.unit, icon: Icon(Icons.groups_rounded, size: 16), label: Text('Unit')),
      ],
      selected: {view},
      onSelectionChanged: (s) => onView(s.first),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final title = Row(
              children: [
                Flexible(child: Text(_title(view), style: t.titleLarge, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                InfoTip(_tip(view)),
              ],
            );
            if (c.maxWidth > 560) {
              return Row(children: [Expanded(child: title), filter]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: filter)],
            );
          }),
          const SizedBox(height: 6),
          Text(_subtitle(view), style: t.bodyMedium),
          const SizedBox(height: 14),
          if (view == _View.unit) const _Legend(single: true) else const _Legend(),
          const SizedBox(height: 18),
          _chart(context),
        ],
      ),
    );
  }

  String _title(_View v) => switch (v) {
        _View.category => 'Sold vs stock, by category',
        _View.item => 'Sold vs stock, by item',
        _View.unit => 'Consumption by unit',
      };

  String _subtitle(_View v) => switch (v) {
        _View.category => 'Each category: how much was sold against what is left',
        _View.item => 'Every item side by side (scroll sideways to see all)',
        _View.unit => 'Total units each customer/unit has ordered',
      };

  String _tip(_View v) => switch (v) {
        _View.category => 'Orange is units sold this cycle, green is units in stock now.',
        _View.item => 'Orange is units sold this cycle, green is units in stock now, per item.',
        _View.unit => 'Adds up every item quantity ordered by each unit this period.',
      };

  Widget _chart(BuildContext context) {
    switch (view) {
      case _View.category:
        final cats = store.activeCategories;
        return _groupedChart(
          context,
          labels: cats,
          sold: [for (final c in cats) store.consumedInCategory(c)],
          stock: [for (final c in cats) store.stockInCategory(c)],
        );
      case _View.item:
        final items = [...store.items]..sort((a, b) => store.consumedOf(b).compareTo(store.consumedOf(a)));
        return _groupedChart(
          context,
          labels: [for (final i in items) i.name],
          sold: [for (final i in items) store.consumedOf(i)],
          stock: [for (final i in items) i.currentQty],
          scroll: true,
        );
      case _View.unit:
        final data = store.consumptionByUnit();
        final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        if (entries.isEmpty) {
          return const SizedBox(
            height: 320,
            child: EmptyState(icon: Icons.bar_chart_rounded, title: 'No orders yet', subtitle: 'Consumption per unit appears once customers order.'),
          );
        }
        return _singleChart(
          context,
          labels: [for (final e in entries) e.key],
          values: [for (final e in entries) e.value],
          color: AppColors.cDairy,
        );
    }
  }
}

class _Legend extends StatelessWidget {
  final bool single;
  const _Legend({this.single = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]);
    if (single) return dot(AppColors.cDairy, 'Units ordered');
    return Wrap(spacing: 18, runSpacing: 8, children: [dot(_soldColor, 'Sold this cycle'), dot(_stockColor, 'Current stock')]);
  }
}

// ---- Chart builders --------------------------------------------------------

Widget _groupedChart(
  BuildContext context, {
  required List<String> labels,
  required List<double> sold,
  required List<double> stock,
  bool scroll = false,
}) {
  double maxV = 1;
  for (final v in [...sold, ...stock]) {
    maxV = max(maxV, v);
  }
  final maxY = maxV * 1.25;

  final chart = BarChart(
    BarChartData(
      alignment: scroll ? BarChartAlignment.spaceBetween : BarChartAlignment.spaceAround,
      maxY: maxY,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
            '${labels[group.x]}\n${ri == 0 ? 'Sold' : 'Stock'}: ${fmtNum(rod.toY)}',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
      titlesData: _titles(context, labels),
      gridData: _grid(context, maxY),
      borderData: FlBorderData(show: false),
      barGroups: [
        for (var i = 0; i < labels.length; i++)
          BarChartGroupData(x: i, barsSpace: 4, barRods: [
            _rod(sold[i], _soldColor),
            _rod(stock[i], _stockColor),
          ]),
      ],
    ),
  );

  if (!scroll) return SizedBox(height: 340, child: chart);
  final width = max(MediaQuery.sizeOf(context).width - 120, labels.length * 82.0);
  return SizedBox(
    height: 340,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: width, child: chart),
    ),
  );
}

Widget _singleChart(
  BuildContext context, {
  required List<String> labels,
  required List<double> values,
  required Color color,
}) {
  double maxV = 1;
  for (final v in values) {
    maxV = max(maxV, v);
  }
  return SizedBox(
    height: 340,
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV * 1.25,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              '${labels[group.x]}\n${fmtNum(rod.toY)} units',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        titlesData: _titles(context, labels),
        gridData: _grid(context, maxV * 1.25),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < labels.length; i++)
            BarChartGroupData(x: i, barRods: [_rod(values[i], color, width: 20)]),
        ],
      ),
    ),
  );
}

BarChartRodData _rod(double y, Color color, {double width = 12}) => BarChartRodData(
      toY: y,
      color: color,
      width: width,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
    );

FlTitlesData _titles(BuildContext context, List<String> labels) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (v, m) => _axisText(context, fmtNum(v))),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 46,
          getTitlesWidget: (v, m) {
            final i = v.toInt();
            if (i < 0 || i >= labels.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(width: 70, child: Text(_short(labels[i]), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _axisStyle(context))),
            );
          },
        ),
      ),
    );

FlGridData _grid(BuildContext context, double maxY) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY <= 0 ? null : maxY / 4,
      getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).colorScheme.outline, strokeWidth: 1),
    );

TextStyle _axisStyle(BuildContext context) =>
    TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant);

Widget _axisText(BuildContext context, String s) => Text(s, style: _axisStyle(context), overflow: TextOverflow.ellipsis);

String _short(String s) => s.length <= 12 ? s : '${s.substring(0, 11)}…';
