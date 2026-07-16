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

/// The demand form: the customer picks quantities against **their own remaining
/// entitlement** — never against warehouse stock.
///
/// Everything on this page is bounded by the balance for the demand's month:
/// `allowance + carried-in − already ordered`. So a customer who was on leave
/// and ordered nothing sees their entitlement in full, and one who took bread on
/// an earlier fresh demand finds that much already gone from Cereals.
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
  RationZone _zone = kOfficersZone;

  /// The customer's balance per category for the demand's month, set each build.
  Map<String, CategoryBalance> _balances = const {};

  CategoryBalance _balanceOf(String category) =>
      _balances[category] ??
      CategoryBalance(
        category: category,
        unit: rikCategoryByName(category)?.unit ?? 'kg',
        allowance: 0,
        carriedIn: 0,
        consumed: 0,
      );

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

  /// The most this item may still reach: what's left of the category's balance
  /// for the month, less what's already in the cart, and any per-item maximum.
  double _capForItem(Item item) {
    final picked = _picked[item.id] ?? 0;
    final head = _balanceOf(item.category).remaining - _pickedInCategory(item.category) + picked;
    final itemMax = _zone.maxForItem(item.name);
    var cap = head;
    if (itemMax < cap) cap = itemMax;
    return cap < 0 ? 0 : cap;
  }

  /// Per-item max label (e.g. "Max 8 kg"), or '' when uncapped.
  String _maxLabelFor(Item item) {
    final m = _zone.maxForItem(item.name);
    return m.isFinite ? 'Max ${fmtNum(m)} ${item.unit}' : '';
  }

  /// Add/remove increment for an item, sized to its monthly entitlement.
  double _stepForItem(Item item) => _stepFor(_balanceOf(item.category).total, item.unit);

  bool _isInLieu(Item item) => isInLieuArticle(item.name);

  void _setQty(Item item, double qty, RationMonth month) {
    setState(() {
      var next = qty < 0 ? 0.0 : qty;
      final picked = _picked[item.id] ?? 0;
      final bal = _balanceOf(item.category);
      final head = bal.remaining - _pickedInCategory(item.category) + picked;
      final itemMax = _zone.maxForItem(item.name);
      var cap = head;
      if (itemMax < cap) cap = itemMax;
      if (cap < 0) cap = 0;

      if (next > cap) {
        next = cap;
        final String msg;
        if (itemMax <= head) {
          msg = 'Max ${fmtNum(itemMax)} ${item.unit} of ${item.name} for your zone';
        } else if (cap <= 0) {
          msg = 'Your ${item.category} entitlement for ${month.label} is used up';
        } else {
          msg = 'Only ${fmtQty(cap, bal.unit)} of ${item.category} left in your ${month.label} balance';
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

    // Open demands this customer (by zone) may order in. Until the unit opens
    // one, there is no demand page at all.
    final windows = store.openCyclesFor(widget.designation);
    if (windows.isEmpty) return const DemandNotStarted();

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

    // Only the varieties the admin added to this demand — "if I am not adding
    // it, the customer will not see it".
    final onDemand = store.itemsForCycle(cycle);
    if (onDemand.isEmpty) return _EmptyDemandState(cycle: cycle);

    // The balance this demand spends from — its entitlement month.
    _balances = {
      for (final b in store.balancesFor(
        name: widget.name,
        phone: widget.phone,
        zone: widget.designation,
        month: cycle.month,
      ))
        b.category: b,
    };

    // Single window already used → full-screen "closed for you" state.
    if (windows.length == 1 && alreadyOrdered) {
      return _AlreadyOrderedState(cycle: cycle, balances: _orderedBalances(onDemand));
    }

    final matches = onDemand.where((i) {
      final mq = _query.isEmpty || i.name.toLowerCase().contains(_query.toLowerCase());
      final mc = _category == 'All' || i.category == _category;
      return mq && mc;
    }).toList();
    final grouped = _category == 'All' && _query.isEmpty;
    final cats = _categoriesOnDemand(onDemand);

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
                        onSelect: (id) => setState(() {
                          _selectedCycleId = id;
                          _picked.clear();
                        }),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (alreadyOrdered)
                      _AlreadyOrderedInline(cycle: cycle)
                    else ...[
                      BalanceSummaryCard(
                        month: cycle.month,
                        balances: _orderedBalances(onDemand),
                        picked: _pickedByCategory(),
                        zoneLabel: _zone.level,
                      ),
                      const SizedBox(height: 12),
                      _DemandBanner(cycle: cycle),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(hintText: 'Search items…', prefixIcon: Icon(Icons.search_rounded)),
                      ),
                      const SizedBox(height: 12),
                      _Categories(
                        names: cats,
                        selected: _category,
                        onSelect: (c) => setState(() => _category = c),
                      ),
                      const SizedBox(height: 16),
                      if (matches.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 36), child: EmptyState(icon: Icons.search_off_rounded, title: 'Nothing matches'))
                      else if (grouped)
                        ..._sections(matches, cycle.month)
                      else ...[
                        if (_category != 'All')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CategoryBalanceBar(
                              category: categoryOf(_category),
                              balance: _balanceOf(_category),
                              picked: _pickedInCategory(_category),
                            ),
                          ),
                        _grid(matches, cycle.month),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!alreadyOrdered && _count > 0)
          _SubmitBar(count: _count, units: _units, onReview: () => _openReview(store, cycle)),
      ],
    );
  }

  /// Balances for the categories that actually appear on this demand, in the
  /// catalogue's order.
  List<CategoryBalance> _orderedBalances(List<Item> onDemand) {
    final names = _categoriesOnDemand(onDemand).skip(1); // drop 'All'
    return [for (final n in names) _balanceOf(n)];
  }

  /// 'All' + every category with an item on this demand.
  List<String> _categoriesOnDemand(List<Item> onDemand) {
    final present = onDemand.map((i) => i.category).toSet();
    return ['All', for (final c in kCategories) if (present.contains(c.name)) c.name];
  }

  Map<String, double> _pickedByCategory() {
    final store = _storeRef;
    final out = <String, double>{};
    if (store == null) return out;
    _picked.forEach((id, q) {
      final it = store.items.where((i) => i.id == id);
      if (it.isNotEmpty) out[it.first.category] = (out[it.first.category] ?? 0) + q;
    });
    return out;
  }

  List<Widget> _sections(List<Item> items, RationMonth month) {
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
      out.add(CategoryBalanceBar(
        category: cat,
        balance: _balanceOf(cat.name),
        picked: _pickedInCategory(cat.name),
      ));
      out.add(const SizedBox(height: 10));
      out.add(_grid(inCat, month));
      out.add(const SizedBox(height: 18));
    }
    return out;
  }

  Widget _grid(List<Item> items, RationMonth month) {
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
                onChanged: (q) => _setQty(item, q, month),
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
        cycle: cycle,
        capFor: _capForItem,
        stepFor: _stepForItem,
        onChange: (item, q) => _setQty(item, q, cycle.month),
        onConfirm: () => _placeOrder(store, cycle),
      ),
    );
  }

  void _placeOrder(AppStore store, OrderCycle cycle) {
    try {
      final order = store.placeOrder(
        customerName: widget.name,
        customerPhone: widget.phone,
        cart: Map.of(_picked),
        cycleId: cycle.id,
        zone: widget.designation,
      );
      setState(() => _picked.clear());
      Navigator.pop(context); // review sheet
      showDialog(context: context, builder: (_) => _SuccessDialog(orderId: order.displayId, items: order.itemCount));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }
}

/// Shown until the unit opens a demand. The unit announces it in the group —
/// "we are ready to accept the demand" — and only then does the page appear.
class DemandNotStarted extends StatelessWidget {
  const DemandNotStarted({super.key});

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
            decoration: BoxDecoration(color: AppColors.brandWash, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: const Icon(Icons.hourglass_empty_rounded, size: 36, color: AppColors.brand),
          ),
          const SizedBox(height: 18),
          Text('Demand not started yet', style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'You will be notified when the unit opens it.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ]),
      ),
    );
  }
}

/// The demand is open but the admin hasn't added any varieties to it yet.
class _EmptyDemandState extends StatelessWidget {
  final OrderCycle cycle;
  const _EmptyDemandState({required this.cycle});

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
            decoration: BoxDecoration(color: AppColors.brandWash, borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: const Icon(Icons.playlist_add_rounded, size: 36, color: AppColors.brand),
          ),
          const SizedBox(height: 18),
          Text('${cycle.title} is being prepared', style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('The unit has not added any items to this demand yet. Check back shortly.',
              textAlign: TextAlign.center, style: t.bodyMedium),
        ]),
      ),
    );
  }
}

/// Shown after a customer has placed their demand for the open cycle. Their
/// balance stays visible — what's still due to them for the month.
class _AlreadyOrderedState extends StatelessWidget {
  final OrderCycle cycle;
  final List<CategoryBalance> balances;
  const _AlreadyOrderedState({required this.cycle, required this.balances});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: AppColors.successWash, borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: const Icon(Icons.verified_rounded, size: 38, color: AppColors.success),
            ),
            const SizedBox(height: 18),
            Text('Demand placed for ${cycle.title}', style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Your remaining balance for ${cycle.month.label} is below.',
              textAlign: TextAlign.center,
              style: t.bodyMedium,
            ),
            const SizedBox(height: 20),
            BalanceSummaryCard(
              month: cycle.month,
              balances: balances,
              picked: const {},
              zoneLabel: cycle.isPublic ? '' : cycle.designation,
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal chips to switch between the open demands a customer can use.
/// Already-ordered demands show a check.
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
          Text('Choose a demand', style: t.titleSmall),
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
                        : Icon(w.type == DemandType.fresh ? Icons.eco_rounded : Icons.grain_rounded, size: 16),
                    label: Text(w.title),
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

/// Compact "you've ordered in this demand" banner shown when more than one
/// demand is open, so the selector stays visible to switch to another.
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
                Text("You've placed your demand for ${cycle.title}", style: t.titleSmall),
                const SizedBox(height: 4),
                Text('This demand is closed for you. Pick another open demand above, or check My Orders.', style: t.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The headline card: **what is left with the customer** for the month — not
/// what is in the warehouse. Shows the month's entitlement, anything carried in
/// from last month, and what is still due.
class BalanceSummaryCard extends StatelessWidget {
  final RationMonth month;
  final List<CategoryBalance> balances;
  final Map<String, double> picked;
  final String zoneLabel;

  const BalanceSummaryCard({
    super.key,
    required this.month,
    required this.balances,
    this.picked = const {},
    this.zoneLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (balances.isEmpty) return const SizedBox.shrink();

    final carried = balances.fold<double>(0, (s, b) => s + b.carriedIn);
    final inCart = picked.values.fold<double>(0, (s, v) => s + v);
    final remaining = balances.fold<double>(0, (s, b) => s + b.remaining) - inCart;
    final total = balances.fold<double>(0, (s, b) => s + b.total);
    final used = total <= 0 ? 0.0 : ((total - remaining) / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Balance · ${month.label}${zoneLabel.isEmpty ? '' : ' · $zoneLabel'}',
                  style: t.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          UsageBar(used01: used, height: 10),
          const SizedBox(height: 12),
          Row(children: [
            _figure(context, 'Allowed', fmtNum(total)),
            _divider(context),
            _figure(context, 'Used', fmtNum(total - remaining)),
            _divider(context),
            _figure(context, 'Left', fmtNum(remaining), emphasize: true),
          ]),
          if (carried > 0 || inCart > 0) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (carried > 0)
                Pill('+${fmtNum(carried)} carried', color: AppColors.accent, icon: Icons.move_up_rounded),
              if (inCart > 0) Pill('${fmtNum(inCart)} in cart', color: AppColors.cDairy, icon: Icons.shopping_basket_rounded),
            ]),
          ],
        ],
      ),
    );
  }

  static Widget _figure(BuildContext context, String label, String value, {bool emphasize = false}) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.bodySmall),
          const SizedBox(height: 1),
          Text(
            value,
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasize ? AppColors.brandDark : null,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Theme.of(context).colorScheme.outline,
      );
}

/// Per-category balance bar: how much of this category is still due to the
/// customer this month, and how much of it this demand is about to use.
class CategoryBalanceBar extends StatelessWidget {
  final Category category;
  final CategoryBalance balance;
  final double picked;
  const CategoryBalanceBar({super.key, required this.category, required this.balance, this.picked = 0});

  @override
  Widget build(BuildContext context) {
    if (balance.total <= 0) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final left = (balance.remaining - picked).clamp(0.0, double.infinity);
    final used01 = ((balance.total - left) / balance.total).clamp(0.0, 1.0);
    final empty = left <= 1e-9;

    // Allowed → Used → Left, spelt out for every category (with the cart
    // counted as used, so the bar moves while picking).
    final detail =
        'Allowed ${fmtNum(balance.total)} · Used ${fmtNum(balance.total - left)} · Left ${fmtNum(left)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                empty ? '${category.name} — used up' : category.name,
                style: t.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: empty ? AppColors.danger : scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${fmtNum(left)} ${balance.unit} left',
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: usageColor(used01)),
            ),
          ],
        ),
        const SizedBox(height: 5),
        UsageBar(used01: used01, height: 7),
        const SizedBox(height: 3),
        Text(detail, style: t.bodySmall?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

/// The demand banner: which demand this is (fresh / dry), the days it covers,
/// and when it closes.
class _DemandBanner extends StatelessWidget {
  final OrderCycle cycle;
  const _DemandBanner({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fresh = cycle.type == DemandType.fresh;
    final deadline = DateFormat('EEE, d MMM').format(cycle.weekEnd);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(fresh ? Icons.eco_outlined : Icons.grain, color: scheme.onSurface, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cycle.type.label} ration · ${cycle.days} days', style: t.titleSmall),
                const SizedBox(height: 2),
                Text('Closes $deadline', style: t.bodySmall),
              ],
            ),
          ),
          const Pill('Open', color: AppColors.success),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  final List<String> names;
  final String selected;
  final ValueChanged<String> onSelect;
  const _Categories({required this.names, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
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

/// Compact product tile. No stock is shown (ration system); [maxQty] is what's
/// left of the customer's own entitlement for this category.
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
                              child: Text(atLimit ? 'NO BALANCE' : 'ADD', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 11.5)),
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
                FilledButton.icon(onPressed: onReview, icon: const Icon(Icons.arrow_forward_rounded, size: 18), label: const Text('Review demand')),
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
  final OrderCycle cycle;
  final double Function(Item) capFor;
  final double Function(Item) stepFor;
  final void Function(Item, double) onChange;
  final VoidCallback onConfirm;
  const _ReviewSheet({
    required this.picked,
    required this.store,
    required this.name,
    required this.cycle,
    required this.capFor,
    required this.stepFor,
    required this.onChange,
    required this.onConfirm,
  });

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
              Expanded(child: Text('Review your demand', style: t.titleLarge)),
            ]),
            const SizedBox(height: 2),
            Text('${widget.cycle.type.label} ration · ${widget.cycle.month.label} · comes out of your balance.', style: t.bodySmall),
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
                                  Text('${item.category} · per ${item.unit}', style: t.bodySmall),
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
            Text('Demand placed!', style: t.headlineSmall),
            const SizedBox(height: 6),
            Text('$orderId · $items items', style: t.bodyMedium),
            const SizedBox(height: 4),
            Text('It has come out of your entitlement — anything left stays with you for the next demand.',
                textAlign: TextAlign.center, style: t.bodySmall),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
          ],
        ),
      ),
    );
  }
}
