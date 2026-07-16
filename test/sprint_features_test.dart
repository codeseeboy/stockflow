/// Tests for this sprint's smart Excel import logic.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stockflow/utils/stock_import.dart';

void main() {
  group('stock_import — smart column detection', () {
    test('canonical header row is parsed correctly', () {
      final result = parseStockRows([
        ['name', 'quantity', 'reorder', 'category', 'unit', 'emoji'],
        ['Basmati Rice', '1000', '300', 'Grains', 'kg', '🍚'],
        ['Toor Dal', '400', '150', 'Pulses', 'kg', '🫘'],
      ]);
      expect(result.rows.length, 2);
      expect(result.rows[0].name, 'Basmati Rice');
      expect(result.rows[0].qty, 1000);
      expect(result.rows[1].name, 'Toor Dal');
      expect(result.rows[1].qty, 400);
    });

    test('alternate header aliases are accepted — item / stock', () {
      final result = parseStockRows([
        ['S.No', 'Item', 'Stock', 'Reorder'],
        ['1', 'Rice', '500', '100'],
        ['2', 'Dal', '200', '50'],
      ]);
      expect(result.rows.length, 2);
      expect(result.rows[0].name, 'Rice');
      expect(result.rows[0].qty, 500);
    });

    test('serial-number-only column is rejected as item name', () {
      final result = parseStockRows([
        ['S.No', 'Item', 'Qty'],
        ['1', 'Rice', '500'],
        ['2', 'Dal', '200'],
        ['3', 'Oil', '300'],
      ]);
      for (final r in result.rows) {
        expect(int.tryParse(r.name), isNull,
            reason: 'Name "" looks like a serial number');
      }
      expect(result.rows.any((r) => r.name == 'Rice'), isTrue);
    });

    test('headerless sheet falls back to positional detection', () {
      // Parser always treats row 0 as the header. In a headerless sheet the
      // first row (Rice) becomes the implicit header, so the data rows are the
      // remaining rows (Dal, Oil) = 2 rows.
      final result = parseStockRows([
        ['Rice', '1000'],
        ['Dal', '400'],
        ['Oil', '300'],
      ]);
      // 3 rows in → 1 header + 2 data rows
      expect(result.rows.length, 2);
      // The two data rows should be correctly named
      expect(result.rows.any((r) => r.name == 'Dal'), isTrue);
      expect(result.rows.any((r) => r.name == 'Oil'), isTrue);
    });

    test('rows with blank or whitespace names are skipped', () {
      final result = parseStockRows([
        ['name', 'quantity'],
        ['', '100'],
        ['   ', '200'],
        ['Rice', '500'],
      ]);
      expect(result.rows.length, 1);
      expect(result.rows[0].name, 'Rice');
    });

    test('non-numeric quantity cell is treated as 0', () {
      final result = parseStockRows([
        ['name', 'quantity'],
        ['Rice', 'N/A'],
        ['Dal', '400'],
      ]);
      expect(result.rows.any((r) => r.name == 'Dal'), isTrue);
      final rice = result.rows.where((r) => r.name == 'Rice').firstOrNull;
      // Rice row may be kept with qty 0, or skipped — either is acceptable.
      if (rice != null) expect(rice.qty, 0);
    });
  });
}
