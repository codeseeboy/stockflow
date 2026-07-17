import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_store.dart';
import '../models/models.dart';

final _brand = PdfColor.fromInt(0xFF12936A);
final _ink = PdfColor.fromInt(0xFF12201C);
final _muted = PdfColor.fromInt(0xFF5E6F69);
final _line = PdfColor.fromInt(0xFFD9E2DE);

String _statusText(StockStatus s) => switch (s) {
      StockStatus.inStock => 'In stock',
      StockStatus.low => 'Low',
      StockStatus.out => 'Out',
    };

String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

pw.Widget _header(String title, String subtitle) {
  final now = DateFormat('d MMM yyyy, h:mm a').format(DateTime.now());
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('StockFlow', style: pw.TextStyle(color: _brand, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Inventory & ordering', style: pw.TextStyle(color: _muted, fontSize: 9)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(title, style: pw.TextStyle(color: _ink, fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated $now', style: pw.TextStyle(color: _muted, fontSize: 9)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Divider(color: _line, thickness: 1),
      pw.SizedBox(height: 2),
      pw.Text(subtitle, style: pw.TextStyle(color: _muted, fontSize: 10)),
      pw.SizedBox(height: 12),
    ],
  );
}

pw.Widget _summaryChips(List<List<String>> pairs) {
  return pw.Row(
    children: [
      for (final p in pairs)
        pw.Container(
          margin: const pw.EdgeInsets.only(right: 10),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEFF3F1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(p[0], style: pw.TextStyle(color: _ink, fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text(p[1], style: pw.TextStyle(color: _muted, fontSize: 9)),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _table(List<String> headers, List<List<String>> rows) {
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    border: pw.TableBorder.symmetric(inside: pw.BorderSide(color: _line, width: 0.5)),
    headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 9.5, fontWeight: pw.FontWeight.bold),
    headerDecoration: pw.BoxDecoration(color: _brand),
    cellStyle: pw.TextStyle(color: _ink, fontSize: 9.5),
    cellHeight: 22,
    oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6F8F7)),
    cellAlignments: {0: pw.Alignment.centerLeft},
  );
}

pw.Document _doc(pw.Widget Function() header, List<pw.Widget> body) {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [header(), ...body],
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(color: _muted, fontSize: 8)),
      ),
    ),
  );
  return doc;
}

Future<Uint8List> buildStockReport(AppStore store) {
  final items = [...store.items]..sort((a, b) => a.category.compareTo(b.category));
  final doc = _doc(
    () => _header('Stock Report', 'Current master stock across all categories'),
    [
      _summaryChips([
        ['${store.totalItems}', 'Total items'],
        ['${store.lowCount}', 'Running low'],
        ['${store.outCount}', 'Out of stock'],
      ]),
      pw.SizedBox(height: 16),
      _table(
        ['Item', 'Category', 'Unit', 'Current', 'Opening', 'Reorder', 'Status'],
        [
          for (final i in items)
            [i.name, i.category, i.unit, _n(i.currentQty), _n(i.openingQty), _n(i.reorderLevel), _statusText(i.status)],
        ],
      ),
    ],
  );
  return doc.save();
}

Future<Uint8List> buildLowStockReport(AppStore store) {
  final items = [...store.outOfStockItems, ...store.lowStockItems];
  final doc = _doc(
    () => _header('Low-stock / Reorder Report', 'Items at or below their reorder level, action needed'),
    [
      _summaryChips([
        ['${store.outCount}', 'Out of stock'],
        ['${store.lowCount}', 'Running low'],
      ]),
      pw.SizedBox(height: 16),
      if (items.isEmpty)
        pw.Text('All items are above their reorder level.', style: pw.TextStyle(color: _muted))
      else
        _table(
          ['Item', 'Category', 'Left', 'Reorder at', 'Est. days left', 'Status'],
          [
            for (final i in items)
              [
                i.name,
                i.category,
                '${_n(i.currentQty)} ${i.unit}',
                _n(i.reorderLevel),
                i.status == StockStatus.out ? '0' : (store.daysLeft(i)?.toString() ?? 'n/a'),
                _statusText(i.status),
              ],
          ],
        ),
    ],
  );
  return doc.save();
}

Future<Uint8List> buildOrdersReport(AppStore store) {
  final orders = store.orders;
  final df = DateFormat('d MMM, h:mm a');
  final byStatus = <OrderStatus, int>{};
  for (final o in orders) {
    byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
  }
  final doc = _doc(
    () => _header('Orders Report', 'All customer orders with status and contents'),
    [
      _summaryChips([
        ['${orders.length}', 'Total orders'],
        ['${byStatus[OrderStatus.pending] ?? 0}', 'Pending'],
        ['${byStatus[OrderStatus.fulfilled] ?? 0}', 'Fulfilled'],
      ]),
      pw.SizedBox(height: 16),
      _table(
        ['Order', 'Customer', 'Items', 'Status', 'Placed'],
        [
          for (final o in orders)
            [
              o.id,
              o.customerName,
              o.lines.map((l) => '${l.name} (${_n(l.qty)} ${l.unit})').join(', '),
              switch (o.status) {
                OrderStatus.pending => 'Pending',
                OrderStatus.viewed => 'Viewed',
                OrderStatus.accepted => 'Accepted',
                OrderStatus.rejected => 'Rejected',
                OrderStatus.processing => 'Processing',
                OrderStatus.fulfilled => 'Fulfilled',
                OrderStatus.cancelled => 'Cancelled',
              },
              df.format(o.createdAt),
            ],
        ],
      ),
    ],
  );
  return doc.save();
}
