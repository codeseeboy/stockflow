import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var orders = store.orders;
    if (_filter != null) orders = orders.where((o) => o.status == _filter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Orders',
                subtitle: '${store.ordersThisCycle.length} orders in ${store.activeCycle.title}',
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip(context, 'All', _filter == null, () => setState(() => _filter = null)),
                    for (final s in OrderStatus.values)
                      _chip(context, orderStatusLabel(s), _filter == s, () => setState(() => _filter = s), orderStatusColor(s)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: EmptyState(icon: Icons.receipt_long_rounded, title: 'No orders here', subtitle: 'Orders placed from the weekly link appear here.'),
                )
              else
                ...orders.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _OrderCard(order: o, store: store),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool selected, VoidCallback onTap, [Color? color]) {
    final c = color ?? AppColors.brand;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(label),
        selectedColor: c.withValues(alpha: 0.15),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: selected ? c : null),
        shape: const StadiumBorder(),
        side: BorderSide(color: selected ? c : Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final AppStore store;
  const _OrderCard({required this.order, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brandWash,
                child: Text(order.customerName.isEmpty ? '?' : order.customerName[0].toUpperCase(), style: const TextStyle(color: AppColors.brandDark, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName, style: t.titleMedium),
                    Text('${order.id} · ${relTime(order.createdAt)}', style: t.bodySmall),
                  ],
                ),
              ),
              Pill(orderStatusLabel(order.status), color: orderStatusColor(order.status)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in order.lines)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('${l.emoji}  ${l.name} · ${fmtQty(l.qty, l.unit)}',
                      style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, c) {
            final phone = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(child: Text(order.customerPhone, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
              ],
            );
            final actions = Row(mainAxisSize: MainAxisSize.min, children: _actions(context));
            // Stack phone above actions when the card is too narrow for both.
            if (c.maxWidth < 380) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [phone, const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: actions)],
              );
            }
            return Row(children: [Expanded(child: phone), actions]);
          }),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (order.status) {
      case OrderStatus.pending:
        return [
          TextButton(
            onPressed: () => store.updateOrderStatus(order, OrderStatus.cancelled),
            child: const Text('Cancel', style: TextStyle(color: AppColors.danger)),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: () => store.updateOrderStatus(order, OrderStatus.confirmed),
            child: const Text('Confirm'),
          ),
        ];
      case OrderStatus.confirmed:
        return [
          FilledButton(
            onPressed: () => store.updateOrderStatus(order, OrderStatus.fulfilled),
            child: const Text('Mark fulfilled'),
          ),
        ];
      case OrderStatus.fulfilled:
        return [
          Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 6),
              Text('Fulfilled', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
            ],
          ),
        ];
      case OrderStatus.cancelled:
        return [
          TextButton(
            onPressed: () => store.updateOrderStatus(order, OrderStatus.pending),
            child: const Text('Reopen'),
          ),
        ];
    }
  }
}
