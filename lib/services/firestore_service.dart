import 'package:cloud_firestore/cloud_firestore.dart';

/// FirestoreService encapsulates reads/writes and real-time streams
/// for the "forms" collection.
///
/// Roles:
/// - Admins: create and view all forms with real-time updates.
/// - Technicians: open a form by id and update fields in the same document.
class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  static const String formsCollection = 'forms';

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _forms =>
      _db.collection(formsCollection);

  /// Create a new form. If [id] is provided, uses it; otherwise a new doc id is generated.
  /// [data] can be any map of fields relevant to your form.
  ///
  /*
  Future<String> createForm({Map<String, dynamic>? data, String? id}) async {
    final now = FieldValue.serverTimestamp();
    final payload = {
      if (data != null) ...data,
      'createdAt': now,
      'updatedAt': now,
      // example additional metadata fields you might want
      // 'createdBy': currentUserId,
      // 'status': 'draft',
    };

    if (id != null && id.isNotEmpty) {
      await _forms.doc(id).set(payload, SetOptions(merge: true));
      return id;
    } else {
      final ref = await _forms.add(payload);
      return ref.id;
    }
  }

   */
  Future<String> createForm({Map<String, dynamic>? data, String? id}) async {
    print('🔵 FirestoreService: Creating form...'); // DEBUG
    final now = FieldValue.serverTimestamp();
    final payload = {
      if (data != null) ...data,
      'createdAt': now,
      'updatedAt': now,
    };

    try {
      if (id != null && id.isNotEmpty) {
        await _forms.doc(id).set(payload, SetOptions(merge: true));
        print('✅ FirestoreService: Form created with id: $id'); // DEBUG
        return id;
      } else {
        final ref = await _forms.add(payload);
        print('✅ FirestoreService: Form created with id: ${ref.id}'); // DEBUG
        return ref.id;
      }
    } catch (e) {
      print('❌ FirestoreService: Error creating form: $e'); // DEBUG
      rethrow;
    }
  }

  /// Upsert a whole form (replace or merge fields).
  Future<void> setForm(String id, Map<String, dynamic> data, {bool merge = true}) async {
    await _forms.doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: merge));
  }

  /// Update specific fields on a form document.
  Future<void> updateForm(String id, Map<String, dynamic> fields) async {
    await _forms.doc(id).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a one-time snapshot of a form.
  Future<DocumentSnapshot<Map<String, dynamic>>> getFormOnce(String id) {
    return _forms.doc(id).get();
  }

  /// Stream a single form document in real-time.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamFormById(String id) {
    return _forms.doc(id).snapshots();
  }

  /// Stream all forms (Admins), ordered by updatedAt desc.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllForms({int? limit}) {
    Query<Map<String, dynamic>> q = _forms.orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }

  /// Stream forms filtered by owner (Technicians), ordered by updatedAt desc.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamFormsByOwner(String owner, {int? limit}) {
    Query<Map<String, dynamic>> q = _forms
        .where('owner', isEqualTo: owner)
        .orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }

  // -------------------- Salon Fiches (Admin) --------------------
  /// Create a new salon fiche document in the `salonFiches` collection.
  /// Include fields like { 'name': 'Salon XYZ', 'address': '...', ... }
  Future<String> createSalonFiche({required Map<String, dynamic> data, String? id}) async {
    final now = FieldValue.serverTimestamp();
    final payload = {
      ...data,
      'createdAt': now,
      'updatedAt': now,
    };
    final col = _db.collection('salonFiches');
    if (id != null && id.isNotEmpty) {
      await col.doc(id).set(payload, SetOptions(merge: true));
      return id;
    } else {
      final ref = await col.add(payload);
      return ref.id;
    }
  }

  /// Upsert a salon fiche by id.
  Future<void> setSalonFiche(String id, Map<String, dynamic> data, {bool merge = true}) async {
    final col = _db.collection('salonFiches');
    await col.doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: merge));
  }

  /// Update fields of a salon fiche.
  Future<void> updateSalonFiche(String id, Map<String, dynamic> fields) async {
    final col = _db.collection('salonFiches');
    await col.doc(id).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a single salon fiche once.
  Future<DocumentSnapshot<Map<String, dynamic>>> getSalonFicheOnce(String id) {
    final col = _db.collection('salonFiches');
    return col.doc(id).get();
  }

  /// Stream all salon fiches (for Admin to pick from), ordered by updatedAt desc.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllSalonFiches({int? limit}) {
    Query<Map<String, dynamic>> q = _db.collection('salonFiches').orderBy('updatedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }

  // -------------------- Form Locking --------------------
  /// Try to acquire an edit lock on a form. Returns true if lock acquired or already owned.
  /// The lock is considered stale after [ttlSeconds] from lockedAt.
  Future<bool> acquireFormLock(String id, String userId, {int ttlSeconds = 600}) async {
    final ref = _forms.doc(id);
    return _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data();
      final lockedBy = data?['lockedBy'] as String?;
      final lockedAtTs = data?['lockedAt'];
      DateTime? lockedAt;
      if (lockedAtTs is Timestamp) lockedAt = lockedAtTs.toDate();
      final now = DateTime.now();
      final isExpired = lockedAt == null || now.difference(lockedAt).inSeconds > ttlSeconds;

      if (lockedBy == null || lockedBy.isEmpty || lockedBy == userId || isExpired) {
        txn.update(ref, {
          'lockedBy': userId,
          'lockedAt': FieldValue.serverTimestamp(),
        });
        return true;
      } else {
        return false;
      }
    });
  }

  /// Release the edit lock, only if owned by [userId].
  Future<void> releaseFormLock(String id, String userId) async {
    final ref = _forms.doc(id);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data();
      final lockedBy = data?['lockedBy'] as String?;
      if (lockedBy == userId) {
        txn.update(ref, {
          'lockedBy': FieldValue.delete(),
          'lockedAt': FieldValue.delete(),
        });
      }
    });
  }
}
