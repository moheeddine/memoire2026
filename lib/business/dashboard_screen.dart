import 'package:flutter/material.dart';
import '../models/promo_model.dart';
import '../models/reservation_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/notification_manager.dart';
import '../services/promo_service.dart';
import '../services/reservation_service.dart';
import '../theme/app_theme.dart';
import '../utils/promo_expiration_checker.dart';
import '../utils/responsive.dart';
import '../widgets/notification_overlay.dart';
import 'business_navbar.dart';
import 'business_profile_screen.dart';
import 'add_promo_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String businessId;
  const DashboardScreen({super.key, required this.businessId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  String get _resolvedId =>
      widget.businessId.isNotEmpty
          ? widget.businessId
          : (AuthService.currentUid ?? '');

  bool _almostFullNotified = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    NotificationManager.init();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _resolvedId;

    if (id.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Text(
            'Session expirée — veuillez vous reconnecter.',
            style: TextStyle(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return NotificationWrapper(
      userId: id,
      child: Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: BusinessNavbar(currentIndex: 0, businessId: id),
      body: StreamBuilder<List<PromoModel>>(
        stream: PromoService.watchByBusiness(id),
        builder: (context, promoSnap) {
          final promos       = promoSnap.data ?? [];
          // Seules les promos actives sont affichées dans le dashboard
          final activePromos = promos.where((p) => p.isEffectivelyActive).toList();
          final totalViews        = promos.fold<int>(0, (s, p) => s + p.views);
          final totalClicks       = promos.fold<int>(0, (s, p) => s + p.clicks);
          final totalUsed         = promos.fold<int>(0, (s, p) => s + p.used);
          final totalReservations = promos.fold<int>(0, (s, p) => s + p.currentReservations);
          final activeCount  = activePromos.length;
          final expiredCount = promos
              .where((p) =>
                  p.isExpired ||
                  p.status == PromoStatus.expired ||
                  p.status == PromoStatus.ended)
              .length;

          // Notify when any promo is almost full (≤5 spots remaining, once per session)
          if (!_almostFullNotified) {
            for (final p in promos) {
              if (PromoExpirationChecker.isAlmostFull(p) && !p.isLimitReached) {
                _almostFullNotified = true;
                final spotsLeft = (p.maxReservations ?? 0) - p.currentReservations;
                NotificationManager.promoAlmostFull(
                  promoTitle: p.title,
                  spotsLeft:  spotsLeft,
                );
                break;
              }
            }
          }

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              // ── Business header ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: StreamBuilder(
                  stream: BusinessService.watchBusiness(id),
                  builder: (context, bizSnap) => _Header(
                    name:       bizSnap.data?.name     ?? 'Mon entreprise',
                    category:   bizSnap.data?.category ?? '',
                    businessId: id,
                  ),
                ),
              ),

              // ── KPI scroll row ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _KpiScrollRow(
                    totalViews:        totalViews,
                    totalClicks:       totalClicks,
                    totalReservations: totalReservations,
                    totalUsed:         totalUsed,
                    activeCount:       activeCount,
                    expiredCount:      expiredCount,
                  ),
                ),
              ),

              // ── Pinned tab bar ──────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabCtrl,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2.5,
                    dividerColor: AppColors.border,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'Promos (${activePromos.length})'),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_rounded, size: 13),
                            SizedBox(width: 4),
                            Text('Réservations'),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insights_rounded, size: 13),
                            SizedBox(width: 4),
                            Text('Analytiques'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                _PromosTab(
                  promos:     activePromos,
                  businessId: id,
                  isLoading:  promoSnap.connectionState ==
                      ConnectionState.waiting,
                ),
                _ReservationsTab(businessId: id),
                _AnalyticsTab(promos: promos),
              ],
            ),
          );
        },
      ),
    ), // Scaffold
    ); // NotificationWrapper
  }
}

// ─── TAB BAR DELEGATE ─────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: AppColors.bg,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => false;
}

// ─── HEADER ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final String category;
  final String businessId;

  const _Header({
    required this.name,
    required this.category,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    final small   = AppResponsive.isSmall(context);
    final avatarSz = small ? 42.0 : 48.0;
    final iconSz   = small ? 21.0 : 24.0;
    final nameSz   = small ? 16.0 : 18.0;

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.mainGradient),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              AppResponsive.hPad(context), 16,
              AppResponsive.hPad(context), 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: avatarSz,
                    height: avatarSz,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Icon(Icons.store_rounded,
                        color: Colors.white, size: iconSz),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: nameSz,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (category.isNotEmpty)
                          Text(
                            category,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: small ? 11.0 : 12.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // ── Notification bell ───────────────────────────────
                  NotificationBell(userId: businessId),
                  const SizedBox(width: 8),

                  // ── Profile button ──────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BusinessProfileScreen(businessId: businessId),
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tableau de bord · ${DateTime.now().year}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── KPI SCROLL ROW ───────────────────────────────────────────────────────────

class _KpiScrollRow extends StatelessWidget {
  final int totalViews;
  final int totalClicks;
  final int totalReservations;
  final int totalUsed;
  final int activeCount;
  final int expiredCount;

  const _KpiScrollRow({
    required this.totalViews,
    required this.totalClicks,
    required this.totalReservations,
    required this.totalUsed,
    required this.activeCount,
    required this.expiredCount,
  });

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _KpiCard(_fmt(totalViews),        'Vues',          Icons.visibility_rounded,     AppColors.info),
          _KpiCard(_fmt(totalClicks),       'Clics',         Icons.ads_click_rounded,      const Color(0xFF0EA5E9)),
          _KpiCard(_fmt(totalReservations), 'Réservations',  Icons.bookmark_rounded,       AppColors.purple),
          _KpiCard(_fmt(totalUsed),         'Utilisations',  Icons.check_circle_rounded,   AppColors.success),
          _KpiCard(activeCount.toString(),  'Actives',       Icons.local_offer_rounded,    AppColors.primary),
          _KpiCard(expiredCount.toString(), 'Expirées',      Icons.timer_off_rounded,      AppColors.error),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    color;

  const _KpiCard(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Live',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── PROMOS TAB ───────────────────────────────────────────────────────────────

class _PromosTab extends StatelessWidget {
  final List<PromoModel> promos;
  final String businessId;
  final bool isLoading;

  const _PromosTab({
    required this.promos,
    required this.businessId,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (promos.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppResponsive.hPad(context)),
        child: _EmptyState(businessId: businessId),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(AppResponsive.hPad(context)),
      itemCount: promos.length,
      itemBuilder: (context, i) =>
          _PromoTile(promo: promos[i], businessId: businessId),
    );
  }
}

// ─── RESERVATIONS TAB ─────────────────────────────────────────────────────────

class _ReservationsTab extends StatefulWidget {
  final String businessId;
  const _ReservationsTab({required this.businessId});

  @override
  State<_ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<_ReservationsTab> {
  bool _notified      = false;
  bool _autoExpired   = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReservationModel>>(
      stream: ReservationService.watchBusinessReservations(widget.businessId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        final reservations = snap.data ?? [];

        // Mark overdue reservations as expired in Firestore (once per session).
        if (!_autoExpired && snap.data != null) {
          _autoExpired = true;
          ReservationService.autoExpireForBusiness(widget.businessId);
        }

        // Fire local notification for the first pending reservation found
        if (!_notified) {
          final firstPending = reservations
              .where((r) =>
                  r.status == ReservationStatus.pending && !r.isExpired)
              .toList();
          if (firstPending.isNotEmpty) {
            _notified = true;
            NotificationManager.newReservationForBusiness(
              clientName: firstPending.first.userName,
              promoTitle: firstPending.first.promoTitle,
            );
          }
        }

        if (reservations.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 56, color: AppColors.textLight),
                  SizedBox(height: 16),
                  Text('Aucune réservation',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                    'Les réservations de vos clients\napparaîtront ici',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        // Group: active first, then done
        final active = reservations
            .where((r) => !r.isDone)
            .toList();
        final done = reservations
            .where((r) => r.isDone)
            .toList();

        return ListView(
          padding: EdgeInsets.all(AppResponsive.hPad(context)),
          children: [
            if (active.isNotEmpty) ...[
              _sectionHeader(
                  'En cours (${active.length})', AppColors.primary),
              const SizedBox(height: 10),
              ...active.map((r) => _ReservationCard(reservation: r)),
              const SizedBox(height: 16),
            ],
            if (done.isNotEmpty) ...[
              _sectionHeader('Historique (${done.length})', AppColors.textMuted),
              const SizedBox(height: 10),
              ...done.map((r) => _ReservationCard(reservation: r)),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ─── RESERVATION CARD ─────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  const _ReservationCard({required this.reservation});

  Color get _statusColor {
    switch (reservation.status) {
      case ReservationStatus.confirmed:  return AppColors.success;
      case ReservationStatus.cancelled:  return AppColors.error;
      case ReservationStatus.completed:  return AppColors.primary;
      case ReservationStatus.expired:    return AppColors.textLight;
      default:                           return AppColors.warning;
    }
  }

  String get _statusLabel {
    switch (reservation.status) {
      case ReservationStatus.confirmed:  return 'Confirmée';
      case ReservationStatus.cancelled:  return 'Annulée';
      case ReservationStatus.completed:  return 'Terminée';
      case ReservationStatus.expired:    return 'Expirée';
      default:                           return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = reservation.userName.isNotEmpty
        ? reservation.userName[0].toUpperCase()
        : '?';
    final hoursLeft =
        reservation.expiresAt.difference(DateTime.now()).inHours;
    final timeColor =
        reservation.isExpired || hoursLeft < 2
            ? AppColors.error
            : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: reservation.isDone
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Main info row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: reservation.isDone ? null : AppColors.primaryGradient,
                    color:    reservation.isDone ? AppColors.surface : null,
                    border:   reservation.isDone
                        ? Border.all(color: AppColors.border, width: 1.5)
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color:      reservation.isDone ? AppColors.textMuted : Colors.white,
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + promo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reservation.userName,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel,
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reservation.promoTitle,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            reservation.phone,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Footer: timing + actions ────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 12, color: timeColor),
                    const SizedBox(width: 4),
                    Text(
                      reservation.timeRemaining,
                      style: TextStyle(
                          color: timeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (reservation.createdAt != null)
                      Text(
                        _fmtDate(reservation.createdAt!),
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 10),
                      ),
                  ],
                ),

                // Optional message
                if (reservation.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.format_quote_rounded,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            reservation.message,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons (only for non-done reservations)
                if (!reservation.isDone) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (reservation.status ==
                          ReservationStatus.pending) ...[
                        Expanded(
                          child: _ActionBtn(
                            label: 'Confirmer',
                            icon: Icons.check_rounded,
                            color: AppColors.success,
                            onTap: () => _confirm(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: _ActionBtn(
                          label: 'Terminer',
                          icon: Icons.task_alt_rounded,
                          color: AppColors.primary,
                          onTap: () => _complete(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionBtn(
                          label: 'Annuler',
                          icon: Icons.close_rounded,
                          color: AppColors.error,
                          onTap: () => _cancel(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    await ReservationService.confirm(reservation.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation confirmée'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cancel(BuildContext context) async {
    await ReservationService.cancel(reservation.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation annulée'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _complete(BuildContext context) async {
    await ReservationService.complete(reservation.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation marquée comme terminée'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

// ─── ACTION BUTTON ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String businessId;
  const _EmptyState({required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Illustration circle
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              gradient: AppColors.softGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.local_offer_rounded,
                  color: AppColors.primary, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune promotion active',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Créez votre première offre pour\nattirer des clients près de vous',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPromoScreen()),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Créer une promotion',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _TipBadge(Icons.visibility_rounded,   'Plus de visibilité'),
              _TipBadge(Icons.people_rounded,        'Plus de clients'),
              _TipBadge(Icons.trending_up_rounded,   'Plus de revenus'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── TIP BADGE ────────────────────────────────────────────────────────────────

class _TipBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _TipBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PROMO TILE ───────────────────────────────────────────────────────────────

class _PromoTile extends StatelessWidget {
  final PromoModel promo;
  final String businessId;

  const _PromoTile({required this.promo, required this.businessId});

  Color get _statusColor {
    if (promo.status == PromoStatus.approved) {
      if (promo.isExpired)      return AppColors.error;
      if (promo.isLimitReached) return AppColors.info;
      if (promo.isEffectivelyActive) return AppColors.success;
    }
    switch (promo.status) {
      case PromoStatus.approved: return AppColors.success;
      case PromoStatus.rejected: return AppColors.error;
      case PromoStatus.ended:    return AppColors.textLight;
      default:                   return AppColors.warning;
    }
  }

  String get _statusLabel {
    if (promo.status == PromoStatus.approved) {
      if (promo.isExpired)           return 'Expirée';
      if (promo.isLimitReached)      return 'Complète';
      if (promo.isEffectivelyActive) return 'Active';
    }
    switch (promo.status) {
      case PromoStatus.approved: return 'Approuvée';
      case PromoStatus.rejected: return 'Rejetée';
      case PromoStatus.ended:    return 'Terminée';
      default:                   return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = promo.imageUrls.isNotEmpty;
    final thumbSz  = (MediaQuery.sizeOf(context).width * 0.20).clamp(65.0, 80.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(13)),
            child: hasImage
                ? Image.network(promo.imageUrls.first,
                    width: thumbSz,
                    height: thumbSz,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(thumbSz))
                : _fallback(thumbSz),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promo.title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${promo.views}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      const Icon(Icons.ads_click_rounded,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${promo.clicks}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      const Icon(Icons.bookmark_rounded,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${promo.used}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  if (promo.isFlashDeal)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⚡ Flash Deal',
                          style: TextStyle(
                              color: Color(0xFFF97316),
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  // Reservation progress bar
                  if (promo.maxReservations != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Réservations',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 10),
                              ),
                              Text(
                                '${promo.currentReservations}/${promo.maxReservations}',
                                style: TextStyle(
                                  color: promo.isLimitReached
                                      ? AppColors.error
                                      : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (promo.currentReservations /
                                      promo.maxReservations!)
                                  .clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: AppColors.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                promo.isLimitReached
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Expiration countdown
                  Builder(builder: (_) {
                    final cd =
                        PromoExpirationChecker.expirationCountdown(promo);
                    if (cd == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cd == 'Expirée'
                              ? AppColors.error.withValues(alpha: 0.1)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⏳ $cd',
                          style: TextStyle(
                            color: cd == 'Expirée'
                                ? AppColors.error
                                : const Color(0xFFF97316),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '-${promo.discount}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 28),
      );
}

// ─── ANALYTICS TAB ────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  final List<PromoModel> promos;
  const _AnalyticsTab({required this.promos});

  @override
  Widget build(BuildContext context) {
    if (promos.isEmpty) {
      return const Center(
        child: Text(
          'Créez des promotions pour voir les analytiques.',
          style: TextStyle(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    final totalViews        = promos.fold<int>(0, (s, p) => s + p.views);
    final totalClicks       = promos.fold<int>(0, (s, p) => s + p.clicks);
    final totalUsed         = promos.fold<int>(0, (s, p) => s + p.used);
    final totalReservations = promos.fold<int>(0, (s, p) => s + p.currentReservations);

    final ranked = [...promos]
      ..sort((a, b) =>
          (b.views + b.clicks + b.used * 3)
              .compareTo(a.views + a.clicks + a.used * 3));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Conversion funnel card ────────────────────────────────────
        _FunnelCard(
          totalViews:        totalViews,
          totalClicks:       totalClicks,
          totalReservations: totalReservations,
          totalUsed:         totalUsed,
        ),
        const SizedBox(height: 16),

        // ── Top performer ─────────────────────────────────────────────
        _TopPromoCard(promo: ranked.first),
        const SizedBox(height: 16),

        // ── Per-promo ranking ─────────────────────────────────────────
        if (promos.length > 1) ...[
          const _SectionLabel('Classement des promotions'),
          const SizedBox(height: 10),
          ...ranked.asMap().entries.map((e) => _PromoRankRow(
                rank:     e.key + 1,
                promo:    e.value,
                maxViews: ranked.first.views.clamp(1, 999999),
              )),
        ],
      ],
    );
  }
}

// ─── FUNNEL CARD ──────────────────────────────────────────────────────────────

class _FunnelCard extends StatelessWidget {
  final int totalViews;
  final int totalClicks;
  final int totalReservations;
  final int totalUsed;

  const _FunnelCard({
    required this.totalViews,
    required this.totalClicks,
    required this.totalReservations,
    required this.totalUsed,
  });

  @override
  Widget build(BuildContext context) {
    final ctr   = totalViews > 0 ? totalClicks / totalViews * 100 : 0.0;
    final resR  = totalViews > 0 ? totalReservations / totalViews * 100 : 0.0;
    final convR = totalViews > 0 ? totalUsed / totalViews * 100 : 0.0;
    final maxV  = totalViews.clamp(1, 999999);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.insights_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Entonnoir de performance',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bars
          _EngagementBar(
            label: 'Vues',
            value: totalViews,
            max:   maxV,
            color: AppColors.info,
          ),
          const SizedBox(height: 12),
          _EngagementBar(
            label: 'Clics',
            value: totalClicks,
            max:   maxV,
            color: const Color(0xFF0EA5E9),
            pct:   ctr,
          ),
          const SizedBox(height: 12),
          _EngagementBar(
            label: 'Réservations',
            value: totalReservations,
            max:   maxV,
            color: AppColors.purple,
            pct:   resR,
          ),
          const SizedBox(height: 12),
          _EngagementBar(
            label: 'Utilisations',
            value: totalUsed,
            max:   maxV,
            color: AppColors.success,
            pct:   convR,
          ),

          if (ctr > 0 || convR > 0) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _RateBadge('CTR',        '${ctr.toStringAsFixed(1)}%',   AppColors.info),
                _RateBadge('Rés./vues',  '${resR.toStringAsFixed(1)}%',  AppColors.purple),
                _RateBadge('Conversion', '${convR.toStringAsFixed(1)}%', AppColors.success),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EngagementBar extends StatelessWidget {
  final String  label;
  final int     value;
  final int     max;
  final Color   color;
  final double? pct;

  const _EngagementBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final ratio    = (value / max).clamp(0.0, 1.0);
    final pctLabel = pct != null ? '  ${pct!.toStringAsFixed(1)}%' : '';

    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            ratio,
              minHeight:        8,
              backgroundColor:  AppColors.surface,
              valueColor:       AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '$value$pctLabel',
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _RateBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _RateBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── TOP PROMO CARD ───────────────────────────────────────────────────────────

class _TopPromoCard extends StatelessWidget {
  final PromoModel promo;
  const _TopPromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Meilleure promotion',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '-${promo.discount}%',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            promo.title,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   18,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetricPill('${promo.views} vues',         Icons.visibility_rounded),
              _MetricPill('${promo.clicks} clics',        Icons.ads_click_rounded),
              _MetricPill('${promo.currentReservations} réserv.', Icons.bookmark_rounded),
              _MetricPill('${promo.used} utilisations',   Icons.check_circle_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _MetricPill(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PROMO RANK ROW ───────────────────────────────────────────────────────────

class _PromoRankRow extends StatelessWidget {
  final int        rank;
  final PromoModel promo;
  final int        maxViews;
  const _PromoRankRow({
    required this.rank,
    required this.promo,
    required this.maxViews,
  });

  @override
  Widget build(BuildContext context) {
    final ratio     = (promo.views / maxViews).clamp(0.0, 1.0);
    final isTop     = rank == 1;
    final barColor  = isTop ? AppColors.primary : AppColors.textLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:  Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop
              ? AppColors.primary.withValues(alpha: 0.30)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: isTop ? 0.10 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: isTop ? AppColors.primaryGradient : null,
              color: isTop ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color:      isTop ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize:   13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title + bar + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title,
                  style: const TextStyle(
                    color:      AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize:   13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           ratio,
                    minHeight:       5,
                    backgroundColor: AppColors.surface,
                    valueColor:      AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _miniStat(Icons.visibility_rounded,  '${promo.views}'),
                    const SizedBox(width: 10),
                    _miniStat(Icons.ads_click_rounded,   '${promo.clicks}'),
                    const SizedBox(width: 10),
                    _miniStat(Icons.bookmark_rounded,    '${promo.currentReservations}'),
                    const SizedBox(width: 10),
                    _miniStat(Icons.check_circle_rounded,'${promo.used}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Discount chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: isTop ? AppColors.primaryGradient : null,
              color:    isTop ? null : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '-${promo.discount}%',
              style: TextStyle(
                color:      isTop ? Colors.white : AppColors.textMuted,
                fontSize:   11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: AppColors.textLight),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

// ─── SECTION LABEL ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color:      AppColors.textDark,
        fontSize:   14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
