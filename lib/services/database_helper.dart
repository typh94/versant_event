import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('versant_event.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Increment version for migrations
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable foreign keys (safe even without explicit FK constraints)
        await db.execute('PRAGMA foreign_keys = ON');
        // Try enabling WAL for better durability and concurrent reads.
        // On iOS/macOS, changing journal mode can throw a benign error. Ignore failures.
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {
          // Ignore: not all platforms/drivers allow setting WAL. Database remains usable.
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerTypeNullable = 'INTEGER';

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType,
        password $textType,
        email $textTypeNullable,
        created_at $textType
      )
    ''');

    // Drafts table
    await db.execute('''
      CREATE TABLE drafts (
        id $textType PRIMARY KEY,
        title $textType,
        owner $textType,
        data $textType,
        created_at $textType,
        updated_at $textType,
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Reports table (for completed reports)
    await db.execute('''
      CREATE TABLE reports (
        id $idType,
        draft_id $textTypeNullable,
        owner $textType,
        title $textType,
        salon_name $textTypeNullable,
        stand_name $textTypeNullable,
        stand_hall $textTypeNullable,
        stand_nb $textTypeNullable,
        tech_name $textTypeNullable,
        date_transmission $textTypeNullable,
        pdf_path $textTypeNullable,
        docx_path $textTypeNullable,
        data $textType,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // Images table (to track all images with proper paths)
    await db.execute('''
      CREATE TABLE images (
        id $idType,
        report_id $textTypeNullable,
        draft_id $textTypeNullable,
        image_type $textType,
        image_path $textType,
        description $textTypeNullable,
        article_index $integerTypeNullable,
        created_at $textType
      )
    ''');

    // Settings table
    await db.execute('''
      CREATE TABLE settings (
        key $textType PRIMARY KEY,
        value $textType,
        updated_at $textType
      )
    ''');

    // Salon fiches table
    await db.execute('''
      CREATE TABLE salon_fiches (
        id TEXT PRIMARY KEY,
        data $textType,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // Indices to speed up common queries
    await db.execute('CREATE INDEX IF NOT EXISTS idx_drafts_owner_archived ON drafts(owner, archived, updated_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reports_owner_created ON reports(owner, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_images_draft ON images(draft_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_images_report ON images(report_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add migration logic here if needed
      // For example, adding new columns or tables
    }
    if (oldVersion < 3) {
      // Add archived column to drafts
      try {
        await db.execute('ALTER TABLE drafts ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // Column may already exist on some devices
        print('Migration v3: archived column add error: $e');
      }
    }
    if (oldVersion < 4) {
      // Create salon_fiches table if upgrading
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS salon_fiches (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        print('Migration v4: create salon_fiches error: $e');
      }
    }
    if (oldVersion < 5) {
      // Create indices introduced in v5
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_drafts_owner_archived ON drafts(owner, archived, updated_at)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_reports_owner_created ON reports(owner, created_at)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_draft ON images(draft_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_images_report ON images(report_id)');
      } catch (e) {
        print('Migration v5: create indexes error: $e');
      }
    }
  }

  // CRUD Operations for Users
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    user['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('users', user);
  }

  Future<Map<String, dynamic>?> getUser(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<int> updateUser(String username, Map<String, dynamic> user) async {
    final db = await database;
    return await db.update(
      'users',
      user,
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  // CRUD Operations for Drafts
  Future<void> insertDraft(String id, Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'drafts',
      {
        'id': id,
        'title': data['title'] ?? '',
        'owner': data['owner'] ?? '',
        'data': jsonEncode(data),
        'created_at': now,
        'updated_at': now,
        'archived': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getDraft(String id) async {
    final db = await database;
    final maps = await db.query(
      'drafts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final draft = maps.first;
      return jsonDecode(draft['data'] as String) as Map<String, dynamic>;
    }
    return null;
  }

// In DatabaseHelper class, update this method:

  Future<List<Map<String, dynamic>>> getDraftsByOwner(String owner) async {
    final db = await database;
    final maps = await db.query(
      'drafts',
      where: 'owner = ? AND archived = 0',
      whereArgs: [owner],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        // Merge database metadata with the stored data
        return {
          'id': map['id'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'], // For backwards compatibility
          ...data, // Spread all the form data
        };
      } catch (e) {
        print('Error parsing draft data: $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDraftsForAdmin() async {
    final db = await database;
    final maps = await db.query(
      'drafts',
      where: 'archived = 0',
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        // Merge database metadata with the stored data
        return {
          'id': map['id'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'], // For backwards compatibility
          ...data, // Spread all the form data
        };
      } catch (e) {
        print('Error parsing draft data: $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }


  Future<List<Map<String, dynamic>>> getDraftsByOwnersList(List<String> owners) async {
    final db = await database;

    // Crée une chaîne de placeholders comme '?, ?' pour la clause WHERE IN
    final placeholders = List.filled(owners.length, '?').join(', ');

    final maps = await db.query(
      'drafts',
      // Utilise la clause IN pour récupérer les brouillons de plusieurs propriétaires
      where: 'owner IN ($placeholders) AND archived = 0',
      whereArgs: owners,
      orderBy: 'updated_at DESC',
    );

    // Mappage similaire à getDraftsByOwner pour décoder les données
    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        // Fusionne les métadonnées avec les données du formulaire
        return {
          'id': map['id'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'], // Pour la compatibilité
          ...data, // Étale toutes les données du formulaire
        };
      } catch (e) {
        print('Error parsing draft data: $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }
  Future<int> updateDraft(String id, Map<String, dynamic> data) async {
    final db = await database;

    // Preserve existing owner if none provided in update payload
    String? ownerToUse = data['owner'] as String?;
    if (ownerToUse == null || ownerToUse.isEmpty) {
      final existing = await db.query(
        'drafts',
        columns: ['owner'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        ownerToUse = existing.first['owner'] as String?;
      }
    }

    return await db.update(
      'drafts',
      {
        'title': data['title'] ?? '',
        'owner': ownerToUse ?? '',
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDraft(String id) async {
    final db = await database;
    // Also delete associated images
    await db.delete('images', where: 'draft_id = ?', whereArgs: [id]);
    return await db.delete('drafts', where: 'id = ?', whereArgs: [id]);
  }

  // Archive/unarchive a draft
  Future<int> setDraftArchived(String id, bool archived) async {
    final db = await database;
    return await db.update(
      'drafts',
      {
        'archived': archived ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Archived queries
  Future<List<Map<String, dynamic>>> getArchivedDraftsByOwner(String owner) async {
    final db = await database;
    final maps = await db.query(
      'drafts',
      where: 'owner = ? AND archived = 1',
      whereArgs: [owner],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        return {
          'id': map['id'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
          ...data,
        };
      } catch (e) {
        print('Error parsing archived draft data: $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }

  // Salon fiches CRUD
  Future<void> insertSalonFiche(String id, Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'salon_fiches',
      {
        'id': id,
        'data': jsonEncode(data),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllSalonFiches() async {
    final db = await database;
    final maps = await db.query(
      'salon_fiches',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) {
      try {
        final data = jsonDecode(m['data'] as String) as Map<String, dynamic>;
        return {
          'id': m['id'],
          ...data,
        };
      } catch (e) {
        print('Error parsing salon fiche data: $e');
        return {
          'id': m['id'],
        };
      }
    }).toList();
  }

  Future<int> deleteSalonFiche(String id) async {
    final db = await database;
    return await db.delete('salon_fiches', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getArchivedDraftsByOwnersList(List<String> owners) async {
    final db = await database;
    final placeholders = List.filled(owners.length, '?').join(', ');
    final maps = await db.query(
      'drafts',
      where: 'owner IN ($placeholders) AND archived = 1',
      whereArgs: owners,
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        return {
          'id': map['id'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
          ...data,
        };
      } catch (e) {
        print('Error parsing archived draft data (owners list): $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getAllArchivedDrafts() async {
    final db = await database;
    final maps = await db.query(
      'drafts',
      where: 'archived = 1',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        return {
          'id': map['id'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
          ...data,
        };
      } catch (e) {
        print('Error parsing ALL archived draft data: $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }

  // CRUD Operations for Reports
  Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return await db.insert('reports', {
      'draft_id': report['draft_id'],
      'owner': report['owner'],
      'title': report['title'] ?? '',
      'salon_name': report['salon_name'],
      'stand_name': report['stand_name'],
      'stand_hall': report['stand_hall'],
      'stand_nb': report['stand_nb'],
      'tech_name': report['tech_name'],
      'date_transmission': report['date_transmission'],
      'pdf_path': report['pdf_path'],
      'docx_path': report['docx_path'],
      'data': jsonEncode(report['data']),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<Map<String, dynamic>?> getDraftMetadata(String id) async {
    final db = await database;
    final maps = await db.query(
      'drafts',
      columns: ['owner', 'id'], // Récupérer seulement les champs nécessaires
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getReportsByOwner(String owner) async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'owner = ?',
      whereArgs: [owner],
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getReport(int id) async {
    final db = await database;
    final maps = await db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
  /*
  Future<List<Map<String, dynamic>>> getAllDrafts() async {
    // Assurez-vous que 'database' est bien le getter/champ de votre connexion DB
    final db = await database;

    // Exécute la requête SELECT * FROM drafts
    final List<Map<String, dynamic>> maps = await db.query('drafts');

    return maps;
  }

   */


  Future<List<Map<String, dynamic>>> getAllDrafts() async {
    final db = await database;

    // Only non-archived drafts
    final List<Map<String, dynamic>> maps = await db.query(
      'drafts',
      where: 'archived = 0',
      orderBy: 'updated_at DESC', // Ajout de l'ordre pour cohérence
    );

    return maps.map((map) {
      try {
        final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
        // Fusionne les métadonnées avec les données du formulaire
        return {
          'id': map['id'],
          'owner': map['owner'], // Très important pour l'affichage/filtrage
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
          ...data, // Étale toutes les données du formulaire (salonName, standName, etc.)
        };


      } catch (e) {
        print('Error parsing ALL draft data: $e');
        return {
          'id': map['id'],
          'title': map['title'],
          'owner': map['owner'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
          'updatedAt': map['updated_at'],
        };
      }
    }).toList();
  }

  // CRUD Operations for Images
  Future<int> insertImage(Map<String, dynamic> image) async {
    final db = await database;
    image['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('images', image);
  }

  Future<List<Map<String, dynamic>>> getImagesByDraft(String draftId) async {
    final db = await database;
    return await db.query(
      'images',
      where: 'draft_id = ?',
      whereArgs: [draftId],
    );
  }

  Future<List<Map<String, dynamic>>> getImagesByReport(int reportId) async {
    final db = await database;
    return await db.query(
      'images',
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }

  Future<int> deleteImage(int id) async {
    final db = await database;
    return await db.delete('images', where: 'id = ?', whereArgs: [id]);
  }

  // Settings operations
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('users');
    await db.delete('drafts');
    await db.delete('reports');
    await db.delete('images');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }


}