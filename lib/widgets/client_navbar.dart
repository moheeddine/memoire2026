import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ClientNavbar extends StatelessWidget {
  final int currentIndex;

  const ClientNavbar({super.key, required this.currentIndex});

  static const _routes = [
    '/home',
    '/favorites',
    '/chatbot',
    '/conversations',
    '/profile',
  ];

  static const _icons = [
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.smart_toy_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  static const _labels = ['Accueil', 'Favoris', 'IA', 'Messages', 'Profil'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(5, (i) {
          final active = currentIndex == i;
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
                  : Icon(_icons[i], color: AppColors.textMuted, size: 22),
            ),
          );
        }),
      ),
    );
  }
}
