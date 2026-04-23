import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory MessageModel.fromDocument(DocumentSnapshot doc) =>
      MessageModel.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
