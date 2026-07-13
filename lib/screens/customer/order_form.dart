import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/customer_orders.dart';
import '../../widgets/ui_kit.dart';

/// A friendly add/remove increment sized to the entitlement [cap] so ~6–8 taps
/// fill any category, whether it's 0.06 kg of tea or 14 eggs.
double _stepFor(double cap, String unit) {
  if (unit == 'nos' || unit == 'dozen' || unit == 'piece' || unit == 'packet') {
    if (cap >= 24) return 6;
    if (cap >= 10) return 2;
    return 1;
  }
  const nice = <double>[0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10, 25, 50];
  final target = cap / 8;
  var best = nice.first;
  var bestDiff = (nice.first - target).abs();
  for (final s in nice) {
    final d = (s - target).abs();
    if (d < bestDiff) {
      best = s;
      bestDiff = d;
    }
  }
  return best;
}

/// Weekly order form: pick items + quantities, review a summary, then confirm.
class OrderForm extends StatefulWidget {
  final String name;
  final String phone;
  final String designation;
  const OrderForm({super.key, required this.name, required this.phone, this.designation = ''});

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final Map<String, double> _picked = {};
  String _query = '';
  String _category = 'All';
  String? _selectedCycleId;
  AppStore? _storeRef;

  int get _count => _picked.values.where((v) => v > 0).length;
  double get _units => _picked.values.fold(0.0, (s, v) => s + v);

  /// The customer's ration zone (entitlement criteria), set each build.
  RationZone _zone = kRationZones.first;

  /// Quantity already picked across all items in [cat].
  double _pickedInCategory(String cat) {
    final store = _storeRef;
    if (store == null) return 0;
    var sum = 0.0;
    _picked.forEach((id, q) {
      final it = store.items.where((i) => i.id == id);
      if (it.isNotEmpty && it.first.category == cat) sum += q;
    });
    return sum;
  }

  /// Total ration points used so far (sum of all picked quantities).
  double get _masterUsed => _picked.values.fold(0.0, (s, v) => s + v);

  /// The most this item may still reach, bounded by the master ration cap, the
  /// item's category cap, and any per-item maximum for the zone.
  double _capForItem(Item item) {
    final picked = _picked[item.id] ?? 0;
    final masterHead = _zone.masterLimit - _masterUsed + picked;
    final catHead = _zone.categoryLimit(item.category) - _pickedInCategory(item.category) + picked;
    final itemMax = _zone.maxForItem(item.name);
    var cap = masterHead;
    if (catHead < cap) cap = catHead;
    if (itemMax < cap) cap = itemMax;
    return cap < 0 ? 0 : cap;
  }

  /// Per-item max label (e.g. "Max 8 kg"), or '' when uncapped.
  String _maxLabelFor(Item item) {
    final m = _zone.maxForItem(item.name);
    return m.isFinite ? 'Max ${fmtNum(m)} ${item.unit}' : '';
  }

  /// Add/remove increment for an item, sized to its category entitlement.
  double _stepForItem(Item item) => _stepFor(_zone.categoryLimit(item.category), item.unit);

  bool _isInLieu(Item item) => isInLieuArticle(item.name);

  void _setQty(Item item, double qty) {
    setState(() {
      var next = qty < 0 ? 0.0 : qty;
      final picked = _picked[item.id] ?? 0;
      final masterHead = _zone.masterLimit - _masterUsed + picked;
      final catHead = _zone.categoryLimit(item.category) - _pickedInCategory(item.category) + picked;
      final itemMax = _zone.maxForItem(item.name);
      var cap = masterHead;
      if (catHead < cap) cap = catHead;
      if (itemMax < cap) cap = itemMax;
      if (cap < 0) cap = 0;

      if (next > cap) {
        next = cap;
        final String msg;
        if (cap == itemMax) {
          msg = 'Max ${fmtNum(itemMax)} ${item.unit} of ${item.name} for your zone';
        } else if (cap == catHead) {
          msg = '${item.category} ration limit reached';
        } else {
          msg = 'Master ration limit reached';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2), content: Text(msg)),
        );
      }
      if (next <= 0) {
        _picked.remove(item.id);
      } else {
        _picked[item.id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    _storeRef = store;
    _zone = store.zoneFor(widget.designation);

    // Drop only items that no longer exist — stock never removes an item.
    _picked.removeWhere((id, qty) => !store.items.any((i) => i.id == id));

    // Open ration links this customer (by zone) may order in.
    final windows = store.openCyclesFor(widget.designation);
    if (windows.isEmpty || store.items.isEmpty) return const _NoOrderState();

    final orderedIds = customerOrdersFor(store, widget.name, widget.phone)
        .map((o) => o.cycleId)
        .toSet();

    // Selected window: the chosen one if still open, else the first not-yet-
    // ordered window, else the first.
    final cycle = windows.firstWhere(
      (c) => c.id == _selectedCycleId,
      orElse: () => windows.firstWhere(
        (c) => !orderedIds.contains(c.id),
        orElse: () => windows.first,
      ),
    );
    final alreadyOrdered = orderedIds.contains(cycle.id);

    // Single window already used → full-screen "closed for you" state.
    if (windows.length == 1 && alreadyOrdered) return _AlreadyOrderedState(cycle: cycle);

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
                    if (windows.length > 1) ...[
                      _WindowSelector(
                        windows: windows,
                        selectedId: cycle.id,
                        orderedIds: orderedIds,
                        onSelect: (id) => setState(() => _selectedCycleId = id),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (alreadyOrdered)
                      _AlreadyOrderedInline(cycle: cycle)
                    else ...[
                      _MasterRationBar(used: _masterUsed, limit: _zone.masterLimit, level: _zone.level),
                      const SizedBox(height: 12),
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
                      else ...[
                        if (_category != 'All')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CategoryQuotaBar(
                              category: categoryOf(_category),
                              picked: _pickedInCategory(_category),
                              quota: _zone.categoryLimit(_category),
                            ),
                          ),
                        _grid(matches),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!alreadyOrdered && _count > 0) _SubmitBar(count: _count, units: _units, onReview: () => _openReview(store, cycle)),
      ],
    );
  }

  List<Widget> _sections(AppStore store, List<Item> items) {
    final out = <Widget>[];
    for (final cat in kCategories) {
      final inCat = items.where((i) => i.category == cat.name).toList();
      if (inCat.isEmpty) continue;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(children: [
          Icon(cat.icon, size: 16, color: cat.color),
          const SizedBox(width: 7),
          Text(cat.name, style: Theme.of(context).textTheme.titleMedium),
        ]),
      ));
      out.add(_CategoryQuotaBar(
        category: cat,
        picked: _pickedInCategory(cat.name),
        quota: _zone.categoryLimit(cat.name),
      ));
      out.add(const SizedBox(height: 10));
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
            SizedBox(
              width: w,
              child: _ProductTile(
                item: item,
                qty: _picked[item.id] ?? 0,
                maxQty: _capForItem(item),
                maxLabel: _maxLabelFor(item),
                step: _stepForItem(item),
                inLieu: _isInLieu(item),
                onChanged: (q) => _setQty(item, q),
              ),
            ),
        ],
      );
    });
  }

  void _openReview(AppStore store, OrderCycle cycle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(
        picked: _picked,
        store: store,
        name: widget.name,
        capFor: _capForItem,
        stepFor: _stepForItem,
        onChange: (item, q) => _setQty(item, q),
        onConfirm: () => _placeOrder(store, cycle),
      ),
    );
  }

  void _placeOrder(AppStore store, OrderCycle cycle) {
    try {
      final order = store.placeOrder(customerName: widget.name, customerPhone: widget.phone, cart: Map.of(_picked), cycleId: cycle.id);
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

/// Shown after a customer has already placed their order for the open cycle —
/// the link is closed for them until the next window.
class _AlreadyOrderedState extends StatelessWidget {
  final OrderCycle cycle;
  const _AlreadyOrderedState({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: AppColors.successWash, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: const Icon(Icons.verified_rounded, size: 38, color: AppColors.success),
          ),
          const SizedBox(height: 18),
          Text("You've ordered for ${cycle.title}", style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'The order link is now closed for you this week. Check it under My Orders — the link reopens with the next window.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ]),
      ),
    );
  }
}

/// Horizontal chips to switch between the open order windows a customer can use
/// (two windows in a week, and/or designation-scoped links). Already-ordered
/// windows show a check.
class _WindowSelector extends StatelessWidget {
  final List<OrderCycle> windows;
  final String selectedId;
  final Set<String> orderedIds;
  final ValueChanged<String> onSelect;
  const _WindowSelector({required this.windows, required this.selectedId, required this.orderedIds, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.event_available_rounded, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          Text('Choose an order window', style: t.titleSmall),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final w in windows)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: w.id == selectedId,
                    onSelected: (_) => onSelect(w.id),
                    avatar: orderedIds.contains(w.id)
                        ? const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success)
                        : (w.isPublic ? null : const Icon(Icons.badge_outlined, size: 16)),
                    label: Text(w.title.replaceFirst('Week ', 'Wk ')),
                    selectedColor: AppColors.brandWash,
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, color: w.id == selectedId ? AppColors.brandDark : null),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: w.id == selectedId ? AppColors.brand : scheme.outline),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact "you've ordered in this window" banner shown when more than one
/// window is open, so the selector stays visible to switch to another.
class _AlreadyOrderedInline extends StatelessWidget {
  final OrderCycle cycle;
  const _AlreadyOrderedInline({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.successWash,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You've ordered for ${cycle.title}", style: t.titleSmall),
                const SizedBox(height: 4),
                Text('This window is closed for you. Pick another open window above, or check My Orders.', style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The prominent master ration bar — total entitlement used across all food
/// categories for the customer's zone. When it fills, nothing more can be added.
class _MasterRationBar extends StatelessWidget {
  final double used;
  final double limit;
  final String level;
  const _MasterRationBar({required this.used, required this.limit, required this.level});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ratio = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final full = used >= limit - 0.0001;
    final color = full ? AppColors.warning : AppColors.brand;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Text('Your ration · $level zone', style: t.titleSmall),
              const Spacer(),
              Text('${fmtNum(used)} / ${fmtNum(limit)}', style: t.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: scheme.surfaceContainerHighest),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            full ? 'Master ration full — remove an item to add another' : 'RIK $level entitlement · your full ration for this week',
            style: t.bodySmall?.copyWith(color: full ? AppColors.warning : scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Per-category ration bar with an animated progress fill. Shown above each
/// category while ordering so the customer sees how much of their allowance is
/// left (rule-based limit enforced in [_OrderFormState._setQty]).
class _CategoryQuotaBar extends StatelessWidget {
  final Category category;
  final double picked;
  final double quota;
  const _CategoryQuotaBar({required this.category, required this.picked, required this.quota});

  @override
  Widget build(BuildContext context) {
    if (quota <= 0) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ratio = (picked / quota).clamp(0.0, 1.0);
    final full = picked >= quota - 0.0001;
    final color = full ? AppColors.warning : category.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              full ? '${category.name} ration full' : '${category.name} ration',
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: full ? AppColors.warning : scheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text('${fmtNum(picked)} / ${fmtNum(quota)}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
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

/// Compact product tile. No stock is shown (ration system); [maxQty] is the
/// per-item ration cap that gates how much can be added.
class _ProductTile extends StatefulWidget {
  final Item item;
  final double qty;
  final double maxQty;
  final String maxLabel;
  final double step;
  final bool inLieu;
  final ValueChanged<double> onChanged;
  const _ProductTile({required this.item, required this.qty, required this.maxQty, required this.maxLabel, required this.step, required this.inLieu, required this.onChanged});

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
    final step = widget.step;
    final picked = qty > 0;
    final canAddMore = qty + step <= widget.maxQty + 1e-9;
    final atLimit = widget.maxQty <= 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
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
                    child: Text(item.emoji, style: const TextStyle(fontSize: 34)),
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
                  if (widget.maxLabel.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text(widget.maxLabel, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700)),
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
                    Text(
                      widget.inLieu ? 'In lieu · per ${item.unit}' : 'per ${item.unit}',
                      style: t.bodySmall?.copyWith(fontSize: 11, color: widget.inLieu ? AppColors.accent : scheme.onSurfaceVariant, fontWeight: widget.inLieu ? FontWeight.w700 : FontWeight.w400),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: !picked
                          ? OutlinedButton(
                              onPressed: atLimit ? null : () => widget.onChanged(step),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brand,
                                side: BorderSide(color: atLimit ? scheme.outline : AppColors.brand),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                              ),
                              child: Text(atLimit ? 'LIMIT' : 'ADD', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            )
                          : _MiniStepper(
                              qty: qty,
                              unit: item.unit,
                              onMinus: () => widget.onChanged(qty - step),
                              onPlus: canAddMore ? () => widget.onChanged(qty + step) : null,
                            ),
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
  final double Function(Item) capFor;
  final double Function(Item) stepFor;
  final void Function(Item, double) onChange;
  final VoidCallback onConfirm;
  const _ReviewSheet({required this.picked, required this.store, required this.name, required this.capFor, required this.stepFor, required this.onChange, required this.onConfirm});

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
                        final step = widget.stepFor(item);
                        return Row(
                          children: [
                            EmojiTile(item.emoji, color: item.cat.color, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: t.titleSmall),
                                  Text('per ${item.unit}', style: t.bodySmall),
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
                                onPlus: e.value + step <= widget.capFor(item) + 1e-9 ? () { widget.onChange(item, e.value + step); setState(() {}); } : null,
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
