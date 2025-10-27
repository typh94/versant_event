class Email {
  final String body;
  final String subject;
  final List<String> recipients;
  final List<String>? cc;
  final List<String>? bcc;
  final List<String>? attachmentPaths;
  final bool isHTML;

  Email({
    required this.body,
    required this.subject,
    this.recipients = const [],
    this.cc,
    this.bcc,
    this.attachmentPaths,
    this.isHTML = false,
  });
}

class FlutterEmailSender {
  static Future<void> send(Email email) async {
    // No-op on web
    throw UnsupportedError('flutter_email_sender is not supported on web');
  }
}