import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'database_helper.dart';
import 'firestore_service.dart';

/// Local store for "fiches salon" with SQLite persistence (web-safe: in-memory on web).
class SalonFicheStore {
  SalonFicheStore._() {
    // Load persisted fiches on first use (skip DB on web)
    Future.microtask(_loadFromDb);
  }
  static final SalonFicheStore instance = SalonFicheStore._();

  /// ValueListenable so UI can rebuild when list changes.
  final ValueNotifier<List<Map<String, dynamic>>> fiches =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);

  Future<void> _loadFromDb() async {
    try {
      if (kIsWeb) {
        // On web: load from Firestore so fiches are shared across devices
        final remote = await FirestoreService.instance.getAllSalonFiches();
        fiches.value = List<Map<String, dynamic>>.from(remote);
        // ignore: avoid_print
        print('SalonFicheStore: Loaded ${fiches.value.length} fiches from Firestore (web).');
        return;
      }
      // On mobile/desktop: load local first
      final local = await DatabaseHelper.instance.getAllSalonFiches();
      List<Map<String, dynamic>> merged = List<Map<String, dynamic>>.from(local);
      // Then try to merge remote
      try {
        final remote = await FirestoreService.instance.getAllSalonFiches();
        final Map<String, Map<String, dynamic>> byId = {
          for (final e in merged) (e['id'] as String): e,
        };
        for (final r in remote) {
          byId[r['id'] as String] = r; // remote wins
        }
        merged = byId.values.toList();
      } catch (_) {
        // ignore remote failures; keep local only
      }
      fiches.value = merged;
    } catch (e) {
      // keep empty on error
    }
  }

  /// Adds a new fiche (map of fields). Returns the generated local id.
  String addFiche(Map<String, dynamic> data) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fiche = {
      'id': id,
      ...data,
    };
    // Update in-memory first for responsive UI
    final next = List<Map<String, dynamic>>.from(fiches.value)..add(fiche);
    fiches.value = next;

    // Persist locally on non-web
    if (!kIsWeb) {
      DatabaseHelper.instance.insertSalonFiche(id, fiche).catchError((_) {});
    }
    // Sync to Firestore (best-effort on all platforms)
    FirestoreService.instance.setSalonFiche(id, fiche, merge: true).catchError((_) {});
    return id;
  }

  void removeFiche(String id) {
    fiches.value = fiches.value.where((e) => e['id'] != id).toList();
    // Delete from DB asynchronously on non-web only
    if (!kIsWeb) {
      DatabaseHelper.instance.deleteSalonFiche(id).catchError((_) {});
    }
    // Remove from Firestore too
    FirestoreService.instance.deleteSalonFiche(id).catchError((_) {});
  }

  Map<String, dynamic>? getById(String id) {
    try {
      return fiches.value.firstWhere((e) => e['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
