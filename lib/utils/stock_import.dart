import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/models.dart';

/// One parsed stock line from an uploaded file.
class ImportRow {
  final String name;
  final String emoji;
  final String category;
  final String unit;
  final double qty;
  final double reorder;
  const ImportRow({
    required this.name,
    required this.emoji,
    required this.category,
    required this.unit,
    required this.qty,
    required this.reorder,
  });
}

class ImportResult {
  final List<ImportRow> rows;
  final List<String> warnings;
  const ImportResult(this.rows, this.warnings);
}

/// Outcome of applying an import.
class ImportSummary {
  final int added;
  final int updated;
  const ImportSummary({required this.added, required this.updated});
}

/// Parse an uploaded .xlsx / .csv into stock rows.
ImportResult parseStockFile(String filename, Uint8List bytes) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.csv')) {
    return _parseTable(_csvToTable(utf8.decode(bytes, allowMalformed: true)));
  }
  try {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const ImportResult([], ['No sheets found in the file.']);
    }
    final sheet = excel.tables.values.first;
    final table = <List<String>>[];
    for (final row in sheet.rows) {
      table.add([for (final cell in row) _cell(cell)]);
    }
    return _parseTable(table);
  } catch (_) {
    return const ImportResult([], ['Could not read this Excel file. Save it as .csv and try again.']);
  }
}

String _cell(Data? d) {
  final v = d?.value;
  if (v == null) return '';
  if (v is TextCellValue) return v.value.toString().trim();
  if (v is IntCellValue) return v.value.toString();
  if (v is DoubleCellValue) return v.value.toString();
  return v.toString().trim();
}

List<List<String>> _csvToTable(String text) {
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  return [
    for (final line in lines)
      if (line.trim().isNotEmpty) line.split(',').map((c) => c.trim()).toList(),
  ];
}

ImportResult _parseTable(List<List<String>> table) {
  final warnings = <String>[];
  // Find the first non-empty row as the header.
  final headerIndex = table.indexWhere((r) => r.any((c) => c.trim().isNotEmpty));
  if (headerIndex < 0) {
    return const ImportResult([], ['The file looks empty.']);
  }
  final headers = table[headerIndex].map((h) => h.toLowerCase().trim()).toList();

  int? col(List<String> keys) {
    for (var i = 0; i < headers.length; i++) {
      for (final k in keys) {
        if (headers[i] == k || headers[i].contains(k)) return i;
      }
    }
    return null;
  }

  final ci = {
    'name': col(['name', 'item', 'product']),
    'category': col(['category', 'cat', 'type']),
    'unit': col(['unit', 'uom']),
    'qty': col(['quantity', 'qty', 'opening', 'stock']),
    'reorder': col(['reorder', 'min', 'threshold']),
    'emoji': col(['emoji', 'icon']),
  };

  if (ci['name'] == null) {
    warnings.add('No "name" column found. The first column will be used as the item name.');
  }
  if (ci['qty'] == null) {
    warnings.add('No "quantity" column found. Quantities default to 0.');
  }

  String at(List<String> row, int? idx) =>
      (idx != null && idx >= 0 && idx < row.length) ? row[idx].trim() : '';

  final rows = <ImportRow>[];
  for (var i = headerIndex + 1; i < table.length; i++) {
    final row = table[i];
    final name = ci['name'] != null ? at(row, ci['name']) : (row.isNotEmpty ? row.first.trim() : '');
    if (name.isEmpty) continue;
    rows.add(ImportRow(
      name: name,
      emoji: at(row, ci['emoji']).isEmpty ? '📦' : at(row, ci['emoji']),
      category: _category(at(row, ci['category'])),
      unit: _unit(at(row, ci['unit'])),
      qty: _num(at(row, ci['qty'])),
      reorder: _num(at(row, ci['reorder'])),
    ));
  }

  if (rows.isEmpty) warnings.add('No data rows found below the header.');
  return ImportResult(rows, warnings);
}

double _num(String s) {
  if (s.isEmpty) return 0;
  final cleaned = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

String _unit(String s) {
  final t = s.trim().toLowerCase();
  const known = {'kg', 'litre', 'liter', 'l', 'dozen', 'packet', 'piece', 'pcs', 'g', 'ml'};
  if (t.isEmpty) return 'kg';
  if (t == 'liter' || t == 'l') return 'litre';
  if (t == 'pcs') return 'piece';
  return known.contains(t) ? (t == 'liter' ? 'litre' : t) : s.trim();
}

String _category(String s) {
  final t = s.trim().toLowerCase();
  if (t.isEmpty) return 'Essentials';
  for (final c in kCategories) {
    if (c.name.toLowerCase() == t) return c.name;
  }
  for (final c in kCategories) {
    if (c.name.toLowerCase().startsWith(t) || t.startsWith(c.name.toLowerCase())) return c.name;
  }
  return 'Essentials';
}
