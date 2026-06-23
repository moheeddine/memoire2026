import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_model.dart';
import '../utils/list_extensions.dart';
import 'notification_manager.dart';
import 'promo_service.dart';

class ReservationService {
  static final _db  = FirebaseFirestore.instance;
  static final _col = _db.collection('reservations');

  static Future<ReservationModel> create({
    required String userId,
    required String promoId,
    required String promoTitle,
    required String businessId,
    required String userName,
    required String phone,
    String message = '',
  }) async {
    // Check & increment reservation count atomically
    final ok = await PromoService.tryIncrementReservations(promoId);
    if (!ok) {
      throw Exception(
          'Cette offre n\'est plus disponible. La limite de réservations a été atteinte.');
    }

    final ref       = _col.doc();
    final expiresAt = DateTime.now().add(const Duration(hours: 24));

    final reservation = ReservationModel(
      id:         ref.id,
      userId:     userId,
      promoId:    promoId,
      promoTitle: promoTitle,
      businessId: businessId,
      userName:   userName,
      phone:      phone,
      message:    message,
      status:     ReservationStatus.pending,
      expiresAt:  expiresAt,
    );

    await ref.set(reservation.toMap());

    // Alert the business side (local notification — same device in demo context)
    NotificationManager.newReservationForBusiness(
      clientName: userName,
      promoTitle: promoTitle,
    );

    return reservation;
  }

  static Stream<List<ReservationModel>> watchUserReservations(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ReservationModel.fromDocument).toList();
          list.sortByDate((r) => r.createdAt);
          return list;
        });
  }

  static Stream<List<ReservationModel>> watchBusinessReservations(
      String businessId) {
    return _col
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ReservationModel.fromDocument).toList();
          list.sortByDate((r) => r.createdAt);
          return list;
        });
  }

  static Future<bool> hasActiveReservation(
      String userId, String promoId) async {
    try {
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .where('promoId', isEqualTo: promoId)
          .get();

      return snap.docs.any((doc) {
        final r = ReservationModel.fromDocument(doc);
        return r.isActive;
      });
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel(String reservationId) async {
    await _col.doc(reservationId).update({'status': 'cancelled'});
  }

  static Future<void> confirm(String reservationId) async {
    await _col.doc(reservationId).update({'status': 'confirmed'});
  }

  static Future<void> complete(String reservationId) async {
    await _col.doc(reservationId).update({'status': 'completed'});
  }

  static Future<void> expire(String reservationId) async {
    await _col.doc(reservationId).update({'status': 'expired'});
  }

  // Batch-marks all overdue pending/confirmed reservations as "expired".
  // Call this on app resume or when a user's reservation list first loads.
  static Future<void> autoExpireForUser(String userId) async {
    try {
      final snap = await _col.where('userId', isEqualTo: userId).get();
      final WriteBatch batch = _db.batch();
      bool hasWork = false;
      for (final doc in snap.docs) {
        final r = ReservationModel.fromDocument(doc);
        if (r.isExpired &&
            (r.status == ReservationStatus.pending ||
                r.status == ReservationStatus.confirmed)) {
          batch.update(doc.reference, {'status': 'expired'});
          hasWork = true;
        }
      }
      if (hasWork) await batch.commit();
    } catch (_) {}
  }

  // Batch-marks overdue reservations as expired for a business.
  // Call once when the business reservation list first loads.
  static Future<void> autoExpireForBusiness(String businessId) async {
    try {
      final snap =
          await _col.where('businessId', isEqualTo: businessId).get();
      final WriteBatch batch = _db.batch();
      bool hasWork = false;
      for (final doc in snap.docs) {
        final r = ReservationModel.fromDocument(doc);
        if (r.isExpired &&
            (r.status == ReservationStatus.pending ||
                r.status == ReservationStatus.confirmed)) {
          batch.update(doc.reference, {'status': 'expired'});
          hasWork = true;
        }
      }
      if (hasWork) await batch.commit();
    } catch (_) {}
  }

  static Future<List<ReservationModel>> getActiveForUser(String userId) async {
    try {
      final snap = await _col.where('userId', isEqualTo: userId).get();
      return snap.docs
          .map(ReservationModel.fromDocument)
          .where((r) => r.isActive)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
