import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';

class ClientNavbar extends StatefulWidget {
  final int currentIndex;

  const ClientNavbar({super.key, required this.currentIndex});

  @override
  State<ClientNavbar> createState() => _ClientNavbarState();
}

class _ClientNavbarState extends State<ClientNavbar> {
  static const _routes = [
    AppRoutes.home,
    AppRoutes.favorites,
    AppRoutes.chatbot,
    AppRoutes.conversations,
    AppRoutes.profile,
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.smart_toy_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  static const _labels = ['Accueil', 'Favoris', 'IA', 'Messages', 'Profil'];

  StreamSubscription<List<ChatModel>>? _chatSub;
  StreamSubscription<int>?            _notifSub;
  int _unreadChats  = 0;
  int _unreadNotifs = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToChats();
    _subscribeToNotifs();
  }

  void _subscribeToChats() {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    _chatSub = ChatService.watchChatsForUser(uid).listen((chats) {
      final count = chats.where((c) => c.hasUnread).length;
      if (mounted && count != _unreadChats) {
        setState(() => _unreadChats = count);
      }
    });
  }

  void _subscribeToNotifs() {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    _notifSub = AppNotificationService.watchUnreadCount(uid).listen((count) {
      if (mounted && count != _unreadNotifs) {
        setState(() => _unreadNotifs = count);
      }
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 72 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (i) {
          final active = widget.currentIndex == i;
          // Badge: unread chats on Messages tab (3), unread notifs on Profile tab (4)
          final badgeCount = i == 3 ? _unreadChats
                           : i == 4 ? _unreadNotifs
                           : 0;
          final showBadge = badgeCount > 0 && !active;

          return GestureDetector(
            onTap: () {
              if (active) return;
              Navigator.pushReplacementNamed(context, _routes[i]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: active ? 14 : 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: active ? AppColors.primaryGradient : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: active
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icons[i], color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _labels[i],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(_icons[i], color: AppColors.textMuted, size: 22),
                        if (showBadge)
                          Positioned(
                            top: -3,
                            right: -5,
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: Text(
                                badgeCount > 9 ? '9+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          );
        }),
      ),
    );
  }
}
