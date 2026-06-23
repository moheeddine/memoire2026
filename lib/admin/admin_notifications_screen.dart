import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends State<AdminNotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _FilterChip(
                label: 'Toutes',
                active: !_unreadOnly,
                onTap: () => setState(() => _unreadOnly = false),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Non lues',
                active: _unreadOnly,
                onTap: () => setState(() => _unreadOnly = true),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    AppNotificationService.markAllAsRead(kAdminTarget),
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Tout lire'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Notification list ────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppNotificationModel>>(
            stream: AppNotificationService.watchNotifications(kAdminTarget),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary));
              }

              var notifs = snap.data ?? [];
              if (_unreadOnly) {
                notifs = notifs.where((n) => !n.isRead).toList();
              }

              if (notifs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.primary,
                              size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _unreadOnly
                              ? 'Aucune notification non lue'
                              : 'Aucune notification',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Les nouvelles inscriptions et soumissions\napparaîtront ici.',
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: notifs.length,
                itemBuilder: (context, i) =>
                    _NotifCard(notif: notifs[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── FILTER CHIP ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color:    active ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? Colors.transparent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── NOTIFICATION CARD ────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotificationModel notif;
  const _NotifCard({required this.notif});

  IconData get _typeIcon {
    switch (notif.type) {
      case AppNotifType.newBusiness:    return Icons.store_rounded;
      case AppNotifType.promoSubmitted: return Icons.local_offer_rounded;
      case AppNotifType.adminComment:   return Icons.chat_bubble_outline_rounded;
      case AppNotifType.newPromotion:   return Icons.celebration_rounded;
      default:                          return Icons.notifications_rounded;
    }
  }

  Color get _typeColor {
    switch (notif.type) {
      case AppNotifType.newBusiness:    return AppColors.blue;
      case AppNotifType.promoSubmitted: return AppColors.primary;
      case AppNotifType.adminComment:   return AppColors.pink;
      case AppNotifType.newPromotion:   return AppColors.success;
      default:                          return AppColors.textMuted;
    }
  }

  static String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'À l\'instant';
    if (d.inMinutes < 60) return 'Il y a ${d.inMinutes}min';
    if (d.inHours < 24)   return 'Il y a ${d.inHours}h';
    if (d.inDays < 7)     return 'Il y a ${d.inDays}j';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor;

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) =>
          AppNotificationService.deleteNotification(notif.id),
      child: GestureDetector(
        onTap: () {
          if (!notif.isRead) AppNotificationService.markAsRead(notif.id);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead
                  ? AppColors.border
                  : AppColors.primary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: notif.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notif.createdAt),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
