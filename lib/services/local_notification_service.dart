import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _androidChannel = AndroidNotificationDetails(
    'cityone_local',
    'CityOne Local',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );
    _initialized = true;
  }

  static Future<void> _show(int id, String title, String body) async {
    await init();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: _androidChannel),
    );
  }

  static Future<void> showNewPromo(String title, String businessName) =>
      _show(1, 'Nouvelle promo !', '$title chez $businessName');

  static Future<void> showNearbyPromo(String title, String distance) =>
      _show(2, 'Promo près de vous', '$title à $distance');

  static Future<void> showFavoriteBusinessUpdate(
          String businessName, String message) =>
      _show(3, businessName, message);

  static Future<void> showPromoApproved(String title) =>
      _show(4, 'Promo approuvée !', '"$title" est maintenant visible.');

  static Future<void> showBusinessApproved(String name) =>
      _show(5, 'Compte approuvé !', 'Bienvenue $name, votre commerce est actif.');

  static Future<void> showNewMessage(String from) =>
      _show(6, 'Nouveau message', 'Message de $from');
}
