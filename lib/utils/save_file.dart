// Cross-platform helper to save bytes as a file.
// On IO platforms, writes to application documents directory and returns the file path.
// On Web, triggers a browser download and returns a pseudo path token.

export 'save_file_io.dart' if (dart.library.html) 'save_file_web.dart';
