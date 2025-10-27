// Minimal web stubs for dart:io symbols to allow Flutter web compilation.
// These classes are only used to satisfy references on web builds; any actual
// use will throw, but web code paths should avoid calling them.
import 'dart:typed_data';

class File {
  final String path;
  File(this.path);

  Future<Uint8List> readAsBytes() async => throw UnsupportedError('File.readAsBytes is not supported on web');
  Uint8List readAsBytesSync() => throw UnsupportedError('File.readAsBytesSync is not supported on web');
  Future<bool> exists() async => false;
  bool existsSync() => false;
  Future<void> writeAsBytes(List<int> bytes) async => throw UnsupportedError('File.writeAsBytes is not supported on web');
  Future<void> writeAsString(String s) async => throw UnsupportedError('File.writeAsString is not supported on web');
}

class Directory {
  final String path;
  Directory(this.path);

  List<dynamic> listSync() => <dynamic>[];
}