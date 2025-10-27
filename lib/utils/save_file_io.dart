import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:versant_event/io_stubs.dart' if (dart.library.io) 'dart:io';

// Saves bytes to the app documents directory and returns the absolute file path.
Future<String> saveBytesAsFile(Uint8List bytes, {required String filename}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
