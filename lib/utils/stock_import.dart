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

/// Parse a raw 2-D string table (list of rows, each a list of cell strings)
/// into stock rows.  Exposed for unit tests so tests don't need a real .xlsx
/// binary.
// ignore: unused_element
ImportResult parseStockRows(List<List<String>> table) => _parseTable(table);

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

bool _isNumeric(String s) => s.isNotEmpty && double.tryParse(s.replaceAll(RegExp(r'[,\s]'), '')) != null;

/// True when a column looks like a serial/№ column: header says so, or the
/// data is just the row count in order (1, 2, 3, …).
bool _looksLikeSerial(List<List<String>> table, int headerIndex, int col, List<String> headers) {
  final h = headers[col];
  if (h == 'ser' || h == 'sno' || h == 's.no' || h == 'sl' || h.contains('ser no') || h.contains('sr no') || h.contains('serial') || h == '#' || h == 'no' || h == 'no.') {
    return true;
  }
  var expected = 1;
  var matches = 0;
  var seen = 0;
  for (var i = headerIndex + 1; i < table.length && seen < 12; i++) {
    final v = col < table[i].length ? table[i][col].trim() : '';
    if (v.isEmpty) continue;
    seen++;
    if (int.tryParse(v) == expected) matches++;
    expected++;
  }
  return seen >= 3 && matches >= seen - 1;
}

ImportResult _parseTable(List<List<String>> table) {
  final warnings = <String>[];
  // Find the first non-empty row as the header.
  final headerIndex = table.indexWhere((r) => r.any((c) => c.trim().isNotEmpty));
  if (headerIndex < 0) {
    return const ImportResult([], ['The file looks empty.']);
  }
  final headers = table[headerIndex].map((h) => h.toLowerCase().trim()).toList();
  final colCount = headers.length;

  int? col(List<String> keys) {
    for (var i = 0; i < colCount; i++) {
      for (final k in keys) {
        if (headers[i] == k || headers[i].contains(k)) return i;
      }
    }
    return null;
  }

  // Column profile over the data rows: how texty / numeric each column is.
  // Used to find the name and quantity columns when headers don't say.
  final textScore = List<int>.filled(colCount, 0);
  final numScore = List<int>.filled(colCount, 0);
  for (var i = headerIndex + 1; i < table.length; i++) {
    for (var c = 0; c < colCount && c < table[i].length; c++) {
      final v = table[i][c].trim();
      if (v.isEmpty) continue;
      if (_isNumeric(v)) {
        numScore[c]++;
      } else {
        textScore[c]++;
      }
    }
  }

  var nameCol = col(['name', 'item', 'product', 'article', 'description', 'particular', 'commodity', 'nomenclature']);
  // Header didn't say → the most text-heavy column that isn't a serial column.
  if (nameCol == null || _looksLikeSerial(table, headerIndex, nameCol, headers)) {
    var best = -1;
    var bestScore = 0;
    for (var c = 0; c < colCount; c++) {
      if (_looksLikeSerial(table, headerIndex, c, headers)) continue;
      if (textScore[c] > bestScore) {
        best = c;
        bestScore = textScore[c];
      }
    }
    if (best >= 0) {
      nameCol = best;
      warnings.add('Item names read from the "${headers[best]}" column.');
    }
  }

  var qtyCol = col(['quantity', 'qty', 'opening', 'stock', 'balance', 'held', 'in hand']);
  // Header didn't say → the most numeric column that isn't serial or the name.
  if (qtyCol == null) {
    var best = -1;
    var bestScore = 0;
    for (var c = 0; c < colCount; c++) {
      if (c == nameCol || _looksLikeSerial(table, headerIndex, c, headers)) continue;
      if (numScore[c] > bestScore) {
        best = c;
        bestScore = numScore[c];
      }
    }
    if (best >= 0) {
      qtyCol = best;
      warnings.add('Quantities read from the "${headers[best]}" column.');
    } else {
      warnings.add('No quantity column found. Quantities default to 0 — check flagged rows before applying.');
    }
  }

  final ci = {
    'name': nameCol,
    'category': col(['category', 'cat', 'type', 'group']),
    'unit': col(['unit', 'uom', 'a/u']),
    'qty': qtyCol,
    'reorder': col(['reorder', 'min', 'threshold']),
    'emoji': col(['emoji', 'icon']),
  };

  String at(List<String> row, int? idx) =>
      (idx != null && idx >= 0 && idx < row.length) ? row[idx].trim() : '';

  final rows = <ImportRow>[];
  var skippedNumericNames = 0;
  for (var i = headerIndex + 1; i < table.length; i++) {
    final row = table[i];
    final name = ci['name'] != null ? at(row, ci['name']) : (row.isNotEmpty ? row.first.trim() : '');
    if (name.isEmpty) continue;
    // A bare number is never an item name — that's a serial or a stray total.
    if (_isNumeric(name)) {
      skippedNumericNames++;
      continue;
    }
    rows.add(ImportRow(
      name: name,
      emoji: at(row, ci['emoji']).isEmpty ? '📦' : at(row, ci['emoji']),
      category: _category(at(row, ci['category'])),
      unit: _unit(at(row, ci['unit'])),
      qty: _num(at(row, ci['qty'])),
      reorder: _num(at(row, ci['reorder'])),
    ));
  }

  if (skippedNumericNames > 0) {
    warnings.add('$skippedNumericNames row(s) had a number where the name should be — skipped. Check the sheet if that looks wrong.');
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
