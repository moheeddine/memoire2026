import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, success, failed }

class PaymentModel {
  final String id;
  final String userId;
  final String promoId;
  final String promoTitle;
  final double amount;
  final PaymentStatus status;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    required this.userId,
    required this.promoId,
    required this.promoTitle,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  factory PaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      promoId: map['promoId'] as String? ?? '',
      promoTitle: map['promoTitle'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(map['status'] as String?),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory PaymentModel.fromDocument(DocumentSnapshot doc) =>
      PaymentModel.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'promoId': promoId,
        'promoTitle': promoTitle,
        'amount': amount,
        'status': status.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static PaymentStatus _parseStatus(String? value) {
    switch (value) {
      case 'success': return PaymentStatus.success;
      case 'failed':  return PaymentStatus.failed;
      default:        return PaymentStatus.pending;
    }
  }
}
