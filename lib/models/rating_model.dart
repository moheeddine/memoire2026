import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String userId;
  final String businessId;
  final double score; // 1.0 – 5.0
  final DateTime? createdAt;

  const RatingModel({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.score,
    this.createdAt,
  });

  factory RatingModel.fromMap(String id, Map<String, dynamic> map) {
    return RatingModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory RatingModel.fromDocument(DocumentSnapshot doc) =>
      RatingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'businessId': businessId,
        'score': score,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
