import 'dart:typed_data';

/// Web implementation of platform-specific archiving tasks (stubs).
class ArchivePlatform {
  static Future<Uint8List?> readLocalFile(String path) async {
    // Local file IO is not supported on web.
    return null;
  }
}
