import 'package:flutter/material.dart';

import '../data/grocery_icon_catalog.dart';
import '../theme/app_theme.dart';

/// Opens the icon chooser and returns the picked emoji (or null if dismissed).
Future<String?> showEmojiPicker(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EmojiPickerSheet(current: current),
  );
}

class _EmojiPickerSheet extends StatefulWidget {
  final String? current;
  const _EmojiPickerSheet({this.current});

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  String _query = '';

  List<MapEntry<String, List<List<String>>>> get _filtered {
    if (_query.trim().isEmpty) return kGroceryIconSections.entries.toList();
    final q = _query.toLowerCase().trim();
    final out = <MapEntry<String, List<List<String>>>>[];
    for (final s in kGroceryIconSections.entries) {
      final matches = s.value.where((e) => e[1].contains(q) || e[0] == q).toList();
      if (matches.isNotEmpty) out.add(MapEntry(s.key, matches));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sections = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_emotions_rounded, color: AppColors.brand),
                const SizedBox(width: 8),
                Text('Choose an icon', style: t.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search (rice, milk, onion…)',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sections.isEmpty
                  ? Center(child: Text('No icons match "$_query"', style: t.bodyMedium))
                  : ListView(
                      controller: controller,
                      children: [
                        for (final s in sections) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8),
                            child: Text(s.key.toUpperCase(),
                                style: t.labelMedium?.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w700)),
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final e in s.value)
                                _EmojiCell(
                                  emoji: e[0],
                                  selected: e[0] == widget.current,
                                  onTap: () => Navigator.pop(context, e[0]),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _EmojiCell({required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.brandWash : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: selected ? AppColors.brand : Colors.transparent, width: 1.6),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
