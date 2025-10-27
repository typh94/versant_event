import 'package:flutter/foundation.dart';

// Model for sub-photo entries (refactor-only, no behavior change)
class SubPhotoEntry {
  String number;
  String description;
  String imagePath;

  SubPhotoEntry({
    required this.number,
    required this.description,
    required this.imagePath,
  });
}
