import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// Extracted from main.dart (refactor-only, no behavior change)
class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function(PdfPageFormat) pdfBuilder;
  const PdfPreviewScreen({super.key, required this.pdfBuilder});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu PDF')),
      body: PdfPreview(
        build: pdfBuilder,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: 'rapport_preview.pdf',
      ),
    );
  }
}
