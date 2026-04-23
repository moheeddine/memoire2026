import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final String clientId;
  final String businessId;
  final String businessName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool hasUnread;

  const ChatModel({
    required this.id,
    required this.clientId,
    required this.businessId,
    required this.businessName,
    required this.lastMessage,
    this.lastMessageAt,
    this.hasUnread = false,
  });

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatModel(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      businessName: map['businessName'] as String? ?? '',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      hasUnread: map['hasUnread'] as bool? ?? false,
    );
  }

  factory ChatModel.fromDocument(DocumentSnapshot doc) =>
      ChatModel.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
}
