// Minimal web stubs for dart:io symbols to allow Flutter web compilation.
// These classes are only used to satisfy references on web builds; any actual
// use will be no-ops or return benign defaults. UI should gate IO calls behind
// kIsWeb checks or provide web-safe alternatives.
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

  // Write / delete APIs (signatures mimic dart:io where referenced)
  Future<void> writeAsBytes(List<int> bytes, {bool flush = false}) async {}
  Future<void> writeAsString(String s) async {}
  Future<void> delete() async {}

  // File operations used by app code
  Future<File> copy(String newPath) async => File(newPath);
}

class Directory {
  final String path;
  Directory(this.path);

  // Existence / creation APIs used by app code
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<Directory> create({bool recursive = false}) async => this;

  // Listing (rarely used on web paths; return empty)
  List<File> listSync() => <File>[];
}