import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/promo_model.dart';
import 'promo_service.dart';

// ─── APP NOTIFICATION SERVICE ─────────────────────────────────────────────────
// Gère la collection Firestore « notifications ».
//
// Règle anti-doublon (dedup) :
//   Chaque notification porte un ID déterministe :
//     company_<commentId>  →  entreprise reçoit une notif par commentaire
//     admin_<commentId>    →  admin    reçoit une notif par commentaire
//     reply_<commentId>    →  client   reçoit une notif par réponse
//   set() est utilisé à la place de add() pour garantir l'idempotence.
//   Le champ isRead n'est PAS écrasé si le document existe déjà.

class AppNotificationService {
  static final _db  = FirebaseFirestore.instance;
  static const _col = 'notifications';

  // ─── STREAMS ──────────────────────────────────────────────────────────────

  /// Notifications d'un utilisateur (entreprise ou client), temps réel.
  /// Index requis : targetUserId ASC + createdAt DESC
  static Stream<List<AppNotificationModel>> watchNotifications(
      String userId) {
    return _db
        .collection(_col)
        .where('targetUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map((s) => s.docs.map(AppNotificationModel.fromDocument).toList());
  }

  /// Notifications destinées à l'administrateur (targetUserId == kAdminTarget).
  static Stream<List<AppNotificationModel>> watchAdminNotifications() {
    return watchNotifications(kAdminTarget);
  }

  /// Nombre de notifications non lues — mis à jour en temps réel.
  /// Index requis : targetUserId ASC + isRead ASC
  static Stream<int> watchUnreadCount(String userId) {
    return _db
        .collection(_col)
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<int> watchAdminUnreadCount() =>
      watchUnreadCount(kAdminTarget);

  // ─── MARK AS READ ─────────────────────────────────────────────────────────

  static Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .collection(_col)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (_) {}
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      final snap = await _db
          .collection(_col)
          .where('targetUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ─── CRÉER : commentaire → notification entreprise ────────────────────────
  // ID déterministe : company_<commentId>
  // Si ce commentaire a déjà notifié l'entreprise → merge:false empêche la réécriture.

  static Future<void> notifyCompanyOnComment({
    required String commentId,
    required String promoId,
    required String promoTitle,
    required String businessId,
    required String clientId,
    required String clientName,
  }) async {
    try {
      final docId = 'company_$commentId';
      final docRef = _db.collection(_col).doc(docId);

      // Anti-doublon : ne crée que si absent
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) return; // déjà créé
        tx.set(docRef, {
          'type':         AppNotifType.newComment.value,
          'targetUserId': businessId,
          'senderId':     clientId,
          'actorName':    clientName,
          'title':        'Nouveau commentaire',
          'commentId':    commentId,
          'promoId':      promoId,
          'promoTitle':   promoTitle,
          'message':
              '$clientName a publié un commentaire sur votre promotion « $promoTitle ».',
          'isRead':    false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ─── CRÉER : réponse → notification client ────────────────────────────────
  // ID déterministe : reply_<commentId>
  // Si l'entreprise réécrit sa réponse → la notification client est rafraîchie
  // (set sans merge : isRead revient à false = nouvelle alerte).

  static Future<void> notifyClientOnReply({
    required String commentId,
    required String promoId,
    required String promoTitle,
    required String clientId,
    required String companyId,
    required String companyName,
  }) async {
    try {
      final docId = 'reply_$commentId';
      await _db.collection(_col).doc(docId).set({
        'type':         AppNotifType.newReply.value,
        'targetUserId': clientId,
        'senderId':     companyId,
        'actorName':    companyName,
        'title':        'Réponse à votre commentaire',
        'commentId':    commentId,
        'promoId':      promoId,
        'promoTitle':   promoTitle,
        'message':
            '$companyName a répondu à votre commentaire sur « $promoTitle ».',
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ─── CRÉER : nouvelle promotion → notification utilisateur ───────────────
  // ID déterministe : promo_new_<promoId>_<userId>
  // Called by the Flutter client as a fallback when Cloud Functions are not
  // yet deployed. In production the Cloud Function onPromoPublished handles this.

  static Future<void> notifyUserOnNewPromo({
    required String userId,
    required String promoId,
    required String promoTitle,
    required String businessId,
    required String businessName,
  }) async {
    try {
      final docId  = 'promo_new_${promoId}_$userId';
      final docRef = _db.collection(_col).doc(docId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) return;
        tx.set(docRef, {
          'type':         AppNotifType.newPromotion.value,
          'targetUserId': userId,
          'senderId':     businessId,
          'actorName':    businessName,
          'title':        '🎉 Nouvelle promotion disponible !',
          'commentId':    '',
          'promoId':      promoId,
          'promoTitle':   promoTitle,
          'message':
              'Découvrez une nouvelle offre publiée par $businessName.',
          'isRead':    false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ─── CRÉER : expiration imminente → notification utilisateur ──────────────
  // ID déterministe : promo_expiring_<promoId>_<userId>

  static Future<void> notifyUserOnExpiringPromo({
    required String userId,
    required String promoId,
    required String promoTitle,
    required String businessId,
    required String businessName,
  }) async {
    try {
      final docId  = 'promo_expiring_${promoId}_$userId';
      final docRef = _db.collection(_col).doc(docId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) return;
        tx.set(docRef, {
          'type':         AppNotifType.expiringPromotion.value,
          'targetUserId': userId,
          'senderId':     businessId,
          'actorName':    businessName,
          'title':        '⏰ Cette promotion expire bientôt !',
          'commentId':    '',
          'promoId':      promoId,
          'promoTitle':   promoTitle,
          'message':
              'Plus que 24 heures pour profiter de cette offre de $businessName.',
          'isRead':    false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ─── ADMIN : nouvelle entreprise inscrite ────────────────────────────────
  // ID déterministe : biz_<businessId>

  static Future<void> notifyAdminOnNewBusiness({
    required String businessId,
    required String businessName,
    required String category,
  }) async {
    try {
      final docId  = 'biz_$businessId';
      final docRef = _db.collection(_col).doc(docId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) return;
        tx.set(docRef, {
          'type':         AppNotifType.newBusiness.value,
          'targetUserId': kAdminTarget,
          'senderId':     businessId,
          'actorName':    businessName,
          'title':        'Nouvelle entreprise inscrite',
          'commentId':    '',
          'promoId':      '',
          'promoTitle':   category,
          'message':      '$businessName ($category) a soumis une demande d\'inscription.',
          'isRead':       false,
          'createdAt':    FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ─── ADMIN : promotion soumise pour modération ────────────────────────────
  // ID déterministe : submit_<promoId>

  static Future<void> notifyAdminOnPromoSubmitted({
    required String promoId,
    required String promoTitle,
    required String businessId,
    required String businessName,
  }) async {
    try {
      final docId  = 'submit_$promoId';
      final docRef = _db.collection(_col).doc(docId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) return;
        tx.set(docRef, {
          'type':         AppNotifType.promoSubmitted.value,
          'targetUserId': kAdminTarget,
          'senderId':     businessId,
          'actorName':    businessName,
          'title':        'Nouvelle promotion à modérer',
          'commentId':    '',
          'promoId':      promoId,
          'promoTitle':   promoTitle,
          'message':      '$businessName a soumis « $promoTitle » pour modération.',
          'isRead':       false,
          'createdAt':    FieldValue.serverTimestamp(),
        });
      });
    } catch (_) {}
  }

  // ─── SUPPRIMER ────────────────────────────────────────────────────────────

  static Future<void> deleteNotification(String id) async {
    try {
      await _db.collection(_col).doc(id).delete();
    } catch (_) {}
  }

  // ─── NAVIGATION ───────────────────────────────────────────────────────────

  /// Charge le PromoModel associé à la notification.
  /// Retourne null si la promo a été supprimée.
  static Future<PromoModel?> getPromoForNotification(
      AppNotificationModel notif) {
    return PromoService.getPromo(notif.promoId);
  }
}
