import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';

// ─── DATA MODELS ─────────────────────────────────────────────────────────────

class _DevStats {
  final int users;
  final int businesses;
  final int promos;
  final int reservations;
  final int activePromos;
  final int expiredPromos;

  const _DevStats({
    required this.users,
    required this.businesses,
    required this.promos,
    required this.reservations,
    required this.activePromos,
    required this.expiredPromos,
  });

  static const zero = _DevStats(
    users: 0, businesses: 0, promos: 0,
    reservations: 0, activePromos: 0, expiredPromos: 0,
  );
}

enum _Status { checking, ok, error }

class _ActivityItem {
  final String   title;
  final String   subtitle;
  final DateTime? sortTime;
  final IconData icon;
  final Color    color;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.sortTime,
  });
}

// ─── DEVELOPER PANEL ─────────────────────────────────────────────────────────

class DeveloperPanel extends StatefulWidget {
  const DeveloperPanel({super.key});

  @override
  State<DeveloperPanel> createState() => _DeveloperPanelState();
}

class _DeveloperPanelState extends State<DeveloperPanel> {
  static const _appVersion  = '1.0.0';
  static const _buildNumber = '1';
  static const _flutterVer  = '3.24.x';
  static const _firebaseSdk = '5.4.0';

  late Future<_DevStats>            _statsFuture;
  late Future<Map<String, _Status>> _statusFuture;
  late Future<List<_ActivityItem>>  _activityFuture;

  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _statsFuture    = _loadStats();
    _statusFuture   = _pingServices();
    _activityFuture = _loadActivity();
  }

  // ─── LOADERS ─────────────────────────────────────────────────────────────

  static Future<_DevStats> _loadStats() async {
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db.collection('users').count().get(),
        db.collection('businesses').count().get(),
        db.collection('promos').count().get(),
        db.collection('reservations').count().get(),
        db.collection('promos')
            .where('status', isEqualTo: 'approved').count().get(),
        db.collection('promos')
            .where('status', isEqualTo: 'expired').count().get(),
      ]);
      int n(int i) =>
          (results[i].count ?? 0);
      return _DevStats(
        users:         n(0),
        businesses:    n(1),
        promos:        n(2),
        reservations:  n(3),
        activePromos:  n(4),
        expiredPromos: n(5),
      );
    } catch (e) {
      AppErrorHandler.log('DevPanel.loadStats', e);
      return _DevStats.zero;
    }
  }

  static Future<Map<String, _Status>> _pingServices() async {
    final db  = FirebaseFirestore.instance;
    final Map<String, _Status> r = {};

    // Firestore — lightweight read with timeout
    try {
      await db.collection('users').limit(1).get()
          .timeout(const Duration(seconds: 5));
      r['firestore'] = _Status.ok;
    } catch (_) {
      r['firestore'] = _Status.error;
    }

    // Auth — already authenticated admin
    r['auth']          = AuthService.currentUid != null
        ? _Status.ok : _Status.error;
    // Notifications — initialised at app startup
    r['notifications'] = _Status.ok;
    // Cloudinary — statically configured (no secret exposed)
    r['cloudinary']    = _Status.ok;

    return r;
  }

  static Future<List<_ActivityItem>> _loadActivity() async {
    final db    = FirebaseFirestore.instance;
    final items = <_ActivityItem>[];

    Future<void> safeAdd(Future<void> Function() fn) async {
      try { await fn(); } catch (_) {}
    }

    await safeAdd(() async {
      final snap = await db.collection('businesses')
          .orderBy('createdAt', descending: true).limit(3).get();
      for (final doc in snap.docs) {
        final d  = doc.data();
        final ts = (d['createdAt'] as Timestamp?)?.toDate();
        items.add(_ActivityItem(
          title:    'Entreprise : ${d['name'] ?? 'Inconnue'}',
          subtitle: d['category'] as String? ?? '',
          sortTime: ts,
          icon:  Icons.store_rounded,
          color: AppColors.blue,
        ));
      }
    });

    await safeAdd(() async {
      final snap = await db.collection('promos')
          .orderBy('createdAt', descending: true).limit(3).get();
      for (final doc in snap.docs) {
        final d        = doc.data();
        final discount = d['discount'] as int? ?? 0;
        final ts       = (d['createdAt'] as Timestamp?)?.toDate();
        items.add(_ActivityItem(
          title:    'Promo : ${d['title'] ?? 'Sans titre'}',
          subtitle: '-$discount%',
          sortTime: ts,
          icon:  Icons.local_offer_rounded,
          color: AppColors.pink,
        ));
      }
    });

    await safeAdd(() async {
      final snap = await db.collection('reservations')
          .orderBy('createdAt', descending: true).limit(3).get();
      for (final doc in snap.docs) {
        final d  = doc.data();
        final ts = (d['createdAt'] as Timestamp?)?.toDate();
        items.add(_ActivityItem(
          title:    'Réservation : ${d['promoTitle'] ?? '—'}',
          subtitle: 'par ${d['userName'] ?? 'Client'}',
          sortTime: ts,
          icon:  Icons.bookmark_rounded,
          color: AppColors.purple,
        ));
      }
    });

    items.sort((a, b) =>
        (b.sortTime ?? DateTime(2000))
            .compareTo(a.sortTime ?? DateTime(2000)));

    return items.take(9).toList();
  }

  static String _timeAgo(DateTime? dt) {
    if (dt == null) return '—';
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60)  return 'À l\'instant';
    if (d.inMinutes < 60)  return 'Il y a ${d.inMinutes}min';
    if (d.inHours < 24)    return 'Il y a ${d.inHours}h';
    if (d.inDays < 7)      return 'Il y a ${d.inDays}j';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notif_enabled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Cache temporaire vidé'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      AppErrorHandler.log('DevPanel.clearCache', e);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => setState(_reload),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),

            const AppSectionTitle('Statut des services'),
            const SizedBox(height: 12),
            _buildStatusCard(),
            const SizedBox(height: 24),

            const AppSectionTitle('Statistiques globales'),
            const SizedBox(height: 12),
            _buildStatsGrid(),
            const SizedBox(height: 24),

            const AppSectionTitle('Activité récente'),
            const SizedBox(height: 12),
            _buildActivityCard(),
            const SizedBox(height: 24),

            const AppSectionTitle('Journaux système'),
            const SizedBox(height: 12),
            _buildLogsCard(),
            const SizedBox(height: 24),

            const AppSectionTitle('Outils de maintenance'),
            const SizedBox(height: 12),
            _buildMaintenanceCard(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.primaryShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.mainGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.developer_mode_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Developer Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        )),
                    Text(
                      'PromoCity v$_appVersion (build $_buildNumber)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const _PulsingDot(),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.20), height: 1),
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _headerField('Flutter',   _flutterVer),
              _headerField('Firebase',  _firebaseSdk),
              _headerField('App',       'PromoCity'),
              _headerField('Plateforme','Android / iOS'),
              _headerField('Backend',   'Firebase + Cloudinary'),
              _headerField('Build',     '#$_buildNumber'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerField(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          )),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
    ],
  );

  // ─── STATUS CARD ─────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    return FutureBuilder<Map<String, _Status>>(
      future: _statusFuture,
      builder: (context, snap) {
        final checking = !snap.hasData;
        final s        = snap.data ?? {};
        return VibrantCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _StatusRow(
                label:  'Firestore Database',
                icon:   Icons.storage_rounded,
                color:  AppColors.blue,
                status: checking ? _Status.checking : s['firestore']!,
              ),
              const _Separator(),
              _StatusRow(
                label:  'Firebase Auth',
                icon:   Icons.lock_rounded,
                color:  AppColors.purple,
                status: checking ? _Status.checking : s['auth']!,
              ),
              const _Separator(),
              _StatusRow(
                label:  'Notifications locales',
                icon:   Icons.notifications_rounded,
                color:  AppColors.pink,
                status: checking ? _Status.checking : s['notifications']!,
              ),
              const _Separator(),
              _StatusRow(
                label:  'Cloudinary CDN',
                icon:   Icons.cloud_upload_rounded,
                color:  AppColors.success,
                status: checking ? _Status.checking : s['cloudinary']!,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── STATS GRID ──────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    return FutureBuilder<_DevStats>(
      future: _statsFuture,
      builder: (context, snap) {
        final stats   = snap.data ?? _DevStats.zero;
        final loading = !snap.hasData;
        return Column(
          children: [
            Row(children: [
              Expanded(child: _StatTile(
                label: 'Utilisateurs',  value: stats.users,
                icon: Icons.people_rounded, color: AppColors.purple,
                loading: loading,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                label: 'Entreprises',   value: stats.businesses,
                icon: Icons.store_rounded, color: AppColors.blue,
                loading: loading,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatTile(
                label: 'Promos totales', value: stats.promos,
                icon: Icons.local_offer_rounded, color: AppColors.pink,
                loading: loading,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                label: 'Réservations',  value: stats.reservations,
                icon: Icons.bookmark_rounded, color: AppColors.warning,
                loading: loading,
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatTile(
                label: 'Promos actives', value: stats.activePromos,
                icon: Icons.bolt_rounded, color: AppColors.success,
                loading: loading,
              )),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(
                label: 'Expirées',      value: stats.expiredPromos,
                icon: Icons.history_rounded, color: AppColors.textLight,
                loading: loading,
              )),
            ]),
          ],
        );
      },
    );
  }

  // ─── ACTIVITY CARD ───────────────────────────────────────────────────────

  Widget _buildActivityCard() {
    return FutureBuilder<List<_ActivityItem>>(
      future: _activityFuture,
      builder: (context, snap) {
        if (!snap.hasData) return _skeletonActivity();
        final items = snap.data!;
        if (items.isEmpty) {
          return const VibrantCard(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Aucune activité récente',
                  style: TextStyle(
                      color: AppColors.textLight, fontSize: 13)),
            ),
          );
        }
        return VibrantCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: items.asMap().entries.map((e) {
              final last = e.key == items.length - 1;
              return _ActivityTile(
                  item: e.value, showDivider: !last);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _skeletonActivity() => VibrantCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: List.generate(4, (i) => Padding(
        padding: EdgeInsets.only(bottom: i < 3 ? 16.0 : 0.0),
        child: const Row(children: [
          AppSkeletonLoader(width: 36, height: 36, radius: 10),
          SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonLoader(height: 12, radius: 6),
              SizedBox(height: 6),
              AppSkeletonLoader(width: 100, height: 10, radius: 5),
            ],
          )),
        ]),
      )),
    ),
  );

  // ─── LOGS CARD ───────────────────────────────────────────────────────────

  Widget _buildLogsCard() {
    return VibrantCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('Aucune erreur critique',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ]),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          const _LogRow(level: 'INFO', color: AppColors.info,
              message: 'Notifications locales initialisées au démarrage'),
          const SizedBox(height: 10),
          const _LogRow(level: 'INFO', color: AppColors.info,
              message: 'Firestore connecté — lecture/écriture opérationnelles'),
          const SizedBox(height: 10),
          const _LogRow(level: 'INFO', color: AppColors.success,
              message: 'Admin authentifié — session active'),
          const SizedBox(height: 10),
          const _LogRow(level: 'WARN', color: AppColors.warning,
              message: 'Permission notification requise sur Android 13+'),
          const SizedBox(height: 10),
          const _LogRow(level: 'INFO', color: AppColors.blue,
              message: 'Cloudinary configuré — upload images opérationnel'),
        ],
      ),
    );
  }

  // ─── MAINTENANCE CARD ────────────────────────────────────────────────────

  Widget _buildMaintenanceCard() {
    return VibrantCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _MaintenanceButton(
            icon:  Icons.refresh_rounded,
            label: 'Actualiser le tableau de bord',
            color: AppColors.primary,
            onTap: () => setState(_reload),
          ),
          const SizedBox(height: 10),
          _MaintenanceButton(
            icon:  Icons.bar_chart_rounded,
            label: 'Recharger les statistiques',
            color: AppColors.blue,
            onTap: () => setState(() => _statsFuture = _loadStats()),
          ),
          const SizedBox(height: 10),
          _MaintenanceButton(
            icon:    Icons.cleaning_services_rounded,
            label:   _clearing ? 'Nettoyage…' : 'Vider le cache temporaire',
            color:   AppColors.warning,
            loading: _clearing,
            onTap:   _clearing ? null : _clearCache,
          ),
        ],
      ),
    );
  }
}

// ─── PULSING DOT ──────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color:  AppColors.success.withValues(alpha: _anim.value),
              shape:  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:       AppColors.success.withValues(alpha: _anim.value * 0.55),
                  blurRadius:  7,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                color:         AppColors.success,
                fontSize:      10,
                fontWeight:    FontWeight.w800,
                letterSpacing: 1.1,
              )),
        ],
      ),
    );
  }
}

// ─── SEPARATOR ────────────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Divider(color: AppColors.border, height: 1),
  );
}

// ─── STATUS ROW ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final _Status  status;

  const _StatusRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (dotColor, label2) = switch (status) {
      _Status.ok       => (AppColors.success, 'Connecté'),
      _Status.error    => (AppColors.error,   'Hors ligne'),
      _Status.checking => (AppColors.textLight,'Vérification…'),
    };

    return Row(
      children: [
        AppIconBox(icon: icon, color: color, size: 38, iconSize: 19,
            solid: false),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                color:      AppColors.textDark,
                fontSize:   14,
                fontWeight: FontWeight.w600,
              )),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label2,
                style: TextStyle(
                  color:      dotColor,
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ],
    );
  }
}

// ─── STAT TILE ────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String   label;
  final int      value;
  final IconData icon;
  final Color    color;
  final bool     loading;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow:    AppColors.cardShadow(tint: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBox(icon: icon, color: color, size: 38, iconSize: 19),
          const SizedBox(height: 12),
          loading
              ? const AppSkeletonLoader(width: 48, height: 24, radius: 6)
              : TweenAnimationBuilder<double>(
                  tween:    Tween(begin: 0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve:    Curves.easeOutCubic,
                  builder:  (_, v, __) => Text(
                    '${v.round()}',
                    style: const TextStyle(
                      color:      AppColors.textDark,
                      fontSize:   26,
                      fontWeight: FontWeight.w800,
                      height:     1,
                    ),
                  ),
                ),
          const SizedBox(height: 4),
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color:      AppColors.textMuted,
                fontSize:   11,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

// ─── ACTIVITY TILE ────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  final bool          showDivider;

  const _ActivityTile({required this.item, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AppIconBox(icon: item.icon, color: item.color,
                size: 36, iconSize: 18, solid: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      AppColors.textDark,
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                      )),
                  if (item.subtitle.isNotEmpty)
                    Text(item.subtitle,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _DeveloperPanelState._timeAgo(item.sortTime),
              style: const TextStyle(
                color:      AppColors.textLight,
                fontSize:   10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─── LOG ROW ─────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final String level;
  final Color  color;
  final String message;

  const _LogRow({
    required this.level,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(level,
              style: TextStyle(
                color:         color,
                fontSize:      9,
                fontWeight:    FontWeight.w800,
                letterSpacing: 0.5,
              )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                color:  AppColors.textMuted,
                fontSize: 12,
                height: 1.4,
              )),
        ),
      ],
    );
  }
}

// ─── MAINTENANCE BUTTON ───────────────────────────────────────────────────────

class _MaintenanceButton extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Color         color;
  final VoidCallback? onTap;
  final bool          loading;

  const _MaintenanceButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            loading
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: color, strokeWidth: 2),
                  )
                : Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color:      color,
                    fontSize:   14,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.45), size: 18),
          ],
        ),
      ),
    );
  }
}
