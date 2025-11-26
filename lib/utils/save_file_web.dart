import 'dart:typed_data';
import 'dart:html' as html;

// Triggers a browser download for the given bytes. Returns a pseudo-path token.
// Accepts List<int> and converts to Uint8List for Blob.
Future<String> saveBytesAsFile(List<int> bytes, {required String filename}) async {
  final u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  // Infer a content type from filename to help browsers recognize the file
  String contentType = 'application/octet-stream';
  final lower = filename.toLowerCase();
  if (lower.endsWith('.pdf')) contentType = 'application/pdf';
  if (lower.endsWith('.docx')) contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  final blob = html.Blob([u8], contentType);
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
