import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_manager.dart';
import 'utils/app_routes.dart';
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
import 'client/client_notifications_screen.dart';
import 'admin/admin_dashboard.dart';
import 'business/waiting_approval_screen.dart';

// ─── BACKGROUND FCM HANDLER ───────────────────────────────────────────────────
// Must be top-level (not inside a class) for Flutter to register it with the
// platform background isolate.

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) =>
    firebaseMessagingBackgroundHandler(message);

// ─── ENTRY POINT ─────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1 — Firebase core (required before everything else).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2 — Register the background FCM handler as early as possible.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  // 3 — Local notification plugin (schedule / alert).
  if (!kIsWeb) {
    try {
      await NotificationManager.init();
      await NotificationManager.requestPermission();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalNotification init error: $e');
    }

    // 4 — FCM permission + handler setup.
    try {
      await FcmService.initialize();
    } catch (e) {
      if (kDebugMode) debugPrint('FCM init error: $e');
    }
  }

  runApp(const MyApp());
}

// ─── APP ──────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Watch auth state: save FCM token whenever the user signs in.
    AuthService.authState.listen((user) {
      if (user != null && !kIsWeb) {
        FcmService.saveTokenForCurrentUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                  'PromoCity',
      debugShowCheckedModeBanner: false,
      theme:                  AppTheme.theme,
      // Navigator key lets FcmService navigate without a BuildContext.
      navigatorKey:           FcmNavigatorKey.key,
      home:                   const SplashScreen(),
      routes: {
        AppRoutes.onboarding:        (context) => const OnboardingScreen(),
        AppRoutes.login:             (context) => const LoginScreen(),
        AppRoutes.register:          (context) => const RegisterScreen(),
        AppRoutes.home:              (context) => const HomeScreen(),
        AppRoutes.favorites:         (context) => const FavoritesScreen(),
        AppRoutes.profile:           (context) => const ProfileScreen(),
        AppRoutes.chatbot:           (context) => const ChatbotScreen(),
        AppRoutes.conversations:     (context) => const ConversationsScreen(),
        AppRoutes.businessDashboard: (context) =>
            DashboardScreen(businessId: AuthService.currentUid ?? ''),
        AppRoutes.adminDashboard:    (context) => const AdminDashboard(),
        AppRoutes.waiting:               (context) => const WaitingApprovalScreen(),
        AppRoutes.clientNotifications:   (context) => const ClientNotificationsScreen(),
      },
    );
  }
}
