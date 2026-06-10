import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

double _stepFor(String unit) => (unit == 'kg' || unit == 'litre') ? 5 : 1;

/// Weekly order form: pick items + quantities, review a summary, then confirm.
class OrderForm extends StatefulWidget {
  final String name;
  final String phone;
  const OrderForm({super.key, required this.name, required this.phone});

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final Map<String, double> _picked = {};
  String _query = '';
  String _category = 'All';

  int get _count => _picked.values.where((v) => v > 0).length;
  double get _units => _picked.values.fold(0.0, (s, v) => s + v);

  void _setQty(Item item, double qty) {
    setState(() {
      final clamped = qty.clamp(0, item.currentQty).toDouble();
      if (clamped <= 0) {
        _picked.remove(item.id);
      } else {
        _picked[item.id] = clamped;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cycle = store.orderingCycle;
    final canOrder = store.canPlaceOrders;

    _picked.removeWhere((id, qty) {
      final it = store.items.where((i) => i.id == id);
      return it.isEmpty || it.first.currentQty <= 0;
    });

    if (!canOrder) return const _NoOrderState();

    final matches = store.items.where((i) {
      final mq = _query.isEmpty || i.name.toLowerCase().contains(_query.toLowerCase());
      final mc = _category == 'All' || i.category == _category;
      return mq && mc;
    }).toList();
    final grouped = _category == 'All' && _query.isEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateBanner(cycle: cycle),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(hintText: 'Search items…', prefixIcon: Icon(Icons.search_rounded)),
                    ),
                    const SizedBox(height: 12),
                    _Categories(selected: _category, onSelect: (c) => setState(() => _category = c)),
                    const SizedBox(height: 16),
                    if (matches.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 36), child: EmptyState(icon: Icons.search_off_rounded, title: 'Nothing matches'))
                    else if (grouped)
                      ..._sections(store, matches)
                    else
                      _grid(matches),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_count > 0) _SubmitBar(count: _count, units: _units, onReview: () => _openReview(store)),
      ],
    );
  }

  List<Widget> _sections(AppStore store, List<Item> items) {
    final out = <Widget>[];
    for (final cat in kCategories) {
      final inCat = items.where((i) => i.category == cat.name).toList();
      if (inCat.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Row(children: [
          Icon(cat.icon, size: 16, color: cat.color),
          const SizedBox(width: 7),
          Text(cat.name, style: Theme.of(context).textTheme.titleMedium),
        ]),
      ));
      out.add(_grid(inCat));
      out.add(const SizedBox(height: 18));
    }
    return out;
  }

  Widget _grid(List<Item> items) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 172).floor().clamp(2, 7);
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(width: w, child: _ProductTile(item: item, qty: _picked[item.id] ?? 0, onChanged: (q) => _setQty(item, q))),
        ],
      );
    });
  }

  void _openReview(AppStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(
        picked: _picked,
        store: store,
        name: widget.name,
        onChange: (item, q) => _setQty(item, q),
        onConfirm: () => _placeOrder(store),
      ),
    );
  }

  void _placeOrder(AppStore store) {
    try {
      final order = store.placeOrder(customerName: widget.name, customerPhone: widget.phone, cart: Map.of(_picked));
      setState(() => _picked.clear());
      Navigator.pop(context); // review sheet
      showDialog(context: context, builder: (_) => _SuccessDialog(orderId: order.id, items: order.itemCount));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }
}

class _NoOrderState extends StatelessWidget {
  const _NoOrderState();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 76, height: 76, decoration: BoxDecoration(color: AppColors.brandWash, borderRadius: BorderRadius.circular(AppRadius.xl)), child: const Icon(Icons.event_busy_rounded, size: 36, color: AppColors.brand)),
          const SizedBox(height: 18),
          Text('No order link is open right now', style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text("You'll be notified the moment this week's order link goes live.", textAlign: TextAlign.center, style: t.bodyMedium),
        ]),
      ),
    );
  }
}

class _DateBanner extends StatelessWidget {
  final OrderCycle cycle;
  const _DateBanner({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final date = DateFormat('d MMM yyyy').format(now);
    final time = DateFormat('h:mm a').format(now);
    final deadline = DateFormat('EEE, d MMM').format(cycle.weekEnd);
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brandDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                Text('$date  ·  $time', style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.circle, size: 8, color: Color(0xFF9DF3C7)),
                  SizedBox(width: 5),
                  Text('Ordering open', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 6),
              Text('Order by $deadline', style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _Categories({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final names = ['All', ...kCategories.map((c) => c.name)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final n in names)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected == n,
                onSelected: (_) => onSelect(n),
                label: Text(n),
                selectedColor: AppColors.brandWash,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected == n ? AppColors.brandDark : null),
                shape: const StadiumBorder(),
                side: BorderSide(color: selected == n ? AppColors.brand : Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact grocery-style product tile (Flipkart/Blinkit feel).
class _ProductTile extends StatefulWidget {
  final Item item;
  final double qty;
  final ValueChanged<double> onChanged;
  const _ProductTile({required this.item, required this.qty, required this.onChanged});

  @override
  State<_ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<_ProductTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final qty = widget.qty;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final out = item.status == StockStatus.out;
    final low = item.status == StockStatus.low;
    final step = _stepFor(item.unit);
    final picked = qty > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, (_hover && !out) ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: picked ? AppColors.brand : scheme.outline, width: picked ? 1.4 : 1),
          boxShadow: [BoxShadow(color: const Color(0xFF12201C).withValues(alpha: _hover ? 0.12 : 0.04), blurRadius: _hover ? 16 : 10, offset: Offset(0, _hover ? 8 : 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // image header
              Stack(
                children: [
                  Container(
                    height: 72,
                    color: item.cat.color.withValues(alpha: 0.12),
                    alignment: Alignment.center,
                    child: Opacity(opacity: out ? 0.45 : 1, child: Text(item.emoji, style: const TextStyle(fontSize: 34))),
                  ),
                  if (picked)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  if (out)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: const Text('Out', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    )
                  else if (low)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text('Only ${fmtNum(item.currentQty)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 34,
                      child: Text(item.name, style: t.titleSmall?.copyWith(fontSize: 12.5, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    Text(out ? 'Unavailable' : '${fmtNum(item.currentQty)} ${item.unit} left', style: t.bodySmall?.copyWith(fontSize: 11, color: out ? AppColors.danger : scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: out
                          ? const SizedBox.shrink()
                          : (!picked
                              ? OutlinedButton(
                                  onPressed: () => widget.onChanged(step),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.brand,
                                    side: const BorderSide(color: AppColors.brand),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                                  ),
                                  child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                )
                              : _MiniStepper(
                                  qty: qty,
                                  unit: item.unit,
                                  onMinus: () => widget.onChanged(qty - step),
                                  onPlus: qty + step <= item.currentQty ? () => widget.onChanged(qty + step) : null,
                                )),
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
}

class _MiniStepper extends StatelessWidget {
  final double qty;
  final String unit;
  final VoidCallback onMinus;
  final VoidCallback? onPlus;
  const _MiniStepper({required this.qty, required this.unit, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          Flexible(
            child: Text('${fmtNum(qty)} $unit', textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: enabled ? 1 : 0.45))),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final int count;
  final double units;
  final VoidCallback onReview;
  const _SubmitBar({required this.count, required this.units, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(color: scheme.surface, border: Border(top: BorderSide(color: scheme.outline))),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$count ${count == 1 ? 'item' : 'items'} selected', style: t.titleMedium),
                      Text('${fmtNum(units)} units', style: t.bodySmall),
                    ],
                  ),
                ),
                FilledButton.icon(onPressed: onReview, icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Review order')),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 1, duration: 200.ms, curve: Curves.easeOut);
  }
}

class _ReviewSheet extends StatefulWidget {
  final Map<String, double> picked;
  final AppStore store;
  final String name;
  final void Function(Item, double) onChange;
  final VoidCallback onConfirm;
  const _ReviewSheet({required this.picked, required this.store, required this.name, required this.onChange, required this.onConfirm});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = {for (final i in widget.store.items) i.id: i};
    final lines = widget.picked.entries.where((e) => e.value > 0).toList();
    final totalUnits = lines.fold<double>(0, (s, e) => s + e.value);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, bottom: 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.brand),
              const SizedBox(width: 8),
              Text('Review your order', style: t.titleLarge),
            ]),
            const SizedBox(height: 2),
            Text('Check the quantities, then confirm to place the order.', style: t.bodySmall),
            const SizedBox(height: 14),
            Expanded(
              child: lines.isEmpty
                  ? const EmptyState(icon: Icons.shopping_basket_rounded, title: 'Nothing selected')
                  : ListView.separated(
                      controller: controller,
                      itemCount: lines.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final e = lines[i];
                        final item = items[e.key];
                        if (item == null) return const SizedBox.shrink();
                        final step = _stepFor(item.unit);
                        return Row(
                          children: [
                            EmojiTile(item.emoji, color: item.cat.color, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: t.titleSmall),
                                  Text('${fmtNum(item.currentQty)} ${item.unit} in stock', style: t.bodySmall),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 118,
                              height: 36,
                              child: _MiniStepper(
                                qty: e.value,
                                unit: item.unit,
                                onMinus: () { widget.onChange(item, e.value - step); setState(() {}); },
                                onPlus: e.value + step <= item.currentQty ? () { widget.onChange(item, e.value + step); setState(() {}); } : null,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(children: [
                Text('Total', style: t.titleMedium),
                const Spacer(),
                Text('${lines.length} items · ${fmtNum(totalUnits)} units', style: t.titleMedium?.copyWith(color: AppColors.brandDark)),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Ordering as ${widget.name}', style: t.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: lines.isEmpty ? null : widget.onConfirm,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirm & place'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String orderId;
  final int items;
  const _SuccessDialog({required this.orderId, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.successWash, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 38),
            ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 18),
            Text('Order placed!', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text('$orderId · $items items', style: t.bodyMedium),
            const SizedBox(height: 4),
            Text('Track it under My Orders. The store has been notified.', textAlign: TextAlign.center, style: t.bodySmall),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
          ],
        ),
      ),
    );
  }
}
