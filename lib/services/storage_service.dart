import 'dart:convert';
import 'package:versant_event/io_stubs.dart' if (dart.library.io) 'dart:io'; // Conditional for web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/form_data.dart';

class StorageService {
  Future<Directory> get _appDocDir async => await getApplicationDocumentsDirectory();

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
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
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
