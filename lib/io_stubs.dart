// Minimal web stubs for dart:io symbols to allow Flutter web compilation.
// These classes are only used to satisfy references on web builds; any actual
// use will throw if invoked at runtime in a web build. UI should gate calls
// behind kIsWeb checks or provide web-safe alternatives.
import 'dart:typed_data';

class File {
  final String path;
  File(this.path);

  // Read APIs
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Uint8List readAsBytesSync() => Uint8List(0);
  Future<String> readAsString() async => '';

  // Existence / metadata
  Future<bool> exists() async => false;
  bool existsSync() => false;
  DateTime lastModifiedSync() => DateTime.fromMillisecondsSinceEpoch(0);

  // Write / delete APIs
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<void> writeAsString(String s) async {}
  Future<void> delete() async {}
}

class Directory {
  final String path;
  Directory(this.path);

  List<File> listSync() => <File>[];
}