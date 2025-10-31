// This file is only used on IO platforms via widgets/io_image.dart conditional export.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'dart:io' as io;

class IoImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const IoImage({super.key, required this.path, this.width, this.height, this.fit});

  @override
  Widget build(BuildContext context) {
    final io.File file = io.File(path);
    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: Colors.redAccent),
        );
      },
    );
  }
}
