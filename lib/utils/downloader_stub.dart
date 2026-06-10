import 'dart:typed_data';

/// Non-web fallback. On mobile we'll wire this to a share/save sheet later.
void downloadBytes(Uint8List bytes, String filename) {
  // No-op on non-web platforms for now.
}
