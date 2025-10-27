// Platform-aware image widget using conditional exports.
// On IO platforms, shows an image from a file path.
// On Web, shows a simple placeholder (no direct file access).

export 'io_image_io.dart' if (dart.library.html) 'io_image_web.dart';
