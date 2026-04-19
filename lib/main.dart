import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

// 🔥 IMPORTANT
import 'firebase_options.dart';

// 🧠 THEME
import 'theme_provider.dart';

// SCREENS
import 'business/dashboard_screen.dart';
import 'auth/splash_screen.dart';
import 'auth/onboarding_screen.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'client/home_screen.dart';

/// 🔔 LOCAL NOTIFICATION INSTANCE
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// 🔔 BACKGROUND HANDLER
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔔 Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  /// 🔥 FCM MOBILE ONLY
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    try {
      await initNotifications();
    } catch (e) {
      print("❌ Notification error: $e");
    }
  }

  /// 🔥 THEME PROVIDER
 runApp(
  ChangeNotifierProvider(
    create: (_) => ThemeProvider()..loadTheme(),
    child: MyApp(),
  ),
);
}

/// 🔥 INIT NOTIFICATIONS
Future<void> initNotifications() async {
  if (kIsWeb) return;

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission();
  print("🔐 Permission: ${settings.authorizationStatus}");

  String? token = await messaging.getToken();
  print("🔥 FCM TOKEN: $token");

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 Foreground: ${message.notification?.title}");

    if (message.notification != null) {
      await flutterLocalNotificationsPlugin.show(
        0,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("📲 Notification clicked!");
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'CityOne',
      debugShowCheckedModeBanner: false,

      /// 🌗 THEME SWITCH
      themeMode: themeProvider.currentMode,

      /// 🌞 LIGHT MODE
      theme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.light,
        scaffoldBackgroundColor: Color(0xFFF8FAFC),
        primaryColor: Color(0xFF6366F1),
      ),

      /// 🌙 DARK MODE
      darkTheme: ThemeData(
        fontFamily: 'Poppins',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF0F0F1A),
        primaryColor: Color(0xFF6366F1),
      ),

      home: SplashScreen(),

      routes: {
        "/onboarding": (context) => OnboardingScreen(),
        "/login": (context) => LoginScreen(),
        "/register": (context) => RegisterScreen(),
        "/home": (context) => HomeScreen(),
        "/business_dashboard": (context) {
          final uid = FirebaseAuth.instance.currentUser!.uid;
          return DashboardScreen(businessId: uid);
        },
      },
    );
  }
}