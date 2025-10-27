// Web stub for path_provider to avoid MissingPluginException on web.
// This file is used only on web builds via conditional imports.
// Do not use these methods at runtime on web; guard calls with kIsWeb checks.

import 'package:versant_event/io_stubs.dart';

Future<Directory> getApplicationDocumentsDirectory() async {
  // On web, return a benign stub directory to avoid MissingPluginException.
  // Code paths should still avoid using the path for real IO on web.
  return Directory('/');
}
