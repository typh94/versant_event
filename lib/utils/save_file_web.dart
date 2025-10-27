import 'dart:typed_data';
import 'dart:html' as html;

// Triggers a browser download for the given bytes. Returns a pseudo-path token.
Future<String> saveBytesAsFile(Uint8List bytes, {required String filename}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return 'download:$filename';
}
