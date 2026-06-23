import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'dashboard_screen.dart';
import 'add_promo_screen.dart';
import 'manage_promos_screen.dart';
import 'business_profile_screen.dart';
import 'business_chats_screen.dart';

class BusinessNavbar extends StatelessWidget {
  final int currentIndex;
  final String businessId;

  const BusinessNavbar({
    super.key,
    required this.currentIndex,
    required this.businessId,
  });

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.add_circle_rounded,
    Icons.list_alt_rounded,
    Icons.chat_bubble_rounded,
    Icons.person_rounded,
  ];

  static const _labels = [
    'Dashboard',
    'Ajouter',
    'Gérer',
    'Messages',
    'Profil',
  ];

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;
    Widget screen;
    switch (index) {
      case 0:
        screen = DashboardScreen(businessId: businessId);
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPromoScreen()),
        );
        return;
      case 2:
        screen = ManagePromosScreen(businessId: businessId);
        break;
      case 3:
        screen = BusinessChatsScreen(businessId: businessId);
        break;
      case 4:
        screen = BusinessProfileScreen(businessId: businessId);
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconSz = AppResponsive.navIconSz(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_icons.length, (i) {
              final active = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _navigate(context, i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon-only pill — guaranteed to fit on any screen width
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.primaryGradient : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _icons[i],
                          color: active ? Colors.white : AppColors.textMuted,
                          size: iconSz,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          color: active
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
