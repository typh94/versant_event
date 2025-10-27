import 'package:flutter/material.dart';

class IoImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const IoImage({super.key, required this.path, this.width, this.height, this.fit});

  @override
  Widget build(BuildContext context) {
    // On web we cannot read arbitrary device file paths. Show a placeholder box.
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported),
    );
  }
}
