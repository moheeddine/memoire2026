import 'package:cloud_firestore/cloud_firestore.dart';

// ─── SENTINEL ─────────────────────────────────────────────────────────────────
// All admin-targeted notifications use this constant as targetUserId.
const kAdminTarget = '__admin__';

// ─── TYPE ─────────────────────────────────────────────────────────────────────

enum AppNotifType {
  // Comment system
  newComment,
  newReply,
  adminComment,
  // Promotion system
  newPromotion,
  expiringPromotion,
  // Admin-only events
  newBusiness,
  promoSubmitted,
  // Fallback
  unknown,
}

AppNotifType _parseType(String? v) {
  switch (v) {
    case 'new_comment':         return AppNotifType.newComment;
    case 'new_reply':           return AppNotifType.newReply;
    case 'admin_comment':       return AppNotifType.adminComment;
    case 'new_promotion':       return AppNotifType.newPromotion;
    case 'expiring_promotion':  return AppNotifType.expiringPromotion;
    case 'new_business':        return AppNotifType.newBusiness;
    case 'promo_submitted':     return AppNotifType.promoSubmitted;
    default:                    return AppNotifType.unknown;
  }
}

extension AppNotifTypeX on AppNotifType {
  String get value {
    switch (this) {
      case AppNotifType.newComment:        return 'new_comment';
      case AppNotifType.newReply:          return 'new_reply';
      case AppNotifType.adminComment:      return 'admin_comment';
      case AppNotifType.newPromotion:      return 'new_promotion';
      case AppNotifType.expiringPromotion: return 'expiring_promotion';
      case AppNotifType.newBusiness:       return 'new_business';
      case AppNotifType.promoSubmitted:    return 'promo_submitted';
      default:                             return 'unknown';
    }
  }
}

// ─── MODEL ────────────────────────────────────────────────────────────────────

class AppNotificationModel {
  final String id;
  final AppNotifType type;

  /// UID of the recipient (or kAdminTarget for admin notifications).
  final String targetUserId;

  /// UID of the sender (client, business, or 'system' for automated ones).
  final String senderId;

  /// Display name of the sender.
  final String actorName;

  /// Title shown in the popup and panel.
  final String title;

  /// Navigation context.
  final String commentId;  // empty string for promo-only notifications
  final String promoId;
  final String promoTitle;

  /// Message body.
  final String message;

  final bool isRead;
  final DateTime? createdAt;

  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.targetUserId,
    required this.senderId,
    required this.actorName,
    required this.title,
    required this.commentId,
    required this.promoId,
    required this.promoTitle,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  // ─── FACTORY ────────────────────────────────────────────────────────────────

  factory AppNotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return AppNotificationModel(
      id:           id,
      type:         _parseType(map['type'] as String?),
      targetUserId: map['targetUserId'] as String? ?? '',
      senderId:     map['senderId']     as String? ?? '',
      actorName:    map['actorName']    as String? ?? '',
      title:        map['title']        as String? ?? '',
      commentId:    map['commentId']    as String? ?? '',
      promoId:      map['promoId']      as String? ?? '',
      promoTitle:   map['promoTitle']   as String? ?? '',
      message:      map['message']      as String? ?? '',
      isRead:       map['isRead']       as bool?   ?? false,
      createdAt:    (map['createdAt']   as Timestamp?)?.toDate(),
    );
  }

  factory AppNotificationModel.fromDocument(DocumentSnapshot doc) {
    return AppNotificationModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  bool get isComment          => type == AppNotifType.newComment;
  bool get isReply            => type == AppNotifType.newReply;
  bool get isAdminComment     => type == AppNotifType.adminComment;
  bool get isNewPromotion     => type == AppNotifType.newPromotion;
  bool get isExpiringPromotion => type == AppNotifType.expiringPromotion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotificationModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
