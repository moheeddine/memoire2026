import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import 'app_notification_service.dart';

class CommentService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'comments';

  // ─── STREAMS ──────────────────────────────────────────────────────────────

  /// Commentaires d'une promo, du plus récent au plus ancien.
  /// Index Firestore requis : promoId ASC + createdAt DESC
  static Stream<List<CommentModel>> watchComments(String promoId) {
    return _db
        .collection(_col)
        .where('promoId', isEqualTo: promoId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDocument).toList());
  }

  /// Tous les commentaires des promos d'une entreprise.
  /// Index Firestore requis : businessId ASC + createdAt DESC
  static Stream<List<CommentModel>> watchByBusiness(String businessId) {
    return _db
        .collection(_col)
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDocument).toList());
  }

  // ─── QUERIES ──────────────────────────────────────────────────────────────

  /// Retourne le commentaire existant d'un utilisateur sur une promo, ou null.
  static Future<CommentModel?> getUserComment(
      String userId, String promoId) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('userId',  isEqualTo: userId)
          .where('promoId', isEqualTo: promoId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return CommentModel.fromDocument(snap.docs.first);
    } catch (_) {
      return null;
    }
  }

  // ─── COMMENT WRITE ────────────────────────────────────────────────────────

  /// Ajoute un commentaire et déclenche une notification pour l'entreprise.
  static Future<void> addComment({
    required String promoId,
    required String businessId,  // pour la notification + requêtes business
    required String promoTitle,  // pour le message de notification
    required String userId,
    required String userName,
    String? userPhoto,
    required String comment,
    required double rating,
  }) async {
    final ref = await _db.collection(_col).add({
      'promoId':    promoId,
      'businessId': businessId,
      'userId':     userId,
      'userName':   userName,
      if (userPhoto != null && userPhoto.isNotEmpty) 'userPhoto': userPhoto,
      'comment':    comment,
      'rating':     rating.clamp(1.0, 5.0),
      'createdAt':  FieldValue.serverTimestamp(),
    });

    // Notifications asynchrones — ne bloquent pas l'UX
    final cid = ref.id;
    AppNotificationService.notifyCompanyOnComment(
      commentId:  cid,
      promoId:    promoId,
      promoTitle: promoTitle,
      businessId: businessId,
      clientId:   userId,
      clientName: userName,
    );
  }

  /// Modifie le texte et la note d'un commentaire existant.
  static Future<void> updateComment(
      String commentId, String newText, double newRating) async {
    await _db.collection(_col).doc(commentId).update({
      'comment':   newText,
      'rating':    newRating.clamp(1.0, 5.0),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime un commentaire (et sa réponse embarquée) — batch atomique.
  static Future<void> deleteComment(String commentId) async {
    await _db.collection(_col).doc(commentId).delete();
  }

  // ─── EMBEDDED REPLY WRITE ─────────────────────────────────────────────────

  /// Ajoute ou remplace la réponse embarquée de l'entreprise.
  /// Déclenche une notification pour le client auteur du commentaire.
  static Future<void> setReply({
    required String commentId,
    required String clientId,    // userId du commentaire → pour notification
    required String companyId,
    required String companyName,
    required String text,
    required String promoId,
    required String promoTitle,
  }) async {
    await _db.collection(_col).doc(commentId).update({
      'reply': {
        'companyId':   companyId,
        'companyName': companyName,
        'text':        text,
        'createdAt':   FieldValue.serverTimestamp(),
      },
    });

    AppNotificationService.notifyClientOnReply(
      commentId:   commentId,
      promoId:     promoId,
      promoTitle:  promoTitle,
      clientId:    clientId,
      companyId:   companyId,
      companyName: companyName,
    );
  }

  /// Modifie le texte d'une réponse existante (mise à jour partielle du map).
  static Future<void> updateReply({
    required String commentId,
    required String newText,
  }) async {
    await _db.collection(_col).doc(commentId).update({
      'reply.text':      newText,
      'reply.updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime la réponse embarquée d'un commentaire.
  static Future<void> removeReply(String commentId) async {
    await _db.collection(_col).doc(commentId).update({
      'reply': FieldValue.delete(),
    });
  }
}
