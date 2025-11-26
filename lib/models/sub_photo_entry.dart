import 'dart:typed_data';

// Model for sub-photo entries (web-safe image support)
class SubPhotoEntry {
  String number;
  String description;
  String imagePath;
  Uint8List? imageBytes; // Optional in-memory image (used on web)

  SubPhotoEntry({
    required this.number,
    required this.description,
    required this.imagePath,
    this.imageBytes,
  });
}
