import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Admin identity card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.primaryShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.40), width: 2),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Administrateur',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('PromoCity Admin Panel',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const AppSectionTitle('Application'),
          const SizedBox(height: 12),

          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            color: AppColors.blue,
            title: 'Version',
            subtitle: 'PromoCity v1.0.0 · Build 1',
          ),
          const _SettingsTile(
            icon: Icons.code_rounded,
            color: AppColors.purple,
            title: 'Stack technique',
            subtitle: 'Flutter 3.24 · Firebase 5.4',
          ),
          const _SettingsTile(
            icon: Icons.cloud_rounded,
            color: AppColors.success,
            title: 'Backend',
            subtitle: 'Firestore · Auth · Cloudinary CDN',
          ),

          const SizedBox(height: 24),
          const AppSectionTitle('Sécurité'),
          const SizedBox(height: 12),

          const _SettingsTile(
            icon: Icons.shield_rounded,
            color: AppColors.primary,
            title: 'Rôle',
            subtitle: 'Administrateur système',
          ),
          const _SettingsTile(
            icon: Icons.lock_outline_rounded,
            color: AppColors.warning,
            title: 'Session',
            subtitle: 'Firebase Auth · Session active',
          ),

          const SizedBox(height: 24),
          const AppSectionTitle('Compte'),
          const SizedBox(height: 12),

          _LogoutTile(context: context),
        ],
      ),
    );
  }
}

// ─── SETTINGS TILE ────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LOGOUT TILE ──────────────────────────────────────────────────────────────

class _LogoutTile extends StatelessWidget {
  final BuildContext context;
  const _LogoutTile({required this.context});

  @override
  Widget build(BuildContext outerContext) {
    return GestureDetector(
      onTap: () async {
        final ok = await showDialog<bool>(
          context: outerContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Se déconnecter ?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text(
              'Vous allez quitter le panneau d\'administration.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Déconnecter',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (ok != true || !outerContext.mounted) return;
        await AuthService.signOut();
        if (outerContext.mounted) {
          Navigator.pushNamedAndRemoveUntil(
              outerContext, AppRoutes.login, (_) => false);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.30)),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Se déconnecter',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text('Retour à la page de connexion',
                      style: TextStyle(
                          color: AppColors.textLight, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.error, size: 20),
          ],
        ),
      ),
    );
  }
}
