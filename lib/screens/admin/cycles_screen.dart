import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notify_customers_sheet.dart';
import '../../widgets/ui_kit.dart';
import '../customer/customer_auth.dart';

class CyclesScreen extends StatelessWidget {
  const CyclesScreen({super.key});

  String _range(OrderCycle c) {
    final f = DateFormat('MMM d');
    return '${f.format(c.weekStart)} – ${f.format(c.weekEnd)}, ${c.weekEnd.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    // The genuinely OPEN cycle (if any) — not just the latest one.
    final cyclesByRecent = store.cyclesByRecent;
    final openCycle = cyclesByRecent.where((c) => c.status == CycleStatus.open).firstOrNull;
    final past = cyclesByRecent.where((c) => c.id != openCycle?.id).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Weekly order link',
                subtitle: 'Generate a fresh ordering link each week and share it with customers',
                action: FilledButton.icon(
                  onPressed: () {
                    final c = store.openNewCycle();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.title} link generated')));
                  },
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text('New link'),
                ),
              ),
              const SizedBox(height: 18),
              if (openCycle != null)
                _ActiveCard(store: store, cycle: openCycle, range: _range(openCycle))
              else
                const _NoLiveLinkCard(),
              const SizedBox(height: 24),
              Text('Past weeks', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (past.isEmpty)
                const EmptyState(icon: Icons.history_rounded, title: 'No past cycles yet')
              else
                ...past.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PastRow(cycle: c, range: _range(c), orders: store.orders.where((o) => o.cycleId == c.id).length),
                    )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when no order window is open — prompts the admin to start one.
class _NoLiveLinkCard extends StatelessWidget {
  const _NoLiveLinkCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Icon(Icons.link_off_rounded, color: scheme.onSurfaceVariant, size: 28),
          ),
          const SizedBox(height: 14),
          Text('No order window is open', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Customers cannot place orders right now. Generate a new weekly link to open ordering.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final AppStore store;
  final OrderCycle cycle;
  final String range;
  const _ActiveCard({required this.store, required this.cycle, required this.range});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final orderCount = store.orders.where((o) => o.cycleId == cycle.id).length;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 430;
            return Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.brandWash, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: const Icon(Icons.link_rounded, color: AppColors.brand),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(cycle.title, style: t.titleLarge, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          const _LiveDot(),
                        ],
                      ),
                      Text(range, style: t.bodyMedium, maxLines: 2),
                      if (narrow) ...[
                        const SizedBox(height: 6),
                        Pill('$orderCount orders', color: AppColors.cDairy, icon: Icons.receipt_long_rounded),
                      ],
                    ],
                  ),
                ),
                if (!narrow)
                  Pill('$orderCount orders', color: AppColors.cDairy, icon: Icons.receipt_long_rounded),
              ],
            );
          }),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, size: 18, color: AppColors.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cycle.link, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cycle.link));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerWelcome())),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open order page'),
              ),
              OutlinedButton.icon(
                onPressed: () => _notify(context, store),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Notify customers'),
              ),
              OutlinedButton.icon(
                onPressed: () => _prepareWhatsAppText(context),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Prepare WhatsApp text'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  store.closeCycle(cycle);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order window closed')));
                },
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: const Text('Close window'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  store.openNewCycle();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Previous week closed · new link is live')));
                },
                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                label: const Text('Close & start next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _notify(BuildContext context, AppStore store) async {
    const body = 'Place your weekly order before the window closes.';
    final result = await showNotifyCustomersSheet(
      context,
      title: '${cycle.title} order link is open',
      body: body,
    );
    if (result != null && context.mounted) {
      await showBroadcastDeliveryDialog(
        context,
        result,
        message: '${cycle.title} order link is open. $body Order here: ${cycle.link}',
        subject: 'StockFlow — ${cycle.title} order window is open',
      );
    }
  }

  /// Builds the standard home-delivery WhatsApp announcement with this week's
  /// live order link and dates filled in, ready to copy and forward.
  void _prepareWhatsAppText(BuildContext context) {
    final d = DateFormat('d MMM yy');
    final delivery = cycle.weekEnd.add(const Duration(days: 1));
    final message = '''Greetings of the day !!

*RIK 2nd Fresh Home delivery (Dharamvir and Tarangini Apartment) for the month of ${DateFormat('MMM yy').format(delivery)}* is scheduled on *${d.format(delivery)}*. All home delivery subscribed personnel are requested to select their preferred varieties by filling the below mentioned order form latest by *1800 hrs* on *${d.format(cycle.weekEnd)}*. Request timely participation by all concerned.

_*Onion and Potato will be delivered as per normal entitlement. This order form aims at providing better variety to all home delivery subscribed personnel.*_

${cycle.link}

*Note:-* All items are subject to availability in local market and might change in case of unforeseen circumstances.

Regards
Team BVY(Koc)''';

    final controller = TextEditingController(text: message);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('WhatsApp message'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This week\'s link is filled in. Edit if needed, then copy and paste into your WhatsApp group.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: controller.text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied — paste it in WhatsApp')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy message'),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: AppColors.successWash, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, size: 8, color: AppColors.success),
          SizedBox(width: 5),
          Text('Live', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  final OrderCycle cycle;
  final String range;
  final int orders;
  const _PastRow({required this.cycle, required this.range, required this.orders});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: const Icon(Icons.history_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cycle.title, style: t.titleSmall),
                Text(range, style: t.bodySmall),
              ],
            ),
          ),
          Text('$orders orders', style: t.bodySmall),
          const SizedBox(width: 12),
          const Pill('Closed', color: AppColors.inkSoft),
        ],
      ),
    );
  }
}
