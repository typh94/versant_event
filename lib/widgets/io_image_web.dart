import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
// Only available on web; safe to import here
import 'dart:html' as html;

class IoImage extends StatefulWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const IoImage({super.key, required this.path, this.width, this.height, this.fit});

  @override
  State<IoImage> createState() => _IoImageState();
}

class _IoImageState extends State<IoImage> {
  Uint8List? _bytes; // persistent bytes to avoid blob: URL expiry
  bool _triedResolve = false;

  bool get _isHttpUrl {
    final p = widget.path.trim();
    return p.startsWith('http://') || p.startsWith('https://');
  }

  bool get _isDataUrl => widget.path.trim().startsWith('data:image');
  bool get _isBlobUrl => widget.path.trim().startsWith('blob:');

  @override
  void initState() {
    super.initState();
    _maybeResolveToBytes();
  }

  @override
  void didUpdateWidget(covariant IoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = null;
      _triedResolve = false;
      _maybeResolveToBytes();
    }
  }

  Future<void> _maybeResolveToBytes() async {
    if (_triedResolve) return;
    _triedResolve = true;
    final p = widget.path.trim();

    try {
      if (_isDataUrl) {
        final uriData = UriData.parse(p);
        final bytes = uriData.contentAsBytes();
        if (mounted) setState(() => _bytes = Uint8List.fromList(bytes));
        return;
      }
      if (_isBlobUrl) {
        // Fetch the blob then read as bytes to avoid later URL revocation
        final resp = await html.HttpRequest.request(p, responseType: 'blob');
        final blob = resp.response as html.Blob?;
        if (blob != null) {
          final reader = html.FileReader();
          final completer = Completer<Uint8List>();
          reader.onLoadEnd.listen((_) {
            try {
              final result = reader.result; // data URL string
              if (result is String) {
                final uriData = UriData.parse(result);
                completer.complete(Uint8List.fromList(uriData.contentAsBytes()));
              } else {
                completer.complete(Uint8List(0));
              }
            } catch (_) {
              completer.complete(Uint8List(0));
            }
          });
          reader.readAsDataUrl(blob);
          final bytes = await completer.future;
          if (bytes.isNotEmpty && mounted) setState(() => _bytes = bytes);
          return;
        }
      }
    } catch (_) {
      // Silent: fall back to network/placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have persistent bytes, use them
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    }

    // For normal http/https images, use network directly
    if (_isHttpUrl || _isDataUrl || _isBlobUrl) {
      return Image.network(
        widget.path,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported),
    );
  }
}
