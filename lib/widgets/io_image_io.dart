import 'package:flutter/material.dart';
import 'package:versant_event/io_stubs.dart' if (dart.library.io) 'dart:io';

class IoImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const IoImage({super.key, required this.path, this.width, this.height, this.fit});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
    );
  }
}
