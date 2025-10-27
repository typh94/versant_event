class OpenFilex {
  static Future<dynamic> open(String path) async {
    // No-op on web
    return {'type': 'unsupported', 'message': 'OpenFilex is not supported on web'};
  }
}