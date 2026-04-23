import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'business/dashboard_screen.dart';
import 'auth/splash_screen.dart';
import 'auth/onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'client/home_screen.dart';
import 'client/favorites_screen.dart';
import 'client/profile_screen.dart';
import 'client/chatbot_screen.dart';
import 'client/conversations_screen.dart';
import 'admin/admin_dashboard.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    try {
      await _initNotifications();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }
  }

  runApp(const MyApp());
}

Future<void> _initNotifications() async {
  if (kIsWeb) return;

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  messaging.onTokenRefresh.listen(_saveFcmToken);
  final token = await messaging.getToken();
  if (token != null) await _saveFcmToken(token);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'cityone_channel',
          'CityOne Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  });
}

Future<void> _saveFcmToken(String token) async {
  await AuthService.saveFcmToken(token);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityOne',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
      routes: {
        '/onboarding':         (context) => OnboardingScreen(),
        '/login':              (context) => const LoginScreen(),
        '/register':           (context) => RegisterScreen(),
        '/home':               (context) => HomeScreen(),
        '/favorites':          (context) => const FavoritesScreen(),
        '/profile':            (context) => const ProfileScreen(),
        '/chatbot':            (context) => const ChatbotScreen(),
        '/conversations':      (context) => const ConversationsScreen(),
        '/business_dashboard': (context) =>
            DashboardScreen(businessId: AuthService.currentUid ?? ''),
        '/admin_dashboard':    (context) => const AdminDashboard(),
      },
    );
  }
}
