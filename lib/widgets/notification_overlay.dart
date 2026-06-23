import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/promo_model.dart';
import '../services/app_notification_service.dart';
import '../theme/app_theme.dart';
import '../client/promo_detail_screen.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// NotificationWrapper
//
// Enveloppe n'importe quel écran et affiche automatiquement un popup
// temporaire (1 seconde visible) dès qu'une nouvelle notification arrive.
//
// Utilise le système d'Overlay de Flutter pour s'afficher au-dessus de tout.
//
// Usage :
//   NotificationWrapper(userId: uid, child: MyScreen())
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class NotificationWrapper extends StatefulWidget {
  final String userId;
  final Widget child;

  const NotificationWrapper({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  StreamSubscription<List<AppNotificationModel>>? _sub;

  /// Instant de démarrage du listener.
  /// Seules les notifications créées APRÈS cette date déclenchent un popup.
  late final DateTime _startAt;

  /// IDs déjà affichés en popup durant cette session (anti-doublon).
  final Set<String> _shownIds = {};

  /// OverlayEntry courant (null si aucun popup actif).
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    // On soustrait 2 s pour absorber le décalage serveur (serverTimestamp).
    _startAt = DateTime.now().subtract(const Duration(seconds: 2));

    if (widget.userId.isEmpty) return; // unauthenticated — skip subscription
    _sub = AppNotificationService.watchNotifications(widget.userId)
        .listen(_onNotifications);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  // ─── LISTENER ─────────────────────────────────────────────────────────────

  void _onNotifications(List<AppNotificationModel> all) {
    // Filtrer les notifications récentes et non déjà affichées
    final fresh = all.where((n) {
      if (_shownIds.contains(n.id)) return false;
      if (n.isRead) return false;
      final dt = n.createdAt;
      if (dt == null) return false;
      return dt.isAfter(_startAt);
    }).toList();

    if (fresh.isEmpty || !mounted) return;

    // Marquer pour ne pas ré-afficher en cas de re-render du stream
    for (final n in fresh) { _shownIds.add(n.id); }

    // Afficher le popup pour la notification la plus récente
    _showPopup(fresh.first);
  }

  // ─── OVERLAY POPUP ────────────────────────────────────────────────────────

  void _showPopup(AppNotificationModel notif) {
    if (!mounted) return;

    // Retirer un popup éventuel encore actif
    _entry?.remove();
    _entry = null;

    _entry = OverlayEntry(
      builder: (_) => _PopupNotification(
        notif: notif,
        onTap: () {
          _dismissEntry();
          _navigate(notif);
        },
        onDone: _dismissEntry,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _dismissEntry() {
    _entry?.remove();
    _entry = null;
  }

  // ─── NAVIGATION ───────────────────────────────────────────────────────────

  Future<void> _navigate(AppNotificationModel notif) async {
    AppNotificationService.markAsRead(notif.id);

    final PromoModel? promo =
        await AppNotificationService.getPromoForNotification(notif);
    if (promo == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromoDetailScreen(
          promo:             promo,
          // Only scroll to comment for comment-related notification types.
          scrollToCommentId: notif.commentId.isNotEmpty &&
                  (notif.isComment || notif.isReply || notif.isAdminComment)
              ? notif.commentId
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _PopupNotification — le popup lui-même
//
// Chrono :
//   0 ms    → début slide-in  (250 ms)
//   250 ms  → complètement visible
//   1 250 ms → début slide-out (250 ms)
//   1 500 ms → popup retiré
//
// Soit ≥ 1 seconde de lisibilité claire.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PopupNotification extends StatefulWidget {
  final AppNotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDone;

  const _PopupNotification({
    required this.notif,
    required this.onTap,
    required this.onDone,
  });

  @override
  State<_PopupNotification> createState() => _PopupNotificationState();

  static LinearGradient gradient(AppNotifType type) {
    switch (type) {
      case AppNotifType.newReply:
        return AppColors.mainGradient;
      case AppNotifType.adminComment:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        );
      case AppNotifType.newPromotion:
        return const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEF4444)],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        );
      case AppNotifType.expiringPromotion:
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        );
      default:
        return AppColors.primaryGradient;
    }
  }

  static IconData icon(AppNotifType type) {
    switch (type) {
      case AppNotifType.newReply:           return Icons.reply_rounded;
      case AppNotifType.adminComment:       return Icons.shield_rounded;
      case AppNotifType.newPromotion:       return Icons.local_offer_rounded;
      case AppNotifType.expiringPromotion:  return Icons.timer_rounded;
      default:                              return Icons.chat_bubble_rounded;
    }
  }
}

class _PopupNotificationState extends State<_PopupNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Glisse depuis le haut (y = -1.5) vers la position finale (y = 0)
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.8),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    // ── Timeline ──────────────────────────────────────────────────────────
    // Étape 1 : slide-in (250 ms)
    _ctrl.forward();

    // Étape 2 : attendre 4 000 ms puis slide-out (250 ms)
    // Visible time ≥ 4 seconds as required.
    _dismissTimer = Timer(const Duration(milliseconds: 4250), () {
      if (!mounted) return;
      _ctrl.reverse().then((_) => widget.onDone());
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top:   topPadding + 12,
      left:  16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  gradient: _PopupNotification.gradient(widget.notif.type),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ── Icon ───────────────────────────────────────────
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _PopupNotification.icon(widget.notif.type),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Content ────────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize:       MainAxisSize.min,
                        children: [
                          Text(
                            widget.notif.title,
                            style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   14,
                              fontWeight: FontWeight.w800,
                              height:     1.2,
                            ),
                            maxLines:  1,
                            overflow:  TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.notif.message,
                            style: TextStyle(
                              color:    Colors.white.withValues(alpha: 0.88),
                              fontSize: 12,
                              height:   1.4,
                            ),
                            maxLines:  2,
                            overflow:  TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // ── Chevron ────────────────────────────────────────
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// NotificationBell — widget cloche avec badge temps réel
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class NotificationBell extends StatelessWidget {
  final String userId;
  final Color iconColor;

  const NotificationBell({
    super.key,
    required this.userId,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final stream = userId == kAdminTarget
        ? AppNotificationService.watchAdminUnreadCount()
        : AppNotificationService.watchUnreadCount(userId);

    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return GestureDetector(
          onTap: () => _openPanel(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(Icons.notifications_rounded,
                      color: iconColor, size: 22),
                ),
                if (count > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   8,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationPanel(userId: userId),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _NotificationPanel — panneau bottom-sheet liste complète
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _NotificationPanel extends StatelessWidget {
  final String userId;
  const _NotificationPanel({required this.userId});

  Stream<List<AppNotificationModel>> get _stream =>
      userId == kAdminTarget
          ? AppNotificationService.watchAdminNotifications()
          : AppNotificationService.watchNotifications(userId);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 4),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Notifications',
                      style: TextStyle(
                          color:      AppColors.textDark,
                          fontSize:   17,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        AppNotificationService.markAllAsRead(userId),
                    child: const Text('Tout lire',
                        style: TextStyle(
                            color:      AppColors.primary,
                            fontSize:   13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // ── List ──────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<AppNotificationModel>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    );
                  }

                  final all = snap.data ?? [];
                  if (all.isEmpty) return const _EmptyNotifs();

                  return ListView.separated(
                    controller:      sc,
                    itemCount:       all.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppColors.border, indent: 70),
                    itemBuilder: (context, i) => _NotifTile(
                      notif:  all[i],
                      userId: userId,
                      onTap:  () => _navigate(context, all[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigate(
      BuildContext context, AppNotificationModel notif) async {
    if (!notif.isRead) AppNotificationService.markAsRead(notif.id);

    final promo = await AppNotificationService.getPromoForNotification(notif);
    if (promo == null || !context.mounted) return;

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PromoDetailScreen(
          promo:             promo,
          scrollToCommentId: notif.commentId,
        ),
      ),
    );
  }
}

// ─── NOTIFICATION TILE ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotificationModel notif;
  final String userId;
  final VoidCallback onTap;

  const _NotifTile({
    required this.notif,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notif.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: unread
            ? AppColors.primaryLight.withValues(alpha: 0.45)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: _PopupNotification.gradient(notif.type),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_PopupNotification.icon(notif.type),
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: TextStyle(
                      color:      AppColors.textDark,
                      fontSize:   13,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(notif.message,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(_relDate(notif.createdAt),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 11)),
                ],
              ),
            ),

            // Unread dot
            if (unread)
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4, left: 6),
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  String _relDate(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'À l\'instant';
    if (d.inMinutes < 60) return 'Il y a ${d.inMinutes} min';
    if (d.inHours   < 24) return 'Il y a ${d.inHours} h';
    if (d.inDays    < 7)  return 'Il y a ${d.inDays} j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _EmptyNotifs extends StatelessWidget {
  const _EmptyNotifs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text('Aucune notification',
              style: TextStyle(
                  color:      AppColors.textDark,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Les nouvelles activités apparaîtront ici.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
