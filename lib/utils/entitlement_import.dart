import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/models.dart';

/// One parsed entitlement line from the unit's Excel — a category and the
/// entitlement per person per day for it.
class EntitlementRow {
  final String category; // matched RIK category ('' when unmatched)
  final String rawCategory; // exactly what the sheet said
  final double perDay;
  const EntitlementRow({required this.category, required this.rawCategory, required this.perDay});
}

class EntitlementImportResult {
  final List<EntitlementRow> rows;
  final List<String> warnings;
  const EntitlementImportResult(this.rows, this.warnings);

  /// Rows that matched a RIK category and can be applied.
  List<EntitlementRow> get valid => rows.where((r) => r.category.isNotEmpty).toList();
}

class EntitlementImportSummary {
  final int updated;
  final int skipped;
  const EntitlementImportSummary({required this.updated, required this.skipped});
}

/// Parse an entitlement sheet (.xlsx / .csv) into per-day rates by category.
///
/// The sheet the unit shares gives the entitlement per person. It may state it
/// per day, or for a period ("per 10 days", "monthly", a `days` column) — in
/// which case we divide back down to a per-day rate, because every allowance in
/// the app is `perDay × days`.
EntitlementImportResult parseEntitlementFile(String filename, Uint8List bytes) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.csv')) {
    return _parse(_csvToTable(utf8.decode(bytes, allowMalformed: true)));
  }
  try {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const EntitlementImportResult([], ['No sheets found in the file.']);
    }
    final sheet = excel.tables.values.first;
    final table = <List<String>>[];
    for (final row in sheet.rows) {
      table.add([for (final cell in row) _cell(cell)]);
    }
    return _parse(table);
  } catch (_) {
    return const EntitlementImportResult(
      [],
      ['Could not read this Excel file. Save it as .csv and try again.'],
    );
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

EntitlementImportResult _parse(List<List<String>> table) {
  final warnings = <String>[];
  final headerIndex = table.indexWhere((r) => r.any((c) => c.trim().isNotEmpty));
  if (headerIndex < 0) {
    return const EntitlementImportResult([], ['The file looks empty.']);
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

  final catCol = col(['category', 'item', 'article', 'commodity', 'head']);
  final perDayCol = col(['per day', 'perday', 'per-day', 'daily', 'scale', 'entitlement', 'qty', 'quantity']);
  final daysCol = col(['days', 'period', 'no of days']);

  if (catCol == null) {
    warnings.add('No "category" column found — the first column will be used.');
  }
  if (perDayCol == null) {
    warnings.add('No entitlement column found. Expected a column like "per day", "scale" or "entitlement".');
    return EntitlementImportResult(const [], warnings);
  }

  String at(List<String> row, int? idx) =>
      (idx != null && idx >= 0 && idx < row.length) ? row[idx].trim() : '';

  final rows = <EntitlementRow>[];
  for (var i = headerIndex + 1; i < table.length; i++) {
    final row = table[i];
    final raw = catCol != null ? at(row, catCol) : (row.isNotEmpty ? row.first.trim() : '');
    if (raw.isEmpty) continue;

    final value = _num(at(row, perDayCol));
    if (value <= 0) {
      // Never drop a row silently — the admin must know what didn't import.
      warnings.add('"$raw" has no usable entitlement value — check this row.');
      continue;
    }

    // If the sheet states the entitlement over a period, bring it back to a
    // per-day rate — everything downstream is perDay × days.
    final days = _num(at(row, daysCol));
    final perDay = days > 0 ? value / days : value;

    final matched = matchRikCategory(raw);
    if (matched == null) {
      warnings.add('"$raw" doesn\'t match a RIK category — skipped.');
    }
    rows.add(EntitlementRow(category: matched ?? '', rawCategory: raw, perDay: perDay));
  }

  if (rows.isEmpty) warnings.add('No entitlement rows found below the header.');
  return EntitlementImportResult(rows, warnings);
}

double _num(String s) {
  if (s.isEmpty) return 0;
  final cleaned = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}
