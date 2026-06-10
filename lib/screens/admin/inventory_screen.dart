import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/add_item_sheet.dart';
import '../../widgets/emoji_picker.dart';
import '../../widgets/ui_kit.dart';
import 'import_stock_screen.dart';

/// A tappable icon field that opens the emoji/icon picker.
class IconPickerTile extends StatelessWidget {
  final String emoji;
  final ValueChanged<String> onPicked;
  final double size;
  const IconPickerTile({super.key, required this.emoji, required this.onPicked, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap to choose an icon',
      child: InkWell(
        onTap: () async {
          final picked = await showEmojiPicker(context, current: emoji);
          if (picked != null) onPicked(picked);
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.brandWash,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
          ),
          child: Stack(
            children: [
              Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.42))),
              Positioned(
                right: 3,
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 9, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';
  String _category = 'All';
  bool _onlyLow = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    var items = store.items.where((i) {
      final matchQ = _query.isEmpty || i.name.toLowerCase().contains(_query.toLowerCase());
      final matchC = _category == 'All' || i.category == _category;
      final matchLow = !_onlyLow || i.status != StockStatus.inStock;
      return matchQ && matchC && matchLow;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: kIsWeb ? null : FloatingActionButton.extended(
        onPressed: () => showAddItemSheet(context, store),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Toolbar(
                  query: _query,
                  onQuery: (v) => setState(() => _query = v),
                  onlyLow: _onlyLow,
                  onToggleLow: () => setState(() => _onlyLow = !_onlyLow),
                  onImport: () => _openImport(context),
                  onAdd: () => showAddItemSheet(context, store),
                ),
                const SizedBox(height: 14),
                _CategoryFilter(selected: _category, onSelect: (c) => setState(() => _category = c)),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: EmptyState(icon: Icons.search_off_rounded, title: 'No items found', subtitle: 'Try a different search or filter.'),
                  )
                else
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 1040
                        ? 3
                        : c.maxWidth > 680
                            ? 2
                            : 1;
                    final w = (c.maxWidth - (cols - 1) * 14) / cols;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final item in items)
                          SizedBox(width: w, child: _ItemCard(item: item, store: store)),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openImport(BuildContext context) {
    if (kIsWeb) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportStockScreen()));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.computer_rounded, color: AppColors.brand, size: 32),
        title: const Text('Import on the website'),
        content: const Text(
          'Bulk Excel / CSV import is part of the full admin tools on the website. '
          'Open StockFlow in a browser to upload your monthly stock sheet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

}

class _Toolbar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQuery;
  final bool onlyLow;
  final VoidCallback onToggleLow;
  final VoidCallback onImport;
  final VoidCallback onAdd;
  const _Toolbar({
    required this.query,
    required this.onQuery,
    required this.onlyLow,
    required this.onToggleLow,
    required this.onImport,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final search = TextField(
        onChanged: onQuery,
        decoration: const InputDecoration(
          hintText: 'Search items…',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilterChip(
            selected: onlyLow,
            onSelected: (_) => onToggleLow(),
            avatar: Icon(Icons.warning_amber_rounded, size: 16, color: onlyLow ? AppColors.warning : null),
            label: const Text('Low & out'),
            selectedColor: AppColors.warningWash,
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Import'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item'),
          ),
        ],
      );
      if (c.maxWidth < 560) {
        return Column(children: [search, const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: actions)]);
      }
      return Row(children: [Expanded(child: search), const SizedBox(width: 12), actions]);
    });
  }
}

class _CategoryFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryFilter({required this.selected, required this.onSelect});

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
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected == n ? AppColors.brandDark : null,
                ),
                shape: const StadiumBorder(),
                side: BorderSide(color: selected == n ? AppColors.brand : Theme.of(context).colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final AppStore store;
  const _ItemCard({required this.item, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => _openEditor(context, store, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiTile(item.emoji, color: item.cat.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(item.cat.icon, size: 13, color: item.cat.color),
                        const SizedBox(width: 4),
                        Text(item.category, style: t.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(item.status, dense: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtNum(item.currentQty), style: t.headlineSmall),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${item.unit} left', style: t.bodySmall),
              ),
              const Spacer(),
              Text('of ${fmtNum(item.openingQty)}', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          StockBar(fraction: item.fraction, status: item.status),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Reorder at ${fmtNum(item.reorderLevel)}', style: t.bodySmall),
              const Spacer(),
              Text('Tap to edit', style: t.bodySmall?.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, AppStore store, Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ItemEditor(store: store, item: item),
      ),
    );
  }
}

class _ItemEditor extends StatefulWidget {
  final AppStore store;
  final Item item;
  const _ItemEditor({required this.store, required this.item});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _qty = TextEditingController(text: fmtNum(widget.item.currentQty));
  late final TextEditingController _reorder = TextEditingController(text: fmtNum(widget.item.reorderLevel));
  late String _emoji = widget.item.emoji;

  @override
  void dispose() {
    _qty.dispose();
    _reorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconPickerTile(emoji: _emoji, size: 52, onPicked: (e) => setState(() => _emoji = e)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: t.titleLarge),
                    Text('${item.category} · per ${item.unit}', style: t.bodyMedium),
                  ],
                ),
              ),
              StatusBadge(item.status),
            ],
          ),
          const SizedBox(height: 22),
          Text('Current quantity (${item.unit})', style: t.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.inventory_2_outlined)),
          ),
          const SizedBox(height: 16),
          Text('Reorder level (alert when below this)', style: t.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _reorder,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.flag_outlined)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _qty.text = fmtNum(item.openingQty));
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Restock to opening (${fmtNum(item.openingQty)} ${item.unit})'),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final q = double.tryParse(_qty.text.trim());
                final r = double.tryParse(_reorder.text.trim());
                if (q != null) widget.store.setStock(item, q);
                if (r != null) widget.store.setReorder(item, r);
                if (_emoji != item.emoji) widget.store.setEmoji(item, _emoji);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} updated')));
              },
              child: const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
