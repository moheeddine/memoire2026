import 'package:cloud_firestore/cloud_firestore.dart';

enum FavoriteType { promo, business, unknown }

class FavoriteModel {
  final String id;
  final String userId;
  final String? promoId;
  final String? businessId;
  final DateTime? createdAt;

  FavoriteModel({
    required this.id,
    required this.userId,
    this.promoId,
    this.businessId,
    this.createdAt,
  }) : assert(
          promoId != null || businessId != null,
          'FavoriteModel requires either promoId or businessId',
        );

  // ─── FACTORY fromMap ──────────────────────────────────────────────────────

  factory FavoriteModel.fromMap(String id, Map<String, dynamic> map) {
    String? promoId    = map['promoId'] as String?;
    String? businessId = map['businessId'] as String?;

    // Backward compat: old format used itemId + type
    if ((promoId == null || promoId.isEmpty) &&
        (businessId == null || businessId.isEmpty)) {
      final itemId = map['itemId'] as String?;
      final type   = map['type'] as String?;
      if (type == 'promo') {
        promoId = itemId;
      } else if (type == 'entreprise' || type == 'business') {
        businessId = itemId;
      } else {
        promoId = itemId; // default to promo
      }
    }

    // Normalize empty strings to null
    if (promoId != null && promoId.isEmpty) promoId = null;
    if (businessId != null && businessId.isEmpty) businessId = null;

    // Safety fallback so assert never fires on malformed data
    if (promoId == null && businessId == null) promoId = 'unknown';

    return FavoriteModel(
      id:         id,
      userId:     map['userId'] as String? ?? '',
      promoId:    promoId,
      businessId: businessId,
      createdAt:  (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory FavoriteModel.fromDocument(DocumentSnapshot doc) {
    return FavoriteModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ─── NAMED CONSTRUCTORS ───────────────────────────────────────────────────

  factory FavoriteModel.forPromo({
    required String id,
    required String userId,
    required String promoId,
  }) {
    return FavoriteModel(id: id, userId: userId, promoId: promoId);
  }

  factory FavoriteModel.forBusiness({
    required String id,
    required String userId,
    required String businessId,
  }) {
    return FavoriteModel(id: id, userId: userId, businessId: businessId);
  }

  // ─── TO MAP (for Firestore write) ─────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'userId':    userId,
      if (promoId != null && promoId!.isNotEmpty)
        'promoId': promoId,
      if (businessId != null && businessId!.isNotEmpty)
        'businessId': businessId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool get isPromoFavorite    =>
      promoId != null && promoId!.isNotEmpty && promoId != 'unknown';

  bool get isBusinessFavorite =>
      businessId != null && businessId!.isNotEmpty;

  FavoriteType get type {
    if (isPromoFavorite)    return FavoriteType.promo;
    if (isBusinessFavorite) return FavoriteType.business;
    return FavoriteType.unknown;
  }

  String get targetId => promoId ?? businessId ?? '';

  // ─── EQUALITY ────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FavoriteModel(id: $id, type: ${type.name}, target: $targetId)';
}
