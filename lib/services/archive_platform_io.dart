import 'dart:typed_data';
import 'dart:io';

/// IO implementation of platform-specific archiving tasks.
class ArchivePlatform {
  static Future<Uint8List?> readLocalFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}
