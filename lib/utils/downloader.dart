// Triggers a file download of `bytes` named `filename`.
// Uses the browser on web; a no-op stub elsewhere (mobile will use the
// `printing` share sheet once we build for Android).
export 'downloader_stub.dart' if (dart.library.js_interop) 'downloader_web.dart';
