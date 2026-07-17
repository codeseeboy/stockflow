import 'package:flutter/material.dart';
import '../data/app_store.dart';
import '../data/food_icon_brain_loader.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/item_icon_brain.dart';
import 'emoji_picker.dart';
import 'notify_customers_sheet.dart';

/// Opens the add-item sheet (dashboard, inventory, anywhere). [initialZone]
/// preselects which zone's stock pool the new item joins — pass the zone
/// whose inventory view the admin was already looking at.
void showAddItemSheet(BuildContext context, AppStore store, {String? initialZone}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AddItemSheet(store: store, initialZone: initialZone),
    ),
  );
}

class AddItemSheet extends StatefulWidget {
  final AppStore store;
  final String? initialZone;
  const AddItemSheet({super.key, required this.store, this.initialZone});

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _reorder = TextEditingController();
  String _emoji = '📦';
  String _category = kCategories.first.name;
  String _unit = 'kg';
  late String _zone = widget.initialZone ?? (widget.store.zoneNames.isNotEmpty ? widget.store.zoneNames.first : '');
  bool _emojiLocked = false;
  bool _notifyCustomers = true;
  ItemVisualSuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    final suggestion = ItemIconBrain.suggest(_name.text, widget.store.items);
    setState(() {
      _suggestion = _name.text.trim().isEmpty ? null : suggestion;
      if (!_emojiLocked && suggestion.confidence > 0) {
        _emoji = suggestion.emoji;
        _category = suggestion.category;
        _unit = suggestion.unit;
      }
    });
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _qty.dispose();
    _reorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final brainCount = FoodIconBrainLoader.aliasCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add new item', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              brainCount > 0
                  ? 'Type any name — $brainCount+ foods in the icon brain (Excel-ready).'
                  : 'Type a name — StockFlow picks the matching icon automatically.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _IconPickerTile(
                  emoji: _emoji,
                  onPicked: (e) => setState(() {
                    _emoji = e;
                    _emojiLocked = true;
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      hintText: 'e.g. Avocado, Dragonfruit, Basmati Rice',
                    ),
                  ),
                ),
              ],
            ),
            if (_suggestion != null && _suggestion!.confidence > 0) ...[
              const SizedBox(height: 10),
              _SmartMatchBanner(suggestion: _suggestion!, locked: _emojiLocked),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [for (final c in kCategories) DropdownMenuItem(value: c.name, child: Text(c.name))],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: const [
                      DropdownMenuItem(value: 'kg', child: Text('kg')),
                      DropdownMenuItem(value: 'litre', child: Text('litre')),
                      DropdownMenuItem(value: 'dozen', child: Text('dozen')),
                      DropdownMenuItem(value: 'packet', child: Text('packet')),
                      DropdownMenuItem(value: 'piece', child: Text('piece')),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Opening quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _reorder,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Reorder level'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (widget.store.zoneNames.isEmpty)
              const Text('No zones yet — create one first from the Zones page.')
            else
              DropdownButtonFormField<String>(
                initialValue: widget.store.zoneNames.contains(_zone) ? _zone : widget.store.zoneNames.first,
                decoration: const InputDecoration(labelText: 'Zone', prefixIcon: Icon(Icons.shield_moon_outlined)),
                items: [for (final z in widget.store.zoneNames) DropdownMenuItem(value: z, child: Text(z))],
                onChanged: (v) => setState(() => _zone = v ?? _zone),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify customers'),
              subtitle: const Text('In-app + SMS + WhatsApp when item is added'),
              value: _notifyCustomers,
              onChanged: (v) => setState(() => _notifyCustomers = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final name = _name.text.trim();
                  final q = double.tryParse(_qty.text.trim()) ?? 0;
                  final r = double.tryParse(_reorder.text.trim()) ?? 0;
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an item name')));
                    return;
                  }
                  widget.store.addItem(
                    name: name,
                    emoji: _emoji,
                    category: _category,
                    unit: _unit,
                    qty: q,
                    reorder: r,
                    zone: _zone,
                    notifyCustomers: false,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added with $_emoji')));
                  if (_notifyCustomers && context.mounted) {
                    final result = await showNotifyCustomersSheet(
                      context,
                      title: 'New item available',
                      body: '$_emoji $name is now on the order list.',
                      itemEmoji: _emoji,
                    );
                    if (result != null && context.mounted) {
                      await showBroadcastDeliveryDialog(context, result);
                    }
                  }
                },
                child: const Text('Add to stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartMatchBanner extends StatelessWidget {
  final ItemVisualSuggestion suggestion;
  final bool locked;
  const _SmartMatchBanner({required this.suggestion, required this.locked});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.brandWash,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.brand, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked ? 'Icon chosen manually' : 'Auto-matched icon',
                  style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.brandDark),
                ),
                Text('${suggestion.emoji} · ${suggestion.category} · ${suggestion.sourceLabel}', style: t.bodySmall),
              ],
            ),
          ),
          Text(suggestion.emoji, style: const TextStyle(fontSize: 26)),
        ],
      ),
    );
  }
}

class _IconPickerTile extends StatelessWidget {
  final String emoji;
  final ValueChanged<String> onPicked;
  const _IconPickerTile({required this.emoji, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showEmojiPicker(context, current: emoji);
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.brandWash,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.4)),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
    );
  }
}
