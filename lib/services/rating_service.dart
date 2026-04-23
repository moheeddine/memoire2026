import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';

class RatingService {
  static final _db = FirebaseFirestore.instance;
  static final _col = _db.collection('ratings');

  // One rating per user per business — stored as ratings/{businessId}_{userId}
  static String _docId(String userId, String businessId) =>
      '${businessId}_$userId';

  static Future<void> rate(
      String userId, String businessId, double score) async {
    final id = _docId(userId, businessId);
    await _col.doc(id).set(
          RatingModel(
            id: id,
            userId: userId,
            businessId: businessId,
            score: score.clamp(1.0, 5.0),
          ).toMap(),
          SetOptions(merge: true),
        );
    await _updateBusinessAverage(businessId);
  }

  static Future<double?> getUserRating(
      String userId, String businessId) async {
    try {
      final doc = await _col.doc(_docId(userId, businessId)).get();
      if (!doc.exists) return null;
      return (doc.data()?['score'] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  static Stream<double> watchAverageRating(String businessId) {
    return _col
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return 0.0;
      final total = snap.docs.fold<double>(
          0, (sum, d) => sum + ((d.data()['score'] as num?)?.toDouble() ?? 0));
      return total / snap.docs.length;
    });
  }

  static Future<double> getAverageRating(String businessId) async {
    try {
      final snap =
          await _col.where('businessId', isEqualTo: businessId).get();
      if (snap.docs.isEmpty) return 0.0;
      final total = snap.docs.fold<double>(
          0, (sum, d) => sum + ((d.data()['score'] as num?)?.toDouble() ?? 0));
      return total / snap.docs.length;
    } catch (_) {
      return 0.0;
    }
  }

  static Future<int> getRatingCount(String businessId) async {
    try {
      final snap =
          await _col.where('businessId', isEqualTo: businessId).get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  // Denormalize average into the business document for quick reads
  static Future<void> _updateBusinessAverage(String businessId) async {
    try {
      final avg = await getAverageRating(businessId);
      final count = await getRatingCount(businessId);
      await _db.collection('businesses').doc(businessId).update({
        'averageRating': avg,
        'ratingCount': count,
      });
    } catch (_) {}
  }
}
