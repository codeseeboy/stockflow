import 'dart:typed_data';

/// A file chosen by the user (name + raw bytes).
class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
}
