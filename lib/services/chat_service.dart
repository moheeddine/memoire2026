import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../utils/list_extensions.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _chats = _db.collection('chats');

  // Deterministic chat ID: sorted so it's unique per pair
  static String _chatId(String clientId, String businessId) =>
      [clientId, businessId].join('_');

  // Create or fetch a chat between client and business
  static Future<String> getOrCreateChat(
      String clientId, String businessId, String businessName) async {
    final id = _chatId(clientId, businessId);
    final ref = _chats.doc(id);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'clientId': clientId,
        'businessId': businessId,
        'businessName': businessName,
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'hasUnread': false,
      });
    }
    return id;
  }

  static Future<void> sendMessage(
      String chatId, String senderId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = _db.batch();

    final msgRef = _chats.doc(chatId).collection('messages').doc();
    batch.set(msgRef, MessageModel(
      id: msgRef.id,
      senderId: senderId,
      text: trimmed,
    ).toMap());

    batch.update(_chats.doc(chatId), {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'hasUnread': true,
    });

    await batch.commit();
  }

  static Stream<List<MessageModel>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map(MessageModel.fromDocument).toList());
  }

  // All chats where the user is client or business
  static Stream<List<ChatModel>> watchChatsForUser(String userId) {
    return _chats
        .where('clientId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ChatModel.fromDocument).toList();
          list.sortByDate((c) => c.lastMessageAt);
          return list;
        });
  }

  static Stream<List<ChatModel>> watchChatsForBusiness(String businessId) {
    return _chats
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(ChatModel.fromDocument).toList();
          list.sortByDate((c) => c.lastMessageAt);
          return list;
        });
  }

  static Future<void> markRead(String chatId) async {
    try {
      await _chats.doc(chatId).update({'hasUnread': false});
    } catch (_) {}
  }
}
