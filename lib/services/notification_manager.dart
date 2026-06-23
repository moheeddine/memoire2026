import 'dart:io';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationManager {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _kEnabled = 'notif_enabled';

  static void _log(String msg) {
    if (kDebugMode) debugPrint('[Notif] $msg');
  }

  // ─── ID RANGES ────────────────────────────────────────────────────────────
  // 100–199 : business alerts
  // 200–299 : client reservation confirmations / expirations
  // 300–399 : flash deals
  // 400–499 : promo-full warnings
  // 500–599 : nearby promos
  // 600–609 : reservation expiry reminders (dynamic)
  // 700–709 : flash deal scheduled alerts (dynamic)
  // 997–999 : test notifications

  // ─── CHANNELS ─────────────────────────────────────────────────────────────

  static const _urgentChannel = AndroidNotificationDetails(
    'cityone_urgent',
    'PromoCity — Alertes urgentes',
    channelDescription: 'Réservations et offres flash urgentes',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableLights: true,
    color: Color(0xFFEC4899),
  );

  static const _infoChannel = AndroidNotificationDetails(
    'cityone_info',
    'PromoCity — Informations',
    channelDescription: 'Mises à jour générales',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _iosDetails    = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
  static const _urgentDetails = NotificationDetails(android: _urgentChannel, iOS: _iosDetails);
  static const _infoDetails   = NotificationDetails(android: _infoChannel,   iOS: _iosDetails);

  // ─── INIT ─────────────────────────────────────────────────────────────────

  /// Initialises the notification plugin. Idempotent — safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;

    // 1 — timezone database + device local zone
    tz.initializeTimeZones();
    try {
      final tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
      _log('timezone set to $tzName');
    } catch (e) {
      _log('timezone fallback to UTC: $e');
    }

    // 2 — plugin initialisation
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // 3 — create Android notification channels explicitly (required on API 26+)
    if (!kIsWeb && Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          'cityone_urgent',
          'PromoCity — Alertes urgentes',
          description: 'Réservations et offres flash urgentes',
          importance: Importance.max,
          playSound: true,
          enableLights: true,
          ledColor: Color(0xFFEC4899),
        ),
      );
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          'cityone_info',
          'PromoCity — Informations',
          description: 'Mises à jour générales',
          importance: Importance.defaultImportance,
        ),
      );
      _log('channels created');
    }

    _initialized = true;
    _log('init complete');
  }

  /// Alias for [init] — satisfies the initialize() contract in the public API.
  static Future<void> initialize() => init();

  static void _onTap(NotificationResponse response) {
    _log('tapped id=${response.id} payload=${response.payload}');
    // Route handling can be wired here via a global navigator key.
  }

  // ─── PERMISSIONS ──────────────────────────────────────────────────────────

  /// Requests OS notification permission.
  /// On Android 13+ (API 33) this shows the system permission dialog.
  /// Returns true if granted.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    await init();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      _log('Android permission granted: $granted');
      return granted;
    }

    if (Platform.isIOS) {
      // DarwinFlutterLocalNotificationsPlugin is Darwin-only and not resolvable
      // on Android builds. Re-initializing with request flags is the
      // cross-platform way to trigger the iOS system permission dialog.
      await _plugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      _log('iOS permission requested');
      return true;
    }

    return true;
  }

  // ─── USER SETTINGS ────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    if (!value) await cancelAll();
  }

  // ─── SHOW (immediate) ─────────────────────────────────────────────────────

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool urgent = false,
    String? payload,
  }) async {
    if (!await isEnabled()) return;
    await init();
    _log('show id=$id "$title"');
    try {
      await _plugin.show(
        id, title, body,
        urgent ? _urgentDetails : _infoDetails,
        payload: payload,
      );
    } catch (e) {
      _log('show failed: $e');
    }
  }

  // ─── SCHEDULE ─────────────────────────────────────────────────────────────

  /// Schedules a notification at [scheduledAt].
  /// Falls back to inexact scheduling if exact alarm permission is not granted
  /// (common on Android 12 devices where SCHEDULE_EXACT_ALARM is restricted).
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    bool urgent = false,
    String? payload,
  }) async {
    if (!await isEnabled()) return;
    await init();

    if (scheduledAt.isBefore(DateTime.now())) return;

    final tzDate = tz.TZDateTime.from(scheduledAt, tz.local);
    _log('schedule id=$id at $scheduledAt (tz=${tz.local.name})');

    // Try exact scheduling first; fall back to inexact on SecurityException.
    try {
      await _plugin.zonedSchedule(
        id, title, body, tzDate,
        urgent ? _urgentDetails : _infoDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      _log('exact schedule ok for id=$id');
    } catch (exactError) {
      _log('exact alarm failed, falling back to inexact: $exactError');
      try {
        await _plugin.zonedSchedule(
          id, title, body, tzDate,
          urgent ? _urgentDetails : _infoDetails,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        _log('inexact schedule ok for id=$id');
      } catch (fallbackError) {
        _log('schedule entirely failed for id=$id: $fallbackError');
      }
    }
  }

  // ─── CANCEL ───────────────────────────────────────────────────────────────

  static Future<void> cancelNotification(int id) async {
    await init();
    await _plugin.cancel(id);
    _log('cancelled id=$id');
  }

  /// Convenience alias kept for internal backward compatibility.
  static Future<void> cancel(int id) => cancelNotification(id);

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
    _log('all cancelled');
  }

  // ─── NAMED EVENTS ─────────────────────────────────────────────────────────

  // --- Client: reservation ---

  static Future<void> reservationCreated({
    required String reservationId,
    required String promoTitle,
    required DateTime expiresAt,
  }) async {
    // Immediate confirmation
    await showNotification(
      id: 200,
      title: 'Réservation confirmée !',
      body: 'Votre réservation "$promoTitle" est valable 24h.',
    );
    // Expiry reminder 1 hour before
    final reminderId = 600 + (reservationId.hashCode.abs() % 9);
    await scheduleNotification(
      id: reminderId,
      title: 'Réservation expire bientôt !',
      body: '"$promoTitle" — expire dans 1h. Rendez-vous sur place.',
      scheduledAt: expiresAt.subtract(const Duration(hours: 1)),
      urgent: true,
      payload: reservationId,
    );
  }

  static Future<void> cancelReservationReminder(String reservationId) async {
    final id = 600 + (reservationId.hashCode.abs() % 9);
    await cancelNotification(id);
  }

  static Future<void> reservationExpiringSoon({required String promoTitle}) =>
      showNotification(
        id: 201,
        title: 'Réservation expire bientôt !',
        body: '"$promoTitle" — moins de 2h restantes, profitez-en !',
        urgent: true,
      );

  // --- Client: flash deals ---

  static Future<void> flashDealEndingSoon({
    required String promoTitle,
    required String timeLeft,
  }) =>
      showNotification(
        id: 300,
        title: '⚡ Flash Deal expire bientôt !',
        body: '"$promoTitle" — Plus que $timeLeft ! Dépêchez-vous.',
        urgent: true,
      );

  static Future<void> scheduleFlashDealAlert({
    required String promoId,
    required String promoTitle,
    required DateTime flashEndTime,
    int minutesBefore = 30,
  }) async {
    final id = 700 + (promoId.hashCode.abs() % 9);
    await scheduleNotification(
      id: id,
      title: '⚡ Flash Deal expire bientôt !',
      body: '"$promoTitle" — Plus que ${minutesBefore}min ! Dépêchez-vous.',
      scheduledAt: flashEndTime.subtract(Duration(minutes: minutesBefore)),
      urgent: true,
      payload: promoId,
    );
  }

  static Future<void> cancelFlashDealAlert(String promoId) async {
    final id = 700 + (promoId.hashCode.abs() % 9);
    await cancelNotification(id);
  }

  // --- Business ---

  static Future<void> newReservationForBusiness({
    required String clientName,
    required String promoTitle,
  }) =>
      showNotification(
        id: 100,
        title: 'Nouvelle réservation !',
        body: '$clientName a réservé "$promoTitle".',
        urgent: true,
      );

  static Future<void> reservationConfirmedByBusiness({
    required String promoTitle,
  }) =>
      showNotification(
        id: 101,
        title: 'Réservation confirmée',
        body: 'Vous avez confirmé la réservation pour "$promoTitle".',
      );

  // --- Promo state ---

  static Future<void> promoAlmostFull({
    required String promoTitle,
    required int spotsLeft,
  }) =>
      showNotification(
        id: 400,
        title: 'Promotion presque complète !',
        body: '"$promoTitle" — Plus que $spotsLeft places disponibles !',
        urgent: true,
      );

  static Future<void> nearbyPromo({
    required String promoTitle,
    required String businessName,
    required String distanceLabel,
    required String promoId,
  }) =>
      showNotification(
        id: 500,
        title: '📍 Promo près de vous !',
        body: '$businessName — $promoTitle à $distanceLabel',
        payload: promoId,
      );

  // ─── TEST ─────────────────────────────────────────────────────────────────

  /// Fires an immediate notification + schedules one 5 seconds later.
  /// Tap the bell icon on the home screen to trigger this.
  static Future<void> showTestNotification() async {
    _log('queuing 5-second test notification');
    await scheduleNotification(
      id: 998,
      title: '✅ Notifications actives',
      body: 'Le système de notifications fonctionne correctement.',
      scheduledAt: DateTime.now().add(const Duration(seconds: 5)),
    );
  }
}
