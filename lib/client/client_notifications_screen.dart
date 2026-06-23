import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/auth_service.dart';
import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/client_navbar.dart';
import 'promo_detail_screen.dart';
import '../services/promo_service.dart';

// ─── CLIENT NOTIFICATIONS SCREEN ─────────────────────────────────────────────

class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() =>
      _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState
    extends State<ClientNotificationsScreen> {
  StreamSubscription<List<AppNotificationModel>>? _sub;
  List<AppNotificationModel> _all     = [];
  _Filter                    _filter  = _Filter.all;
  bool                       _loading = true;
  String?                    _uid;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _uid = AuthService.currentUid;
    if (_uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _sub = AppNotificationService.watchNotifications(_uid!).listen(
      (list) {
        if (mounted) setState(() { _all = list; _loading = false; });
      },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ─── FILTERED LIST ────────────────────────────────────────────────────────

  List<AppNotificationModel> get _filtered {
    switch (_filter) {
      case _Filter.unread:
        return _all.where((n) => !n.isRead).toList();
      case _Filter.promos:
        return _all.where((n) =>
          n.isNewPromotion || n.isExpiringPromotion).toList();
      case _Filter.replies:
        return _all.where((n) => n.isReply || n.isComment).toList();
      case _Filter.all:
        return _all;
    }
  }

  int get _unreadCount => _all.where((n) => !n.isRead).length;

  // ─── ACTIONS ─────────────────────────────────────────────────────────────

  Future<void> _markAllRead() async {
    if (_uid == null) return;
    await AppNotificationService.markAllAsRead(_uid!);
  }

  Future<void> _delete(AppNotificationModel notif) async {
    await AppNotificationService.deleteNotification(notif.id);
  }

  Future<void> _tap(AppNotificationModel notif) async {
    if (!notif.isRead) {
      await AppNotificationService.markAsRead(notif.id);
    }
    if (!mounted) return;
    if (notif.promoId.isNotEmpty) {
      final promo = await PromoService.getPromo(notif.promoId);
      if (!mounted) return;
      if (promo != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PromoDetailScreen(promo: promo),
          ),
        );
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: const ClientNavbar(currentIndex: 4),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_unreadCount > 0)
                  Text(
                    '$_unreadCount non lue${_unreadCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tout lire',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── FILTER BAR ──────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _Filter.values.map((f) {
            final active = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    f.label,
                    style: TextStyle(
                      color: active ? Colors.white : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── BODY ────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return _emptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) => _NotifCard(
        notif: items[i],
        onTap:   () => _tap(items[i]),
        onDelete: () => _delete(items[i]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == _Filter.all
                ? 'Aucune notification'
                : 'Aucune notification ici',
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vos alertes de promotions et réponses\napparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── FILTER ENUM ──────────────────────────────────────────────────────────────

enum _Filter { all, unread, promos, replies }

extension _FilterX on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:     return 'Toutes';
      case _Filter.unread:  return 'Non lues';
      case _Filter.promos:  return 'Promotions';
      case _Filter.replies: return 'Réponses';
    }
  }
}

// ─── NOTIF CARD ───────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotificationModel notif;
  final VoidCallback         onTap;
  final VoidCallback         onDelete;

  const _NotifCard({
    required this.notif,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                color: AppColors.purple.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(notif.createdAt),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
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

  IconData get _icon {
    switch (notif.type) {
      case AppNotifType.newComment:        return Icons.comment_rounded;
      case AppNotifType.newReply:          return Icons.reply_rounded;
      case AppNotifType.newPromotion:      return Icons.local_offer_rounded;
      case AppNotifType.expiringPromotion: return Icons.timer_rounded;
      default:                             return Icons.notifications_rounded;
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case AppNotifType.newComment:        return AppColors.blue;
      case AppNotifType.newReply:          return AppColors.success;
      case AppNotifType.newPromotion:      return AppColors.primary;
      case AppNotifType.expiringPromotion: return AppColors.warning;
      default:                             return AppColors.textMuted;
    }
  }

  static String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'À l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
    if (diff.inHours   < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays    <  7) return 'il y a ${diff.inDays}j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
