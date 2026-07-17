import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/downloader.dart';
import '../../utils/file_picker.dart';
import '../../utils/stock_import.dart';
import '../../widgets/ui_kit.dart';

class ImportStockScreen extends StatefulWidget {
  const ImportStockScreen({super.key});

  @override
  State<ImportStockScreen> createState() => _ImportStockScreenState();
}

class _ImportStockScreenState extends State<ImportStockScreen> {
  String? _fileName;
  List<ImportRow> _rows = const [];
  List<String> _warnings = const [];
  bool _addToExisting = true;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final file = await pickStockFile();
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final result = parseStockFile(file.name, file.bytes);
      setState(() {
        _fileName = file.name;
        _rows = result.rows;
        _warnings = result.warnings;
        _busy = false;
      });
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not read file: $e')));
      }
    }
  }

  void _downloadTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Stock'];
    excel.setDefaultSheet('Stock');
    // Drop the auto-created blank sheet so only 'Stock' remains.
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('name'),
      TextCellValue('quantity'),
      TextCellValue('reorder'),
      TextCellValue('category'),
      TextCellValue('unit'),
      TextCellValue('emoji'),
    ]);
    const samples = <List<Object>>[
      ['Basmati Rice', 1000, 300, 'Grains', 'kg', '🍚'],
      ['Toor Dal', 400, 150, 'Pulses', 'kg', '🫘'],
      ['Onion', 500, 150, 'Vegetables', 'kg', '🧅'],
      ['Milk', 400, 110, 'Dairy', 'litre', '🥛'],
      ['Cooking Oil', 300, 80, 'Essentials', 'litre', '🛢️'],
    ];
    for (final r in samples) {
      sheet.appendRow([
        TextCellValue(r[0] as String),
        IntCellValue(r[1] as int),
        IntCellValue(r[2] as int),
        TextCellValue(r[3] as String),
        TextCellValue(r[4] as String),
        TextCellValue(r[5] as String),
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      downloadBytes(Uint8List.fromList(bytes), 'stockflow_template.xlsx');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel template downloaded — just fill the quantity column')),
    );
  }

  void _apply() {
    if (_rows.isEmpty) return;
    final summary = context.read<AppStore>().importStock(_rows, addToExisting: _addToExisting);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Import done. ${summary.added} new, ${summary.updated} updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Import master stock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Upload your stock sheet',
                  subtitle: 'Download the Excel template, just fill the quantity column, upload it back',
                  info: 'Only name + quantity are required. Leave category, unit and emoji blank and '
                      'the app fills them in for you. Extra columns are ignored; column order doesn\'t matter.',
                  action: OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Excel template'),
                  ),
                ),
                const SizedBox(height: 18),
                _UploadZone(fileName: _fileName, busy: _busy, onPick: _pick),
                const SizedBox(height: 18),
                _ModeSelector(
                  addToExisting: _addToExisting,
                  onChanged: (v) => setState(() => _addToExisting = v),
                ),
                if (_warnings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(child: Text(w, style: t.bodySmall?.copyWith(color: AppColors.warning))),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 18),
                if (_fileName == null)
                  _Placeholder()
                else if (_rows.isEmpty)
                  const EmptyState(icon: Icons.error_outline_rounded, title: 'No rows found', subtitle: 'Check the file has a header row and data below it.')
                else
                  _Preview(rows: _rows),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _rows.isEmpty ? null : _apply,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_rows.isEmpty
                        ? 'Apply import'
                        : 'Apply ${_rows.length} item${_rows.length == 1 ? '' : 's'} (${_addToExisting ? 'add to existing' : 'replace'})'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  final String? fileName;
  final bool busy;
  final VoidCallback onPick;
  const _UploadZone({required this.fileName, required this.busy, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final has = fileName != null;
    return InkWell(
      onTap: busy ? null : onPick,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: has ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: has ? AppColors.brand : scheme.outline, width: 1.4),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: (has ? AppColors.brand : scheme.onSurfaceVariant).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: busy
                  ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(has ? Icons.description_rounded : Icons.cloud_upload_rounded, color: has ? AppColors.brand : scheme.onSurfaceVariant, size: 28),
            ),
            const SizedBox(height: 14),
            Text(has ? fileName! : 'Choose a file to upload', style: t.titleMedium?.copyWith(color: has ? scheme.onPrimaryContainer : null)),
            const SizedBox(height: 4),
            Text(has ? 'Tap to choose a different file' : '.xlsx or .csv', style: t.bodySmall?.copyWith(color: has ? scheme.onPrimaryContainer : null)),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final bool addToExisting;
  final ValueChanged<bool> onChanged;
  const _ModeSelector({required this.addToExisting, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('How should this apply?', style: t.titleSmall),
              const SizedBox(width: 6),
              const InfoTip('Add: existing items get topped up (good for mid-week deliveries). '
                  'Replace: existing items are reset to the new quantity.'),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.add_rounded, size: 18), label: Text('Add to existing')),
              ButtonSegment(value: false, icon: Icon(Icons.swap_horiz_rounded, size: 18), label: Text('Replace')),
            ],
            selected: {addToExisting},
            onSelectionChanged: (s) => onChanged(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.standard,
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What appears here', style: t.titleSmall),
          const SizedBox(height: 4),
          Text('After you upload, a preview of your items will show here so you can review before applying.', style: t.bodySmall),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ColChip('name', true),
              _ColChip('category', false),
              _ColChip('unit', false),
              _ColChip('quantity', true),
              _ColChip('reorder', false),
              _ColChip('emoji', false),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('= required', style: t.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColChip extends StatelessWidget {
  final String label;
  final bool required;
  const _ColChip(this.label, this.required);
  @override
  Widget build(BuildContext context) {
    final c = required ? AppColors.brand : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }
}

class _Preview extends StatelessWidget {
  final List<ImportRow> rows;
  const _Preview({required this.rows});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Text('Review before applying', style: t.titleMedium),
                const SizedBox(width: 8),
                Pill('${rows.length} items', color: AppColors.brand),
                if (rows.any((r) => r.qty <= 0)) ...[
                  const SizedBox(width: 8),
                  Pill('${rows.where((r) => r.qty <= 0).length} missing qty', color: AppColors.warning, icon: Icons.warning_amber_rounded),
                ],
              ],
            ),
          ),
          Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('ITEM', style: t.labelMedium)),
                Expanded(flex: 3, child: Text('CATEGORY', style: t.labelMedium)),
                Expanded(flex: 2, child: Text('QTY', style: t.labelMedium, textAlign: TextAlign.end)),
                Expanded(flex: 2, child: Text('REORDER', style: t.labelMedium, textAlign: TextAlign.end)),
              ],
            ),
          ),
          ...rows.take(50).map((r) {
            final cat = categoryOf(r.category);
            final flagged = r.qty <= 0;
            return Container(
              color: flagged ? AppColors.warningWash : null,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(children: [
                      if (flagged) ...[
                        const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.warning),
                        const SizedBox(width: 6),
                      ],
                      Text(r.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.name, style: t.titleSmall, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      Icon(cat.icon, size: 13, color: cat.color),
                      const SizedBox(width: 4),
                      Flexible(child: Text(r.category, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      flagged ? 'no qty' : '${fmtNum(r.qty)} ${r.unit}',
                      style: t.bodySmall?.copyWith(color: flagged ? AppColors.warning : null, fontWeight: flagged ? FontWeight.w700 : null),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(flex: 2, child: Text(fmtNum(r.reorder), style: t.bodySmall, textAlign: TextAlign.end)),
                ],
              ),
            );
          }),
          if (rows.length > 50)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('+ ${rows.length - 50} more…', style: t.bodySmall),
            ),
        ],
      ),
    );
  }
}
