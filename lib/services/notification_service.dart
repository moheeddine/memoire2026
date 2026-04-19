import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  /// ⚠️ حط Server Key الصحيحة من Firebase (Cloud Messaging)
  static const String serverKey = "AIzaSyDo4CsPqB8BxHtuhTxFep0qUVnJw88ID4g";

  static const String fcmUrl = "https://fcm.googleapis.com/fcm/send";

  /// 🔥 SEND NOTIFICATION TO ALL USERS
  static Future<void> sendNotificationToUsers(String title, String body) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      List<String> tokens = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        /// ✅ SAFE CHECK
        if (data.containsKey('fcmToken') &&
            data['fcmToken'] != null &&
            data['fcmToken'].toString().isNotEmpty) {
          tokens.add(data['fcmToken']);
        }
      }

      /// ❌ إذا ما فما حتى token
      if (tokens.isEmpty) {
        print("❌ No FCM tokens found");
        return;
      }

      print("📲 TOKENS COUNT: ${tokens.length}");

      /// 🔥 SEND REQUEST
      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "key=$serverKey",
        },
        body: jsonEncode({
          "registration_ids": tokens,
          "notification": {"title": title, "body": body},
          "priority": "high",
        }),
      );

      /// 🧪 DEBUG
      print("✅ STATUS: ${response.statusCode}");
      print("📩 RESPONSE: ${response.body}");

      /// ❗ CHECK ERRORS
      if (response.statusCode != 200) {
        print("❌ ERROR SENDING NOTIFICATION");
      }
    } catch (e) {
      print("❌ EXCEPTION: $e");
    }
  }
}
