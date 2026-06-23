import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_manager.dart';
import '../services/promo_service.dart';
import '../client/promo_detail_screen.dart';

// ─── BACKGROUND HANDLER ───────────────────────────────────────────────────────
// Must be a top-level function (not a method) for Flutter to register it.

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by main() before this is called.
  // For notification-type FCM messages the OS shows the notification
  // automatically. For data-only messages you can add handling here.
  if (kDebugMode) {
    debugPrint('[FCM] background message: ${message.messageId}');
  }
}

// ─── FCM SERVICE ──────────────────────────────────────────────────────────────
//
// Lifecycle:
//   1. FcmService.initialize() — call once at app startup (before runApp).
//   2. FcmService.saveTokenForCurrentUser() — call after the user signs in.
//   3. Internally listens for token refresh and updates Firestore automatically.
//
// Navigation:
//   Requires MyApp.navigatorKey to be set on MaterialApp before tapping any
//   FCM notification that should open PromoDetailScreen.

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;

  // ─── INIT ─────────────────────────────────────────────────────────────────

  /// Call once from main(), after Firebase.initializeApp().
  static Future<void> initialize() async {
    if (kIsWeb) return;

    // 1 — Request OS permission (iOS / Android 13+).
    await _messaging.requestPermission(
      alert:       true,
      badge:       true,
      sound:       true,
      provisional: false,
    );

    // 2 — Foreground presentation options (iOS: show banner even when app open).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false, // We use our own in-app popup via Firestore stream.
      badge: true,
      sound: false,
    );

    // 3 — Foreground messages (app is open).
    //     The Firestore stream already shows an in-app popup. We only show a
    //     local notification for promo-type messages so the user has a system
    //     notification in the tray as well.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 4 — Background tap (app was in background, user taps the system notif).
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 5 — Terminated tap (app was closed, user taps the system notif).
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Post-frame to ensure the navigator is mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMessage(initial);
      });
    }

    // 6 — Token refresh.
    _messaging.onTokenRefresh.listen((newToken) {
      final uid = AuthService.currentUid;
      if (uid != null) {
        AuthService.saveFcmToken(uid, newToken);
      }
    });
  }

  /// Call right after the user signs in so the token is stored in Firestore.
  static Future<void> saveTokenForCurrentUser() async {
    if (kIsWeb) return;
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await AuthService.saveFcmToken(uid, token);
        if (kDebugMode) debugPrint('[FCM] token saved for $uid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] token save error: $e');
    }
  }

  /// Clears the FCM token from Firestore on sign-out so the user no longer
  /// receives push notifications on this device.
  static Future<void> clearTokenOnSignOut() async {
    if (kIsWeb) return;
    final uid = AuthService.currentUid;
    if (uid == null) return;
    try {
      await AuthService.saveFcmToken(uid, '');
      await _messaging.deleteToken();
    } catch (_) {}
  }

  // ─── MESSAGE HANDLERS ─────────────────────────────────────────────────────

  static void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] foreground: ${message.notification?.title}');
    }
    // Show a local system notification for promo events so it lands in the
    // device's notification tray (the in-app Firestore popup also appears).
    final type = message.data['type'] as String? ?? '';
    if (type == 'new_promotion' || type == 'expiring_promotion') {
      final title = message.notification?.title ?? 'PromoCity';
      final body  = message.notification?.body  ?? '';
      final id    = message.hashCode & 0x7FFFFFFF;
      NotificationManager.showNotification(
        id:      id,
        title:   title,
        body:    body,
        urgent:  type == 'expiring_promotion',
        payload: message.data['promoId'] as String?,
      );
    }
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] opened from background: ${message.messageId}');
    }
    _handleMessage(message);
  }

  static void _handleMessage(RemoteMessage message) {
    final promoId = message.data['promoId'] as String?;
    if (promoId == null || promoId.isEmpty) return;
    _navigateToPromo(promoId);
  }

  static Future<void> _navigateToPromo(String promoId) async {
    try {
      final promo = await PromoService.getPromo(promoId);
      if (promo == null) return;

      // FcmNavigatorKey is set on MaterialApp in main.dart.
      final nav = FcmNavigatorKey.key.currentState;
      if (nav == null) return;

      nav.push(MaterialPageRoute(
        builder: (_) => PromoDetailScreen(promo: promo),
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] navigate error: $e');
    }
  }
}

// ─── NAVIGATOR KEY ────────────────────────────────────────────────────────────
// A static GlobalKey stored here so FcmService can navigate without a context.

class FcmNavigatorKey {
  FcmNavigatorKey._();
  static final key = GlobalKey<NavigatorState>();
}
