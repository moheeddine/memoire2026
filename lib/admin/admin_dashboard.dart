import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../models/notification_model.dart';
import '../models/promo_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';
import '../utils/error_handler.dart';
import '../widgets/notification_overlay.dart';
import 'manage_users.dart';
import 'manage_companies.dart';
import 'manage_promos.dart';
import 'manage_categories.dart';
import 'admin_notifications_screen.dart';
import 'developer_panel.dart';
import 'admin_settings_screen.dart';

const _kAdminNav = [
  {'icon': Icons.dashboard_rounded,      'label': 'Vue globale'},    // 0
  {'icon': Icons.people_rounded,         'label': 'Utilisateurs'},   // 1
  {'icon': Icons.store_rounded,          'label': 'Entreprises'},    // 2
  {'icon': Icons.local_offer_rounded,    'label': 'Promotions'},     // 3
  {'icon': Icons.category_rounded,       'label': 'Catégories'},     // 4
  {'icon': Icons.notifications_rounded,  'label': 'Notifications'},  // 5
  {'icon': Icons.developer_mode_rounded, 'label': 'Développeur'},    // 6
  {'icon': Icons.settings_rounded,       'label': 'Paramètres'},     // 7
];

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _pageTitle => _kAdminNav[_currentIndex]['label'] as String;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.textDark),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.mainGradient.createShader(bounds),
          child: Text(
            _pageTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        actions: [
          // ── Cloche notifications admin ──────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AdminNotifBell(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      drawer: _AdminDrawer(
        currentIndex: _currentIndex,
        onSelect: (i) {
          setState(() => _currentIndex = i);
          Navigator.pop(context);
        },
      ),
      body: _AdminNotifWrapper(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _OverviewTab(
          onNavigate: (i) => setState(() => _currentIndex = i),
        );
      case 1:  return const ManageUsersScreen();
      case 2:  return const ManageCompaniesScreen();
      case 3:  return const ManagePromosScreen();
      case 4:  return const ManageCategoriesScreen();
      case 5:  return const AdminNotificationsScreen();
      case 6:  return const DeveloperPanel();
      case 7:  return const AdminSettingsScreen();
      default:
        return _OverviewTab(
          onNavigate: (i) => setState(() => _currentIndex = i),
        );
    }
  }
}

// ─── ADMIN NOTIFICATION WRAPPER ───────────────────────────────────────────────
// Encapsule le body du dashboard admin pour afficher les popups de notifications.

class _AdminNotifWrapper extends StatelessWidget {
  final Widget child;
  const _AdminNotifWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return NotificationWrapper(
      userId: kAdminTarget,
      child:  child,
    );
  }
}

// ─── ADMIN NOTIFICATION BELL ──────────────────────────────────────────────────

class _AdminNotifBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const NotificationBell(
      userId:    kAdminTarget,
      iconColor: AppColors.textDark,
    );
  }
}

// ─── SIDEBAR DRAWER ───────────────────────────────────────────────────────────

class _AdminDrawer extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _AdminDrawer({required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 24, 20, 28),
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Administration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PromoCity Panel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _kAdminNav.length,
              itemBuilder: (context, i) {
                final active = currentIndex == i;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.primaryGradient : null,
                      color: active ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _kAdminNav[i]['icon'] as IconData,
                          color: active ? Colors.white : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _kAdminNav[i]['label'] as String,
                          style: TextStyle(
                            color:
                                active ? Colors.white : AppColors.textDark,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Logout at bottom
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.login, (_) => false);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 20),
                    SizedBox(width: 14),
                    Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─── OVERVIEW TAB ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _OverviewTab({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : now.hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, Admin 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tableau de bord PromoCity',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const AppSectionTitle('Vue globale'),
          const SizedBox(height: 12),

          // ── KPI cards ───────────────────────────────────────────────
          AppStatCard<List<UserModel>>(
            label: 'Clients inscrits',
            sublabel: 'Voir tous les utilisateurs',
            icon: Icons.people_rounded,
            color: AppColors.purple,
            stream: AuthService.watchUsersByRole('client'),
            count: (l) => l.length,
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: AppStatCard<List<BusinessModel>>(
                  label: 'Entreprises',
                  sublabel: 'Total inscrites',
                  icon: Icons.store_rounded,
                  color: AppColors.blue,
                  stream: BusinessService.watchAll(),
                  count: (l) => l.length,
                  compact: true,
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppStatCard<List<BusinessModel>>(
                  label: 'En attente',
                  sublabel: 'À approuver',
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                  stream: BusinessService.watchPending(),
                  count: (l) => l.length,
                  compact: true,
                  onTap: () => onNavigate(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: AppStatCard<List<PromoModel>>(
                  label: 'Promos actives',
                  sublabel: 'Approuvées',
                  icon: Icons.local_offer_rounded,
                  color: AppColors.pink,
                  stream: PromoService.watchByStatus('approved'),
                  count: (l) => l.length,
                  compact: true,
                  onTap: () => onNavigate(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppStatCard<List<PromoModel>>(
                  label: 'À modérer',
                  sublabel: 'En attente',
                  icon: Icons.pending_actions_rounded,
                  color: AppColors.orange,
                  stream: PromoService.watchByStatus('pending'),
                  count: (l) => l.length,
                  compact: true,
                  onTap: () => onNavigate(3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Quick actions ────────────────────────────────────────────
          const AppSectionTitle('Actions rapides'),
          const SizedBox(height: 12),
          _QuickActions(onNavigate: onNavigate),

          const SizedBox(height: 28),

          // ── Pending businesses ───────────────────────────────────────
          const AppSectionTitle('Entreprises en attente'),
          const SizedBox(height: 12),
          const _PendingBusinessesList(),
        ],
      ),
    );
  }
}


// ─── QUICK ACTIONS ────────────────────────────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final String   label;
  final Color    color;
  final int      navIndex;
  const _QuickAction(this.icon, this.label, this.color, this.navIndex);
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const _QuickActions({required this.onNavigate});

  static const _actions = [
    _QuickAction(Icons.store_rounded,         'Entreprises',   AppColors.blue,    2),
    _QuickAction(Icons.local_offer_rounded,   'Promotions',    AppColors.pink,    3),
    _QuickAction(Icons.people_rounded,        'Utilisateurs',  AppColors.purple,  1),
    _QuickAction(Icons.notifications_rounded, 'Notifications', AppColors.warning, 5),
    _QuickAction(Icons.category_rounded,      'Catégories',    AppColors.success, 4),
    _QuickAction(Icons.developer_mode_rounded,'Développeur',   AppColors.textMuted, 6),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _actions.length,
      itemBuilder: (context, i) {
        final a = _actions[i];
        return GestureDetector(
          onTap: () => onNavigate(a.navIndex),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: a.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(a.icon, color: a.color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  a.label,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── PENDING BUSINESSES ───────────────────────────────────────────────────────

class _PendingBusinessesList extends StatelessWidget {
  const _PendingBusinessesList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusinessModel>>(
      stream: BusinessService.watchPending(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                AppErrorHandler.getMessage(snap.error),
                style: const TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final businesses = snap.data ?? [];
        if (businesses.isEmpty) {
          return const AppEmptyState(message: 'Aucune entreprise en attente');
        }
        return Column(
          children: businesses.map((b) => _BusinessCard(business: b)).toList(),
        );
      },
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final BusinessModel business;
  const _BusinessCard({required this.business});

  Future<void> _approve(BuildContext context) async {
    try {
      await BusinessService.approve(business.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${business.name} approuvé !'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      AppErrorHandler.log('Business.approve', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  Future<void> _reject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le rejet'),
        content: Text('Rejeter "${business.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeter',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BusinessService.reject(business.uid);
    } catch (e) {
      AppErrorHandler.log('Business.reject', e);
      if (context.mounted) AppErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store_rounded,
                    color: AppColors.warning, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    Text(business.category,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('EN ATTENTE',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (business.matricule.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Matricule : ${business.matricule}',
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 12)),
          ],
          if (business.email.isNotEmpty)
            Text('Email : ${business.email}',
                style: const TextStyle(
                    color: AppColors.textLight, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approve(context),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Rejeter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

