import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'picked_file.dart';

/// Opens the browser file chooser (.xlsx / .csv) and returns the bytes.
Future<PickedFile?> pickStockFile() async {
  final input = (web.document.createElement('input') as web.HTMLInputElement)
    ..type = 'file'
    ..accept = '.xlsx,.csv,.xls';

  final completer = Completer<PickedFile?>();

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final result = reader.result;
      if (result.isA<JSArrayBuffer>()) {
        final buffer = (result as JSArrayBuffer).toDart;
        completer.complete(PickedFile(file.name, buffer.asUint8List()));
      } else {
        completer.complete(null);
      }
    }.toJS;
    reader.onerror = ((web.Event _) {
      completer.complete(null);
    }).toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.click();
  return completer.future;
}
