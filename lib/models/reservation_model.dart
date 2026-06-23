import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus { pending, confirmed, cancelled, expired, completed }

class ReservationModel {
  final String id;
  final String userId;
  final String promoId;
  final String promoTitle;
  final String businessId;
  final String userName;
  final String phone;
  final String message;
  final ReservationStatus status;
  final DateTime expiresAt;
  final DateTime? createdAt;

  const ReservationModel({
    required this.id,
    required this.userId,
    required this.promoId,
    required this.promoTitle,
    required this.businessId,
    required this.userName,
    required this.phone,
    this.message = '',
    required this.status,
    required this.expiresAt,
    this.createdAt,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isActive =>
      (status == ReservationStatus.pending ||
          status == ReservationStatus.confirmed) &&
      !isExpired;

  bool get isDone =>
      status == ReservationStatus.completed ||
      status == ReservationStatus.cancelled ||
      isExpired;

  String get timeRemaining {
    if (isExpired) return 'Expirée';
    final diff = expiresAt.difference(DateTime.now());
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return 'Expire dans ${h}h ${m}m';
    return 'Expire dans ${m}m';
  }

  factory ReservationModel.fromMap(String id, Map<String, dynamic> map) {
    return ReservationModel(
      id:         id,
      userId:     map['userId']     as String? ?? '',
      promoId:    map['promoId']    as String? ?? '',
      promoTitle: map['promoTitle'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      userName:   map['userName']   as String? ?? '',
      phone:      map['phone']      as String? ?? '',
      message:    map['message']    as String? ?? '',
      status:     _parseStatus(map['status'] as String?),
      expiresAt:  (map['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
      createdAt:  (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ReservationModel.fromDocument(DocumentSnapshot doc) {
    return ReservationModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() => {
        'userId':     userId,
        'promoId':    promoId,
        'promoTitle': promoTitle,
        'businessId': businessId,
        'userName':   userName,
        'phone':      phone,
        'message':    message,
        'status':     status.name,
        'expiresAt':  Timestamp.fromDate(expiresAt),
        'createdAt':  FieldValue.serverTimestamp(),
      };

  static ReservationStatus _parseStatus(String? v) {
    switch (v) {
      case 'confirmed':  return ReservationStatus.confirmed;
      case 'cancelled':  return ReservationStatus.cancelled;
      case 'expired':    return ReservationStatus.expired;
      case 'completed':  return ReservationStatus.completed;
      default:           return ReservationStatus.pending;
    }
  }
}
