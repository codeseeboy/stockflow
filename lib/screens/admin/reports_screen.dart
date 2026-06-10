import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/downloader.dart';
import '../../utils/pdf_reports.dart';
import '../../widgets/ui_kit.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _busy;

  Future<void> _generate(String key, String filenameBase, Future<Uint8List> Function(AppStore) build) async {
    final store = context.read<AppStore>();
    setState(() => _busy = key);
    try {
      final bytes = await build(store);
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      downloadBytes(bytes, '${filenameBase}_$stamp.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated. Check your downloads')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Generate reports',
                  subtitle: 'Export a clean PDF you can print or share',
                ),
                const SizedBox(height: 18),
                _ReportCard(
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.brand,
                  title: 'Stock report',
                  desc: 'Full master stock with current vs opening levels and status for every item.',
                  stat: '${store.totalItems} items',
                  busy: _busy == 'stock',
                  onTap: () => _generate('stock', 'StockFlow_Stock_Report', buildStockReport),
                ),
                const SizedBox(height: 14),
                _ReportCard(
                  icon: Icons.trending_down_rounded,
                  color: AppColors.warning,
                  title: 'Low-stock / reorder report',
                  desc: 'Items at or below reorder level with estimated days left, so you know what to buy next.',
                  stat: '${store.lowCount + store.outCount} need attention',
                  busy: _busy == 'low',
                  onTap: () => _generate('low', 'StockFlow_LowStock_Report', buildLowStockReport),
                ),
                const SizedBox(height: 14),
                _ReportCard(
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.cDairy,
                  title: 'Orders report',
                  desc: 'Every customer order with contents, status and timestamp.',
                  stat: '${store.orders.length} orders',
                  busy: _busy == 'orders',
                  onTap: () => _generate('orders', 'StockFlow_Orders_Report', buildOrdersReport),
                ),
                const SizedBox(height: 24),
                AppCard(
                  color: AppColors.brandWash,
                  child: Row(
                    children: const [
                      Icon(Icons.lightbulb_rounded, color: AppColors.brand),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reports use live data. Once on Supabase, you can also schedule weekly reports by email.',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.brandDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final String stat;
  final bool busy;
  final VoidCallback onTap;
  const _ReportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.stat,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: t.titleMedium)),
                    Pill(stat, color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(desc, style: t.bodyMedium),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onTap,
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: Text(busy ? 'Generating…' : 'Download PDF'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
