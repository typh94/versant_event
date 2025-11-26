/*import 'dart:convert';
import 'package:versant_event/io_stubs.dart' if (dart.library.io) 'dart:io'; // Conditional for web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'package:versant_event/stubs/path_provider_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/form_data.dart';

class StorageService {
  // Use a flexible return type to avoid web/IO Directory type mismatch during web compile
  Future<dynamic> get _appDocDir async {
    if (kIsWeb) {
      // Return a stub Directory for web; actual file IO is avoided on web paths
      return Directory('/');
    }
    // On IO platforms, this is a dart:io Directory; declare as dynamic to unify types
    return await getApplicationDocumentsDirectory() as dynamic;
  }

  // ===== Legacy helpers for FormData model (kept for compatibility) =====
  Future<String> saveFormData(FormData data) async {
    if (kIsWeb) {
      // Store as draft in SharedPreferences under a legacy namespace
      final prefs = await SharedPreferences.getInstance();
      final id = data.id;
      final key = 'legacy_form_$id';
      await prefs.setString(key, data.toJsonString());
      return key; // return the storage key as a path surrogate
    }
    final dir = await _appDocDir;
    final file = File('${dir.path}/${data.id}.json');
    await file.writeAsString(data.toJsonString());
    return file.path;
  }

  Future<FormData?> loadFormData(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = id.startsWith('legacy_form_') ? id : 'legacy_form_$id';
      final s = prefs.getString(key);
      if (s != null) {
        return FormData.fromJson(jsonDecode(s));
      }
      return null;
    }
    final dir = await _appDocDir;
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      final s = await file.readAsString();
      return FormData.fromJson(jsonDecode(s));
    }
    return null;
  }

  Future<List<String>> listSavedIds() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs
          .getKeys()
          .where((k) => k.startsWith('legacy_form_'))
          .map((k) => k.replaceFirst('legacy_form_', ''))
          .toList();
    }
    final dir = await _appDocDir;
    final files = dir.listSync();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.path.split('/').last.replaceAll('.json', ''))
        .toList();
  }

  // ===== New generic draft helpers (web-safe) =====
  static const _indexKey = 'drafts_index';
  static String _draftKey(String id) => 'draft_$id';

  Future<String> saveDraft(Map<String, dynamic> data, {String? id}) async {
    final draftId = id ?? _newId();
    final enriched = {
      'id': draftId,
      'updatedAt': DateTime.now().toIso8601String(),
      ...data,
    };

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      // Update index
      final index = prefs.getStringList(_indexKey) ?? <String>[];
      if (!index.contains(draftId)) index.add(draftId);
      await prefs.setStringList(_indexKey, index);
      // Save JSON
      await prefs.setString(_draftKey(draftId), jsonEncode(enriched));
      return draftId;
    }

    final dir = await _appDocDir;
    final file = File('${dir.path}/$draftId.json');
    await file.writeAsString(jsonEncode(enriched));
    return draftId;
  }

  Future<void> deleteDraft(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getStringList(_indexKey) ?? <String>[];
      index.remove(id);
      await prefs.setStringList(_indexKey, index);
      await prefs.remove(_draftKey(id));
      return;
    }
    final dir = await _appDocDir;
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Map<String, dynamic>?> loadDraft(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_draftKey(id));
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    }
    final dir = await _appDocDir;
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      final s = await file.readAsString();
      return jsonDecode(s) as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> listDrafts({String? owner}) async {
    final List<Map<String, dynamic>> drafts = [];

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_indexKey) ?? <String>[];
      for (final id in ids) {
        final s = prefs.getString(_draftKey(id));
        if (s == null) continue;
        try {
          final json = jsonDecode(s) as Map<String, dynamic>;
          drafts.add({
            'id': json['id'] ?? id,
            'title': json['title'] ?? json['contactSinistre'] ?? json['name'] ?? 'Fiche sans titre',
            'updatedAt': json['updatedAt'] ?? '',
            'address': json['addresseSinistre'] ?? json['email'] ?? '',
            'hall': json['hall'] ?? '',
            'standNb': json['standNb'] ?? '',
            'standName': json['standName'] ?? '',
            'salonName': json['salonName'] ?? '',
            'owner': json['owner'] ?? '',
            'techName': json['techName'] ?? '',
            'objMission': json['objMission'] ?? '',
            'dateTransmission': json['dateTransmission'] ?? '',
            'mailClient': json['mailClient'] ?? '',
            'dscrptnSommaire': json['dscrptnSommaire'] ?? '',
          });
        } catch (_) {
          // skip invalid
        }
      }
      // Sort by updatedAt desc if available
      drafts.sort((a, b) => (b['updatedAt'] ?? '').compareTo(a['updatedAt'] ?? ''));
    } else {
      final dir = await _appDocDir;
      // Ensure we operate on a strongly typed Iterable<File> to avoid runtime type issues
      final Iterable<File> typedFiles = (dir.listSync() as List).whereType<File>();
      final List<File> files = typedFiles
          .where((File f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      for (final f in files) {
        try {
          final s = await f.readAsString();
          final json = jsonDecode(s) as Map<String, dynamic>;
          drafts.add({
            'id': json['id'] ?? f.path.split('/').last.replaceAll('.json', ''),
            'title': json['title'] ?? json['contactSinistre'] ?? json['name'] ?? 'Fiche sans titre',
            'updatedAt': json['updatedAt'] ?? '',
            'address': json['addresseSinistre'] ?? json['email'] ?? '',
            'hall': json['hall'] ?? '',
            'standNb': json['standNb'] ?? '',
            'standName': json['standName'] ?? '',
            'salonName': json['salonName'] ?? '',
            'owner': json['owner'] ?? '',
            'techName': json['techName'] ?? '',
            'objMission': json['objMission'] ?? '',
            'dateTransmission': json['dateTransmission'] ?? '',
            'mailClient': json['mailClient'] ?? '',
            'dscrptnSommaire': json['dscrptnSommaire'] ?? '',

            'installateurName': json['installateurName'] ?? '',
            'proprioMatosName': json['proprioMatosName'] ?? '',
            'nbStructuresTot': json['nbStructuresTot'] ?? '',

            'nbTowers': json['nbTowers'] ?? '',
            'nbPalans': json['nbPalans'] ?? '',
            'marqueModelPP': json['marqueModelPP'] ?? '',
            'rideauxEnseignes': json['rideauxEnseignes'] ?? '',
            'poidGrilTot': json['poidGrilTot'] ?? '',



          });
        } catch (_) {
          // Skip malformed
        }
      }
    }

    if (owner != null && owner.isNotEmpty) {
      return drafts.where((d) => (d['owner'] ?? '') == owner).toList();
    }
    return drafts;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}


 */
import 'database_helper.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Archive/unarchive a draft
  Future<void> archiveDraft(String id, bool archived) async {
    if (kIsWeb) {
      // On web, use Firestore since SQLite is not available
      try {
        await FirestoreService.instance.updateForm(id, {'archived': archived});
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ archiveDraft(web) failed: $e');
        }
      }
      return;
    }
    await _dbHelper.setDraftArchived(id, archived);
  }
/*
  // Save draft to database
  Future<String> saveDraft(Map<String, dynamic> data, {String? id}) async {
    final draftId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (id != null) {
      await _dbHelper.updateDraft(draftId, data);
    } else {
      await _dbHelper.insertDraft(draftId, data);
    }

    return draftId;
  }

 */
  // The modification:
  Future<String> saveDraft(Map<String, dynamic> data, {String? id, required String owner}) async {
    final draftId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Preserve the original owner on updates. Only set to the passed owner on insert.
    String ownerToUse = owner;
    if (!kIsWeb && id != null) {
      final meta = await _dbHelper.getDraftMetadata(draftId);
      final existingOwner = (meta != null ? meta['owner'] as String? : null);
      if (existingOwner != null && existingOwner.isNotEmpty) {
        ownerToUse = existingOwner; // keep original owner
      }
    }

    // Always record who last edited this draft (the current user calling save)
    final lastEditedBy = owner;

    final dataWithOwner = {
      ...data,
      'owner': ownerToUse,
      'lastEditedBy': lastEditedBy,
      'archived': false,
    };

    if (kIsWeb) {
      // On web, directly upsert to Firestore and return id
      try {
        await FirestoreService.instance.setForm(draftId, dataWithOwner, merge: true);
        if (kDebugMode) {
          // ignore: avoid_print
          print('✅ StorageService.saveDraft(web) -> Saved to Firestore. id=$draftId');
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ StorageService.saveDraft(web) -> Firestore save failed. id=$draftId error=$e');
        }
        rethrow;
      }
      return draftId;
    }

    // IO platforms: save locally then sync to Firestore best-effort
    if (id != null) {
      await _dbHelper.updateDraft(draftId, dataWithOwner);
    } else {
      await _dbHelper.insertDraft(draftId, dataWithOwner);
    }

    // Also upsert to Firestore (best-effort). Do not throw if it fails.
    try {
      await FirestoreService.instance.setForm(draftId, dataWithOwner, merge: true);
      if (kDebugMode) {
        // ignore: avoid_print
        print('✅ StorageService.saveDraft -> Saved to Firestore. id=$draftId');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('❌ StorageService.saveDraft -> Firestore save failed (local save succeeded). id=$draftId error=$e');
      }
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('ℹ️ StorageService.saveDraft -> Saved locally in SQLite AND attempted Firestore sync. id=$draftId owner=$ownerToUse lastEditedBy=$lastEditedBy');
    }

    return draftId;
  }

  // Load draft from storage (Firestore on web, SQLite on IO)
  Future<Map<String, dynamic>?> loadDraft(String id) async {
    if (kIsWeb) {
      try {
        final snap = await FirestoreService.instance.getFormOnce(id);
        if (!snap.exists) return null;
        final data = snap.data();
        if (data == null) return null;
        // Normalize and include id for consumers expecting it
        return {
          'id': id,
          ...data,
        };
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ loadDraft(web) failed for $id: $e');
        }
        return null;
      }
    }
    // IO platforms: first try local SQLite, then fall back to Firestore (to see web-created forms)
    final local = await _dbHelper.getDraft(id);
    if (local != null) return local;
    try {
      final snap = await FirestoreService.instance.getFormOnce(id);
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return {'id': id, ...data};
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('ℹ️ loadDraft(IO): Firestore fallback failed for $id: $e');
      }
      return null;
    }
  }

  // Get all drafts for current user
  Future<List<Map<String, dynamic>>> getAllDrafts(String owner) async {

    return await _dbHelper.getDraftsByOwner(owner);
  }
/*
  // List all drafts (for backwards compatibility with your DraftsListScreen)
  Future<List<Map<String, dynamic>>> listDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = prefs.getString('current_user') ?? '';

    // Get drafts from database
    final drafts = await _dbHelper.getDraftsByOwner(currentUser);

    // Transform the data to match the expected format in your UI
    return drafts.map((draft) {
      return {
        'id': draft['id'],
        'salonName': draft['salonName'] ?? draft['title'],
        'standName': draft['standName'],
        'hall': draft['hall'],
        'standNb': draft['standNb'],
        'updatedAt': draft['updated_at'],
        'owner': draft['owner'],
        // Include all other fields
        ...draft,
      };
    }).toList();
  }


 */

  /*
  Future<List<Map<String, dynamic>>> listDrafts({required String owner}) async { // <-- Now requires 'owner'

    // Get drafts from database
    final drafts = await _dbHelper.getDraftsByOwner(owner); // <-- Uses the passed owner

    // Transform the data to match the expected format in your UI
    return drafts.map((draft) {
      return {
        'id': draft['id'],
        'salonName': draft['salonName'] ?? draft['title'],
        'standName': draft['standName'],
        'hall': draft['hall'],
        'standNb': draft['standNb'],
        'updatedAt': draft['updated_at'],
        'owner': draft['owner'],
        // Include all other fields
        ...draft,
      };
    }).toList();
  }

   */
  Future<List<Map<String, dynamic>>> _transformDrafts(List<Map<String, dynamic>> drafts) async {
    return drafts.map((draft) {
      final updatedAt = draft['updated_at'] ?? draft['updatedAt'];
      return {
        'id': draft['id'],
        'salonName': draft['salonName'] ?? draft['title'],
        'standName': draft['standName'],
        'hall': draft['hall'],
        'standNb': draft['standNb'],
        'updatedAt': updatedAt is Timestamp ? updatedAt.toDate().toIso8601String() : (updatedAt?.toString()),
        'owner': draft['owner'],
        'lastEditedBy': draft['lastEditedBy'] ?? draft['owner'],
      };
    }).toList();
  }

  /*
  Future<List<Map<String, dynamic>>> listDraftsToDisplay({
    required String currentUser,
    required bool isAdmin,
  }) async {
    // 1. Récupération des données brutes
    List<Map<String, dynamic>> rawDrafts;

    if (isAdmin) {
      rawDrafts = await _dbHelper.getAllDrafts();
    } else {

      rawDrafts = await _dbHelper.getDraftsByOwner(currentUser);
    }

    // 2. Transformation pour l'affichage
    return _transformDrafts(rawDrafts);
  }


   */



  Future<List<Map<String, dynamic>>> listDraftsToDisplay({
    required String currentUser,
    required bool isAdmin,
    required String adminUsername, // <-- NÉCESSAIRE: Vous devez passer le nom de l'Admin
  }) async {
    List<Map<String, dynamic>> rawDrafts = [];

    if (kIsWeb) {
      try {
        final col = FirebaseFirestore.instance.collection(FirestoreService.formsCollection);
        QuerySnapshot<Map<String, dynamic>> snap;
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
        if (isAdmin) {
          // Admin: load all docs (no order to avoid composite index), client-sort later
          snap = await col.get();
          docs = snap.docs;
        } else {
          // Tech: first try by owner filter
          final ownersToFetch = <String>{currentUser, if (adminUsername.isNotEmpty) adminUsername}.toList();
          try {
            snap = await col.where('owner', whereIn: ownersToFetch).get();
            docs = snap.docs;
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('ℹ️ listDraftsToDisplay(web): owner whereIn failed or empty. Falling back to full scan. err=$e');
            }
          }
          // If no docs found, fall back to fetching all and filter client-side by heuristics
          if (docs.isEmpty) {
            final fallback = await col.get();
            docs = fallback.docs.where((d) {
              final data = d.data();
              final owner = data['owner'];
              final createdBy = data['createdBy'];
              final techName = data['techName'];
              final visibleToTech = (owner == currentUser) || (owner == adminUsername) ||
                  (owner == null && (createdBy == currentUser || techName == currentUser));
              return visibleToTech;
            }).toList();
          }
        }
        rawDrafts = docs.map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
          };
        }).toList();
        // Client-side sort by updatedAt desc if present
        rawDrafts.sort((a, b) {
          final ua = a['updatedAt'];
          final ub = b['updatedAt'];
          DateTime pa;
          DateTime pb;
          if (ua is Timestamp) {
            pa = ua.toDate();
          } else {
            pa = DateTime.tryParse(ua?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          if (ub is Timestamp) {
            pb = ub.toDate();
          } else {
            pb = DateTime.tryParse(ub?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          return pb.compareTo(pa);
        });
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ listDraftsToDisplay(web): $e');
        }
      }
    } else {
      // IO platforms: merge local SQLite with Firestore so mobile sees web-created forms
      try {
        final col = FirebaseFirestore.instance.collection(FirestoreService.formsCollection);
        List<Map<String, dynamic>> cloud = [];

        if (isAdmin) {
          // Admin: prefer non-archived forms
          try {
            final snap = await col.where('archived', isEqualTo: false).get();
            cloud = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          } catch (_) {
            // Fallback: fetch all and filter client-side
            final fallback = await col.get();
            cloud = fallback.docs
                .map((d) => {'id': d.id, ...d.data()})
                .where((m) => (m['archived'] ?? false) != true)
                .toList();
          }
          rawDrafts = await _dbHelper.getAllDrafts();
        } else {
          // Technician: own + admin's, non-archived
          final ownersToFetch = <String>{currentUser, if (adminUsername.isNotEmpty) adminUsername}.toList();
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
          try {
            final snap = await col
                .where('owner', whereIn: ownersToFetch)
                .where('archived', isEqualTo: false)
                .get();
            docs = snap.docs;
          } catch (e) {
            // Fallback: whereIn or composite might fail; fetch by owners first, then filter non-archived
            try {
              final snap = await col.where('owner', whereIn: ownersToFetch).get();
              docs = snap.docs
                  .where((d) => (d.data()['archived'] ?? false) != true)
                  .toList();
            } catch (_) {
              // Last resort: full scan then filter by owners and archived
              final fallback = await col.get();
              docs = fallback.docs.where((d) {
                final data = d.data();
                final owner = data['owner'];
                final archived = data['archived'] == true;
                return !archived && (owner == currentUser || owner == adminUsername);
              }).toList();
            }
          }
          cloud = docs.map((d) => {'id': d.id, ...d.data()}).toList();

          // Local drafts for same owners
          final localOwners = [currentUser, adminUsername];
          rawDrafts = await _dbHelper.getDraftsByOwnersList(localOwners);
        }

        // Merge local and cloud by id, cloud wins on conflicts
        final byId = <String, Map<String, dynamic>>{};
        for (final d in rawDrafts) {
          final id = d['id'] as String?;
          if (id != null) byId[id] = d;
        }
        for (final c in cloud) {
          final id = c['id'] as String?;
          if (id != null) byId[id] = {...(byId[id] ?? {}), ...c};
        }
        rawDrafts = byId.values.toList();

        // Sort by updatedAt desc if present
        rawDrafts.sort((a, b) {
          final ua = a['updatedAt'];
          final ub = b['updatedAt'];
          DateTime pa;
          DateTime pb;
          if (ua is Timestamp) {
            pa = ua.toDate();
          } else {
            pa = DateTime.tryParse(ua?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          if (ub is Timestamp) {
            pb = ub.toDate();
          } else {
            pb = DateTime.tryParse(ub?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          return pb.compareTo(pa);
        });
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('ℹ️ listDraftsToDisplay(IO): Firestore merge failed, falling back to local only. err=$e');
        }
        if (isAdmin) {
          rawDrafts = await _dbHelper.getAllDrafts();
        } else {
          final ownersToFetch = [currentUser, adminUsername];
          rawDrafts = await _dbHelper.getDraftsByOwnersList(ownersToFetch);
          final seenIds = <String>{};
          rawDrafts = rawDrafts.where((draft) => seenIds.add(draft['id'] as String)).toList();
        }
      }
    }

    // Transform for UI
    return _transformDrafts(rawDrafts);
  }

  // Archived lists (for Archive screen)
  Future<List<Map<String, dynamic>>> listArchivedDraftsToDisplay({
    required String currentUser,
    required bool isAdmin,
    required String adminUsername,
  }) async {
    List<Map<String, dynamic>> rawDrafts = [];

    if (kIsWeb) {
      try {
        final col = FirebaseFirestore.instance.collection(FirestoreService.formsCollection);
        QuerySnapshot<Map<String, dynamic>> snap;
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
        if (isAdmin) {
          snap = await col.where('archived', isEqualTo: true).get();
          docs = snap.docs;
        } else {
          final ownersToFetch = <String>{currentUser, if (adminUsername.isNotEmpty) adminUsername}.toList();
          try {
            snap = await col
                .where('archived', isEqualTo: true)
                .where('owner', whereIn: ownersToFetch)
                .get();
            docs = snap.docs;
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('ℹ️ listArchivedDraftsToDisplay(web): whereIn failed. Fallback scan. err=$e');
            }
            final fallback = await col.where('archived', isEqualTo: true).get();
            docs = fallback.docs.where((d) {
              final data = d.data();
              final owner = data['owner'];
              final createdBy = data['createdBy'];
              final techName = data['techName'];
              final visibleToTech = (owner == currentUser) || (owner == adminUsername) ||
                  (owner == null && (createdBy == currentUser || techName == currentUser));
              return visibleToTech;
            }).toList();
          }
        }
        rawDrafts = docs.map((d) => {'id': d.id, ...d.data()}).toList();
        // Sort by updatedAt desc if present
        rawDrafts.sort((a, b) {
          final ua = a['updatedAt'];
          final ub = b['updatedAt'];
          DateTime pa;
          DateTime pb;
          if (ua is Timestamp) {
            pa = ua.toDate();
          } else {
            pa = DateTime.tryParse(ua?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          if (ub is Timestamp) {
            pb = ub.toDate();
          } else {
            pb = DateTime.tryParse(ub?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          }
          return pb.compareTo(pa);
        });
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ listArchivedDraftsToDisplay(web): $e');
        }
      }
    } else {
      if (isAdmin) {
        // Admin: sees all archived drafts
        rawDrafts = await _dbHelper.getAllArchivedDrafts();
      } else {
        // Tech: sees his archived + admin's archived
        final ownersToFetch = [currentUser, adminUsername];
        rawDrafts = await _dbHelper.getArchivedDraftsByOwnersList(ownersToFetch);
        final seenIds = <String>{};
        rawDrafts = rawDrafts.where((draft) => seenIds.add(draft['id'] as String)).toList();
      }
    }

    return _transformDrafts(rawDrafts);
  }

  // Delete draft
  Future<void> deleteDraft(String id) async {
    if (kIsWeb) {
      try {
        await FirestoreService.instance.deleteForm(id);
        if (kDebugMode) {
          // ignore: avoid_print
          print('✅ deleteDraft(web): deleted $id from Firestore');
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('❌ deleteDraft(web) failed: $e');
        }
      }
      return;
    }
    await _dbHelper.deleteDraft(id);
  }

  // Save completed report
  Future<int> saveReport(Map<String, dynamic> report) async {
    return await _dbHelper.insertReport(report);
  }

  // Get all reports for current user
  Future<List<Map<String, dynamic>>> getAllReports(String owner) async {
    return await _dbHelper.getReportsByOwner(owner);
  }

  // Track images
  Future<void> saveImageReference({
    required String imagePath,
    required String imageType,
    String? draftId,
    int? reportId,
    String? description,
    int? articleIndex,
  }) async {
    await _dbHelper.insertImage({
      'report_id': reportId?.toString(),
      'draft_id': draftId,
      'image_type': imageType,
      'image_path': imagePath,
      'description': description,
      'article_index': articleIndex,
    });
  }

  // Get images for a draft
  Future<List<Map<String, dynamic>>> getDraftImages(String draftId) async {
    return await _dbHelper.getImagesByDraft(draftId);
  }

  // Get images for a report
  Future<List<Map<String, dynamic>>> getReportImages(int reportId) async {
    return await _dbHelper.getImagesByReport(reportId);
  }
}