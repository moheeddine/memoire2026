import 'package:cloud_firestore/cloud_firestore.dart';

// Architecture FCM :
// Le client écrit dans notifications_queue/ → Cloud Function lit et envoie via FCM v1 HTTP API.
// Cela évite d'exposer les credentials service account dans l'application mobile.

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // ─── TOKEN MANAGEMENT ─────────────────────────────────────────────────────

  static Future<void> saveToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken':       token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> clearToken(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (_) {}
  }

  // ─── ENVOI CIBLÉ — UTILISATEUR SPÉCIFIQUE ─────────────────────────────────

  static Future<void> sendToUser(
    String uid, {
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _enqueue({
      'targetType': 'user',
      'targetUid':  uid,
      'title':      title,
      'body':       body,
      'data':       data ?? {},
    });
  }

  // ─── ENVOI PAR TOPIC ──────────────────────────────────────────────────────
  // Topics disponibles : 'clients' | 'businesses' | 'all'

  static Future<void> sendToTopic(
    String topic, {
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _enqueue({
      'targetType':  'topic',
      'targetTopic': topic,
      'title':       title,
      'body':        body,
      'data':        data ?? {},
    });
  }

  // ─── ENVOI PAR RÔLE (tous les users d'un rôle) ────────────────────────────

  static Future<void> sendToRole(
    String role, {
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _enqueue({
      'targetType': 'role',
      'targetRole': role,
      'title':      title,
      'body':       body,
      'data':       data ?? {},
    });
  }

  // ─── HELPERS SÉMANTIQUES ──────────────────────────────────────────────────

  static Future<void> notifyNewPromo(String promoTitle) async {
    await sendToTopic(
      'clients',
      title: '🔥 Nouvelle promotion !',
      body:  promoTitle,
      data:  {'type': 'new_promo'},
    );
  }

  static Future<void> notifyBusinessApproved(String businessUid) async {
    await sendToUser(
      businessUid,
      title: '✅ Compte approuvé !',
      body:  'Votre commerce est maintenant visible sur CityOne.',
      data:  {'type': 'business_approved'},
    );
  }

  static Future<void> notifyBusinessRejected(String businessUid) async {
    await sendToUser(
      businessUid,
      title: '❌ Demande refusée',
      body:  'Votre demande a été refusée. Contactez le support.',
      data:  {'type': 'business_rejected'},
    );
  }

  static Future<void> notifyPromoApproved(
      String businessUid, String promoTitle) async {
    await sendToUser(
      businessUid,
      title: '✅ Promotion approuvée !',
      body:  '"$promoTitle" est maintenant visible par les clients.',
      data:  {'type': 'promo_approved'},
    );
  }

  static Future<void> notifyPromoExpiringSoon(
      String businessUid, String promoTitle) async {
    await sendToUser(
      businessUid,
      title: '⏰ Promotion bientôt expirée',
      body:  '"$promoTitle" expire dans moins de 24h.',
      data:  {'type': 'promo_expiring'},
    );
  }

  // ─── INTERNAL ─────────────────────────────────────────────────────────────

  static Future<void> _enqueue(Map<String, dynamic> payload) async {
    try {
      await _db.collection('notifications_queue').add({
        ...payload,
        'status':    'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
