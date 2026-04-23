import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';

class BusinessService {
  static final _db = FirebaseFirestore.instance;

  // ─── READ SINGLE ──────────────────────────────────────────────────────────

  static Future<BusinessModel?> getBusinessData(String uid) async {
    try {
      final doc = await _db.collection('businesses').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return BusinessModel.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  static Stream<BusinessModel?> watchBusiness(String uid) {
    return _db
        .collection('businesses')
        .doc(uid)
        .snapshots()
        .map((doc) =>
            doc.exists ? BusinessModel.fromDocument(doc) : null);
  }

  // ─── READ LIST ────────────────────────────────────────────────────────────

  static Stream<List<BusinessModel>> watchAll() {
    return _db
        .collection('businesses')
        .snapshots()
        .map((snap) => snap.docs
            .map(BusinessModel.fromDocument)
            .toList());
  }

  static Stream<List<BusinessModel>> watchByStatus(String status) {
    return _db
        .collection('businesses')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snap) => snap.docs
            .map(BusinessModel.fromDocument)
            .toList());
  }

  static Stream<List<BusinessModel>> watchActive() {
    return watchByStatus('active');
  }

  static Stream<List<BusinessModel>> watchPending() {
    return watchByStatus('pending');
  }

  static Future<List<BusinessModel>> getActiveBusinesses() async {
    try {
      final snap = await _db
          .collection('businesses')
          .where('status', isEqualTo: 'active')
          .get();
      return snap.docs.map(BusinessModel.fromDocument).toList();
    } catch (_) {
      return [];
    }
  }

  // Retourne un map uid → BusinessModel pour les JOINs rapides
  static Future<Map<String, BusinessModel>> getBusinessesMap(
      List<String> uids) async {
    if (uids.isEmpty) return {};
    try {
      // Firestore limite whereIn à 10 éléments — on batch par chunks
      final chunks = <List<String>>[];
      for (var i = 0; i < uids.length; i += 10) {
        chunks.add(uids.sublist(
            i, i + 10 > uids.length ? uids.length : i + 10));
      }

      final results = <String, BusinessModel>{};
      for (final chunk in chunks) {
        final snap = await _db
            .collection('businesses')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          results[doc.id] = BusinessModel.fromDocument(doc);
        }
      }
      return results;
    } catch (_) {
      return {};
    }
  }

  // ─── CATEGORIES ───────────────────────────────────────────────────────────

  static Future<List<String>> getCategories() async {
    try {
      final snap = await _db
          .collection('businesses')
          .where('status', isEqualTo: 'active')
          .get();

      final cats = <String>{};
      for (final doc in snap.docs) {
        final cat = (doc.data())['category'] as String?;
        if (cat != null && cat.isNotEmpty) cats.add(cat);
      }
      return cats.toList()..sort();
    } catch (_) {
      return [];
    }
  }

  // ─── ADMIN ACTIONS ────────────────────────────────────────────────────────

  static Future<void> updateStatus(String uid, String status) async {
    final batch = _db.batch();

    batch.update(
      _db.collection('businesses').doc(uid),
      {'status': status},
    );
    batch.update(
      _db.collection('users').doc(uid),
      {'status': status},
    );

    await batch.commit();
  }

  static Future<void> approve(String uid) => updateStatus(uid, 'active');
  static Future<void> reject(String uid)  => updateStatus(uid, 'rejected');

  // ─── STATS (incréments atomiques) ─────────────────────────────────────────

  static Future<void> incrementStat(
      String uid, String field, {int by = 1}) async {
    try {
      await _db.collection('businesses').doc(uid).update({
        'stats.$field': FieldValue.increment(by),
      });
    } catch (_) {}
  }

  static Future<void> incrementWeeklyView(String uid, String day) async {
    try {
      await _db.collection('businesses').doc(uid).update({
        'weekly_views.$day': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  static Future<void> updateMatriculeImageUrl(
      String businessId, String url) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .update({'matriculeImageUrl': url});
  }
}
