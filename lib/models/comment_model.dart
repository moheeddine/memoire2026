import 'package:cloud_firestore/cloud_firestore.dart';

// ─── EMBEDDED REPLY ───────────────────────────────────────────────────────────
// Stockée directement dans le document comment (pas de sous-collection).
// Une seule réponse par commentaire, appartenant à l'entreprise propriétaire.

class CommentReply {
  final String companyId;
  final String companyName;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CommentReply({
    required this.companyId,
    required this.companyName,
    required this.text,
    this.createdAt,
    this.updatedAt,
  });

  factory CommentReply.fromMap(Map<String, dynamic> map) {
    return CommentReply(
      companyId:   map['companyId']   as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      text:        map['text']        as String? ?? '',
      createdAt:   (map['createdAt']  as Timestamp?)?.toDate(),
      updatedAt:   (map['updatedAt']  as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId':   companyId,
        'companyName': companyName,
        'text':        text,
        'createdAt':   FieldValue.serverTimestamp(),
      };

  bool get isEdited => updatedAt != null;
}

// ─── LEGACY SUB-COLLECTION REPLY MODEL ───────────────────────────────────────
// Conservé pour la rétrocompatibilité avec le code existant.

class ReplyModel {
  final String id;
  final String commentId;
  final String businessId;
  final String businessName;
  final String message;
  final DateTime? createdAt;

  const ReplyModel({
    required this.id,
    required this.commentId,
    required this.businessId,
    required this.businessName,
    required this.message,
    this.createdAt,
  });

  factory ReplyModel.fromMap(
      String id, String commentId, Map<String, dynamic> map) {
    return ReplyModel(
      id:           id,
      commentId:    commentId,
      businessId:   map['businessId']   as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      message:      map['message']      as String? ?? '',
      createdAt:    (map['createdAt']   as Timestamp?)?.toDate(),
    );
  }

  factory ReplyModel.fromDocument(DocumentSnapshot doc, String commentId) {
    return ReplyModel.fromMap(
      doc.id,
      commentId,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() => {
        'businessId':   businessId,
        'businessName': businessName,
        'message':      message,
        'createdAt':    FieldValue.serverTimestamp(),
      };
}

// ─── COMMENT MODEL ────────────────────────────────────────────────────────────

class CommentModel {
  final String id;
  final String promoId;
  final String businessId; // propriétaire de la promo → notification + requêtes
  final String userId;
  final String userName;
  final String? userPhoto;
  final String comment;
  final double rating;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Réponse embarquée de l'entreprise (null = pas encore répondu)
  final CommentReply? reply;

  const CommentModel({
    required this.id,
    required this.promoId,
    required this.businessId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.rating,
    this.userPhoto,
    this.createdAt,
    this.updatedAt,
    this.reply,
  });

  // ─── FACTORY ──────────────────────────────────────────────────────────────

  factory CommentModel.fromMap(String id, Map<String, dynamic> map) {
    final replyMap = map['reply'] as Map<String, dynamic>?;
    return CommentModel(
      id:         id,
      promoId:    map['promoId']    as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      userId:     map['userId']     as String? ?? '',
      userName:   map['userName']   as String? ?? 'Utilisateur',
      userPhoto:  map['userPhoto']  as String?,
      comment:    map['comment']    as String? ?? '',
      rating:     (map['rating']    as num?)?.toDouble() ?? 0.0,
      createdAt:  (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt:  (map['updatedAt'] as Timestamp?)?.toDate(),
      reply:      replyMap != null ? CommentReply.fromMap(replyMap) : null,
    );
  }

  factory CommentModel.fromDocument(DocumentSnapshot doc) {
    return CommentModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toMap() => {
        'promoId':    promoId,
        'businessId': businessId,
        'userId':     userId,
        'userName':   userName,
        if (userPhoto != null) 'userPhoto': userPhoto,
        'comment':    comment,
        'rating':     rating,
        'createdAt':  FieldValue.serverTimestamp(),
      };

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  bool get isEdited  => updatedAt != null;
  bool get hasReply  => reply != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CommentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
