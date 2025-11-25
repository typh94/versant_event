import 'package:flutter/material.dart';

class IoImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const IoImage({super.key, required this.path, this.width, this.height, this.fit});

  bool get _isDisplayableUrl {
    final p = path.trim();
    return p.startsWith('blob:') || p.startsWith('data:image') || p.startsWith('http://') || p.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisplayableUrl) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stack) {
          return _placeholder();
        },
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported),
    );
  }
}
