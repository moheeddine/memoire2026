import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/favorite_model.dart';
import '../utils/list_extensions.dart';

class FavoriteService {
  static final _db = FirebaseFirestore.instance;

  // ─── STREAM ───────────────────────────────────────────────────────────────

  static Stream<List<FavoriteModel>> watchFavorites(String userId) {
    return _db
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list =
              snap.docs.map(FavoriteModel.fromDocument).toList();
          list.sortByDate((f) => f.createdAt);
          return list;
        });
  }

  static Stream<List<FavoriteModel>> watchPromoFavorites(String userId) {
    return _db
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map(FavoriteModel.fromDocument)
            .where((f) => f.isPromoFavorite)
            .toList());
  }

  static Stream<List<FavoriteModel>> watchBusinessFavorites(String userId) {
    return _db
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map(FavoriteModel.fromDocument)
            .where((f) => f.isBusinessFavorite)
            .toList());
  }

  // ─── CHECK ────────────────────────────────────────────────────────────────

  static Future<bool> isFavoritePromo(
      String userId, String promoId) async {
    try {
      final snap = await _db
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .where('promoId', isEqualTo: promoId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isFavoriteBusiness(
      String userId, String businessId) async {
    try {
      final snap = await _db
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .where('businessId', isEqualTo: businessId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Retourne l'ID du document favori s'il existe, null sinon
  static Future<String?> getFavoriteId({
    required String userId,
    String? promoId,
    String? businessId,
  }) async {
    assert(promoId != null || businessId != null);
    try {
      Query query = _db
          .collection('favorites')
          .where('userId', isEqualTo: userId);

      if (promoId != null) {
        query = query.where('promoId', isEqualTo: promoId);
      } else {
        query = query.where('businessId', isEqualTo: businessId);
      }

      final snap = await query.limit(1).get();
      return snap.docs.isEmpty ? null : snap.docs.first.id;
    } catch (_) {
      return null;
    }
  }

  // Retourne un Set de promoIds favoris pour un user (pour check rapide)
  static Future<Set<String>> getFavoritePromoIds(String userId) async {
    try {
      final snap = await _db
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();
      return snap.docs
          .map(FavoriteModel.fromDocument)
          .where((f) => f.promoId != null && f.promoId!.isNotEmpty)
          .map((f) => f.promoId!)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  // Retourne un Set de businessIds favoris pour un user
  static Future<Set<String>> getFavoriteBusinessIds(String userId) async {
    try {
      final snap = await _db
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();
      return snap.docs
          .map(FavoriteModel.fromDocument)
          .where((f) => f.businessId != null && f.businessId!.isNotEmpty)
          .map((f) => f.businessId!)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  // ─── WRITE ────────────────────────────────────────────────────────────────

  static Future<void> addPromoFavorite(
      String userId, String promoId) async {
    final alreadyFav = await isFavoritePromo(userId, promoId);
    if (alreadyFav) return;

    await _db.collection('favorites').add({
      'userId':    userId,
      'promoId':   promoId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addBusinessFavorite(
      String userId, String businessId) async {
    final alreadyFav = await isFavoriteBusiness(userId, businessId);
    if (alreadyFav) return;

    await _db.collection('favorites').add({
      'userId':     userId,
      'businessId': businessId,
      'createdAt':  FieldValue.serverTimestamp(),
    });
  }

  // Toggle : ajoute si absent, supprime si présent
  // Retourne true si le favori a été ajouté, false s'il a été supprimé
  static Future<bool> togglePromoFavorite(
      String userId, String promoId) async {
    final docId = await getFavoriteId(
        userId: userId, promoId: promoId);

    if (docId != null) {
      await removeFavorite(docId);
      return false;
    } else {
      await addPromoFavorite(userId, promoId);
      return true;
    }
  }

  static Future<bool> toggleBusinessFavorite(
      String userId, String businessId) async {
    final docId = await getFavoriteId(
        userId: userId, businessId: businessId);

    if (docId != null) {
      await removeFavorite(docId);
      return false;
    } else {
      await addBusinessFavorite(userId, businessId);
      return true;
    }
  }

  static Future<void> removeFavorite(String favoriteId) async {
    await _db.collection('favorites').doc(favoriteId).delete();
  }
}
