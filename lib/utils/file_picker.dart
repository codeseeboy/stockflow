// Opens a file chooser and returns the picked file's bytes.
// Web → HTML <input type=file>; other platforms → null (import is web-only).
export 'file_picker_stub.dart' if (dart.library.js_interop) 'file_picker_web.dart';
