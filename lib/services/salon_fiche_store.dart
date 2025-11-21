import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Local store for "fiches salon" with SQLite persistence (no Firestore).
class SalonFicheStore {
  SalonFicheStore._() {
    // Load persisted fiches on first use
    Future.microtask(_loadFromDb);
  }
  static final SalonFicheStore instance = SalonFicheStore._();

  /// ValueListenable so UI can rebuild when list changes.
  final ValueNotifier<List<Map<String, dynamic>>> fiches =
      ValueNotifier<List<Map<String, dynamic>>>(<Map<String, dynamic>>[]);

  Future<void> _loadFromDb() async {
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

    // Persist asynchronously
    DatabaseHelper.instance.insertSalonFiche(id, fiche).catchError((_) {});
    return id;
  }

  void removeFiche(String id) {
    fiches.value = fiches.value.where((e) => e['id'] != id).toList();
    // Delete from DB asynchronously
    DatabaseHelper.instance.deleteSalonFiche(id).catchError((_) {});
  }

  Map<String, dynamic>? getById(String id) {
    try {
      return fiches.value.firstWhere((e) => e['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
