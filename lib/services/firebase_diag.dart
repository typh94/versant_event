import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// FirebaseDiag prints useful runtime diagnostics so you can tell whether
/// the app is actually connected to your Firebase project and able to
/// talk to Firestore.
class FirebaseDiag {
  /// Call after Firebase.initializeApp(). Safe to call multiple times.
  static Future<void> debugStatus() async {
    try {
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        print('🟡 FirebaseDiag: Firebase is NOT initialized.');
        return;
      }

      final app = Firebase.app();
      final options = app.options;
      print('================ Firebase Diagnostics ================');
      print('App name: ${app.name}');
      print('Project ID: ${options.projectId}');
      print('App ID: ${options.appId}');
      if (options.apiKey != null && options.apiKey!.isNotEmpty) {
        print('API Key: ${_mask(options.apiKey!)}');
      }
      if (options.messagingSenderId != null && options.messagingSenderId!.isNotEmpty) {
        print('Sender ID: ${options.messagingSenderId}');
      }
      if (options.storageBucket != null) {
        print('Storage bucket: ${options.storageBucket}');
      }

      // Try a very small Firestore read to verify connectivity and rules.
      try {
        final pingCol = FirebaseFirestore.instance.collection('__diag');
        // Try to read 1 doc (likely none exist). This still hits Firestore and will
        // surface permission or network issues in logs.
        final qs = await pingCol.limit(1).get();
        print('Firestore connectivity: OK (fetched ${qs.docs.length} docs from __diag).');
      } catch (e) {
        print('🔴 FirebaseDiag: Firestore read failed. Check network/rules/project linkage. Error: $e');
      }
      print('======================================================');
    } catch (e) {
      print('🔴 FirebaseDiag error: $e');
    }
  }

  static String _mask(String s) {
    if (s.length <= 8) return '********';
    return s.substring(0, 4) + '****' + s.substring(s.length - 4);
    }
}
