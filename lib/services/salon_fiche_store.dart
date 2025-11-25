import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'database_helper.dart';

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
    if (kIsWeb) {
      // On web, keep in-memory only to avoid sqflite usage
      // debug: confirm skip
      // ignore: avoid_print
      print('SalonFicheStore: Web detected, skipping SQLite load.');
      return;
    }
    try {
      final all = await DatabaseHelper.instance.getAllSalonFiches();
      fiches.value = List<Map<String, dynamic>>.from(all);
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

    // Persist asynchronously on non-web only
    if (!kIsWeb) {
      DatabaseHelper.instance.insertSalonFiche(id, fiche).catchError((_) {});
    }
    return id;
  }

  void removeFiche(String id) {
    fiches.value = fiches.value.where((e) => e['id'] != id).toList();
    // Delete from DB asynchronously on non-web only
    if (!kIsWeb) {
      DatabaseHelper.instance.deleteSalonFiche(id).catchError((_) {});
    }
  }

  Map<String, dynamic>? getById(String id) {
    try {
      return fiches.value.firstWhere((e) => e['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
