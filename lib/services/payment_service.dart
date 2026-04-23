import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';

class PaymentService {
  static final _db = FirebaseFirestore.instance;
  static final _col = _db.collection('payments');

  // Simulates a payment: 90% success rate
  static Future<PaymentModel> processPayment({
    required String userId,
    required String promoId,
    required String promoTitle,
    required double amount,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    final success = Random().nextDouble() < 0.9;
    final status = success ? PaymentStatus.success : PaymentStatus.failed;

    final ref = _col.doc();
    final payment = PaymentModel(
      id: ref.id,
      userId: userId,
      promoId: promoId,
      promoTitle: promoTitle,
      amount: amount,
      status: status,
    );

    await ref.set(payment.toMap());
    return payment;
  }

  static Stream<List<PaymentModel>> watchUserPayments(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(PaymentModel.fromDocument).toList();
          list.sort((a, b) {
            final ta = a.createdAt;
            final tb = b.createdAt;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
          return list;
        });
  }

  static Future<List<PaymentModel>> getUserPayments(String userId) async {
    try {
      final snap = await _col
          .where('userId', isEqualTo: userId)
          .get();
      final list = snap.docs.map(PaymentModel.fromDocument).toList();
      list.sort((a, b) {
        final ta = a.createdAt;
        final tb = b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
      return list;
    } catch (_) {
      return [];
    }
  }
}
