import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../models/promo_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/promo_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'manage_users.dart';
import 'manage_promos.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.mainGradient.createShader(bounds),
          child: const Text(
            'Administration',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
            onPressed: () async {
              await AuthService.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildNavbar(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:  return const _OverviewTab();
      case 1:  return const ManageUsersScreen();
      case 2:  return const ManagePromosScreen();
      default: return const _OverviewTab();
    }
  }

  Widget _buildNavbar() {
    final items = [
      {'icon': Icons.dashboard_rounded,   'label': 'Vue globale'},
      {'icon': Icons.people_rounded,      'label': 'Utilisateurs'},
      {'icon': Icons.local_offer_rounded, 'label': 'Promos'},
    ];

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
        children: List.generate(items.length, (i) {
          final active = _currentIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _currentIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                  horizontal: active ? 16 : 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: active ? AppColors.primaryGradient : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: active
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i]['icon'] as IconData,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          items[i]['label'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Icon(items[i]['icon'] as IconData,
                      color: AppColors.textMuted, size: 22),
            ),
          );
        }),
      ),
    );
  }
}

// ─── OVERVIEW TAB ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatsRow(),
          const SizedBox(height: 24),
          _sectionHeader('Entreprises en attente'),
          const SizedBox(height: 12),
          const _PendingBusinessesList(),
          const SizedBox(height: 24),
          _sectionHeader('Promos en attente'),
          const SizedBox(height: 12),
          const _PendingPromosList(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ─── STATS ROW ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard<List<UserModel>>(
            label:   'Clients',
            icon:    Icons.person_rounded,
            color:   AppColors.purple,
            stream:  AuthService.watchUsersByRole('client'),
            count:   (l) => l.length,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard<List<BusinessModel>>(
            label:   'Entreprises',
            icon:    Icons.store_rounded,
            color:   AppColors.blue,
            stream:  BusinessService.watchAll(),
            count:   (l) => l.length,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard<List<PromoModel>>(
            label:   'Promos',
            icon:    Icons.local_offer_rounded,
            color:   AppColors.pink,
            stream:  PromoService.watchByStatus('approved'),
            count:   (l) => l.length,
          ),
        ),
      ],
    );
  }
}

class _StatCard<T> extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final Stream<T> stream;
  final int Function(T) count;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snap) {
        final n = snap.hasData ? count(snap.data as T) : 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                n.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
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
        final businesses = snap.data ?? [];
        if (businesses.isEmpty) return _emptyState('Aucune entreprise en attente');
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
      await NotificationService.notifyBusinessApproved(business.uid);
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
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
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
      await NotificationService.notifyBusinessRejected(business.uid);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
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

// ─── PENDING PROMOS ───────────────────────────────────────────────────────────

class _PendingPromosList extends StatelessWidget {
  const _PendingPromosList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PromoModel>>(
      stream: PromoService.watchByStatus('pending'),
      builder: (context, snap) {
        final promos = snap.data ?? [];
        if (promos.isEmpty) return _emptyState('Aucune promo en attente');
        return Column(
          children: promos.map((p) => _AdminPromoCard(promo: p)).toList(),
        );
      },
    );
  }
}

class _AdminPromoCard extends StatelessWidget {
  final PromoModel promo;
  const _AdminPromoCard({required this.promo});

  Future<void> _approve(BuildContext context) async {
    try {
      await PromoService.approve(promo.id);
      await NotificationService.notifyPromoApproved(
          promo.businessId, promo.title);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promo approuvée !'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    try {
      await PromoService.reject(promo.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promo rejetée'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
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
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.06),
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
              Expanded(
                child: Text(
                  promo.title,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '-${promo.discount}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          if (promo.businessName != null) ...[
            const SizedBox(height: 4),
            Text(promo.businessName!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
          if (promo.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              promo.description,
              style: const TextStyle(
                  color: AppColors.textLight, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _approve(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Approuver'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reject(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Rejeter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── SHARED ───────────────────────────────────────────────────────────────────

Widget _emptyState(String message) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 18),
        const SizedBox(width: 10),
        Text(message,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13)),
      ],
    ),
  );
}
