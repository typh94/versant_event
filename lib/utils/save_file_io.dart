import 'package:path_provider/path_provider.dart';
import 'package:versant_event/io_stubs.dart' if (dart.library.io) 'dart:io';

// Saves bytes to the app documents directory and returns the absolute file path.
// Accepts List<int> to be compatible with APIs that return List<int> instead of Uint8List.
Future<String> saveBytesAsFile(List<int> bytes, {required String filename}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
