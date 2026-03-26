import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:intl/intl.dart';
import 'archive_platform_web.dart'
    if (dart.library.io) 'archive_platform_io.dart';
import 'auth_service.dart';

/// Minimal service to archive photos to Firebase Storage
/// and log a document in a separate Firestore collection.
///
/// This is fire-and-forget: errors are caught and printed,
/// to avoid impacting existing UI/flows.
class PhotoArchiveService {
  static final _storage = firebase_storage.FirebaseStorage.instance;
  static final _firestore = FirebaseFirestore.instance;

  /// Archives raw bytes (use on web or when bytes are available)
  static Future<String?> archiveBytes(Uint8List bytes, {
    String filename = 'photo.jpg',
    String? description,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final username = await AuthService.currentUsername();
      final now = DateTime.now();
      final path = _buildStoragePath(now, filename);
      final contentType = _guessContentType(filename);

      final ref = _storage.ref().child(path);
      await ref.putData(bytes, firebase_storage.SettableMetadata(contentType: contentType));
      final downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('photos_archive').add({
        'storagePath': path,
        'downloadUrl': downloadUrl,
        'description': description,
        'username': username,
        'platform': kIsWeb ? 'web' : 'io',
        'createdAt': FieldValue.serverTimestamp(),
        ...?extra,
      });
      return downloadUrl;
    } catch (e) {
      // Log but do not throw
      // ignore: avoid_print
      print('PhotoArchiveService.archiveBytes error: $e');
      return null;
    }
  }

  /// Archives a local file path (IO platforms)
  static Future<String?> archiveFile(String filePath, {
    String? description,
    Map<String, dynamic>? extra,
  }) async {
    try {
      if (kIsWeb) return null; // not applicable
      
      // On IO platforms, read the file as bytes using platform helper then archive.
      final bytes = await ArchivePlatform.readLocalFile(filePath);
      if (bytes == null) return null;

      final filename = filePath.split('/').last;
      
      return await archiveBytes(
        bytes,
        filename: filename,
        description: description,
        extra: extra,
      );
    } catch (e) {
      // ignore: avoid_print
      print('PhotoArchiveService.archiveFile error: $e');
      return null;
    }
  }

  static String _buildStoragePath(DateTime now, String filename) {
    final yyyy = DateFormat('yyyy').format(now);
    final mm = DateFormat('MM').format(now);
    final dd = DateFormat('dd').format(now);
    final ts = now.millisecondsSinceEpoch;
    final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return 'photos_archive/$yyyy/$mm/$dd/${ts}_$safe';
  }

  static String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
