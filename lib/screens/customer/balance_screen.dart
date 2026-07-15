import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/customer_orders.dart';
import '../../widgets/ui_kit.dart';

/// The customer's entitlement balance — its own tab.
///
/// One month at a time: a headline "left with you" figure, then a row per
/// category. Past months are a tap away, and tapping any category opens a
/// sheet that shows exactly how its number was calculated (entitlement +
/// carried − each order = left).
class BalanceScreen extends StatefulWidget {
  final String name;
  final String phone;
  final String designation;
  const BalanceScreen({super.key, required this.name, required this.phone, this.designation = ''});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  RationMonth? _selected;

  /// Months worth showing: the current one plus any month the customer ordered
  /// in — newest first, capped at six.
  List<RationMonth> _months(AppStore store) {
    final now = store.currentMonth;
    final set = <RationMonth>{now, now.previous};
    for (final o in customerOrdersFor(store, widget.name, widget.phone)) {
      set.add(store.monthOfOrder(o));
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = Theme.of(context).textTheme;
    final months = _months(store);
    final month = months.contains(_selected) ? _selected! : months.first;

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

    final remaining = balances.fold<double>(0, (s, b) => s + b.remaining);
    final total = balances.fold<double>(0, (s, b) => s + b.total);
    final carried = balances.fold<double>(0, (s, b) => s + b.carriedIn);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance', style: t.headlineSmall),
              const SizedBox(height: 2),
              Text('What is still left with you', style: t.bodyMedium),
              const SizedBox(height: 14),

              // Month selector — current and past months.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in months)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: m == month,
                          onSelected: (_) => setState(() => _selected = m),
                          label: Text(m == store.currentMonth ? '${m.shortLabel} · now' : m.shortLabel),
                          selectedColor: AppColors.brandWash,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: m == month ? AppColors.brandDark : null,
                          ),
                          shape: const StadiumBorder(),
                          side: BorderSide(color: m == month ? AppColors.brand : Theme.of(context).colorScheme.outline),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _HeadlineCard(month: month, remaining: remaining, total: total, carried: carried),
              const SizedBox(height: 18),

              Text('By category', style: t.titleMedium),
              const SizedBox(height: 4),
              Text('Tap a category to see how its balance came', style: t.bodySmall),
              const SizedBox(height: 10),
              ...balances.map((b) => _CategoryRow(
                    balance: b,
                    onTap: () => _explain(context, store, b, month),
                  )),
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

/// The headline figure — big and unmissable.
class _HeadlineCard extends StatelessWidget {
  final RationMonth month;
  final double remaining;
  final double total;
  final double carried;
  const _HeadlineCard({required this.month, required this.remaining, required this.total, required this.carried});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ratio = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Left with you · ${month.label}', style: t.bodyMedium),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtNum(remaining), style: t.displaySmall?.copyWith(color: AppColors.brandDark, fontSize: 40, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('of ${fmtNum(total)} units', style: t.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: AppColors.brand,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          if (carried > 0) ...[
            const SizedBox(height: 10),
            Pill('${fmtNum(carried)} carried from ${month.previous.shortLabel}', color: AppColors.accent, icon: Icons.move_up_rounded),
          ],
        ],
      ),
    );
  }
}

/// One category: emoji, name, a thin bar, and the remaining figure — big.
class _CategoryRow extends StatelessWidget {
  final CategoryBalance balance;
  final VoidCallback onTap;
  const _CategoryRow({required this.balance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cat = categoryOf(balance.category);
    final emoji = rikCategoryByName(balance.category)?.emoji ?? '📦';
    final ratio = balance.total <= 0 ? 0.0 : (balance.remaining / balance.total).clamp(0.0, 1.0);
    final empty = balance.isExhausted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            EmojiTile(emoji, color: cat.color, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(balance.category, style: t.titleSmall),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      color: empty ? AppColors.warning : cat.color,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtNum(balance.remaining),
                  style: t.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: empty ? AppColors.warning : null,
                  ),
                ),
                Text('of ${fmtNum(balance.total)} ${balance.unit}', style: t.bodySmall),
              ],
            ),
            const SizedBox(width: 4),
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
  const _ExplainSheet({
    required this.store,
    required this.balance,
    required this.month,
    required this.name,
    required this.phone,
    required this.designation,
  });

  /// The orders in this month that took from this category: (order, qty).
  List<(Order, double)> _deductions() {
    final out = <(Order, double)>[];
    for (final o in customerOrdersFor(store, name, phone)) {
      if (o.status == OrderStatus.cancelled) continue;
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

  String _demandTitle(Order o) =>
      store.cycles.where((c) => c.id == o.cycleId).firstOrNull?.title ?? 'Order ${o.id}';

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

            _line(
              context,
              icon: Icons.assignment_outlined,
              label: 'Monthly entitlement',
              detail: '${fmtNum(rate)} $unit/day × ${month.days} days',
              value: '+${fmtNum(balance.allowance)}',
              color: AppColors.brand,
            ),
            if (balance.carriedIn > 0)
              _line(
                context,
                icon: Icons.move_up_rounded,
                label: 'Carried from ${month.previous.shortLabel}',
                detail: 'Left over last month, added on',
                value: '+${fmtNum(balance.carriedIn)}',
                color: AppColors.accent,
              ),
            if (deductions.isEmpty)
              _line(
                context,
                icon: Icons.shopping_basket_outlined,
                label: 'Nothing taken yet',
                detail: 'No demand placed this month',
                value: '−0',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            else
              for (final (o, qty) in deductions)
                _line(
                  context,
                  icon: Icons.shopping_basket_outlined,
                  label: _demandTitle(o),
                  detail: DateFormat('d MMM, h:mm a').format(o.createdAt.toLocal()),
                  value: '−${fmtNum(qty)}',
                  color: AppColors.danger,
                ),

            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text('Left with you', style: t.titleMedium)),
                Text(
                  '${fmtNum(balance.remaining)} $unit',
                  style: t.titleLarge?.copyWith(color: AppColors.brandDark, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Whatever is left at month end is added to next month.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String detail,
    required String value,
    required Color color,
  }) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
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
