import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../utils/app_routes.dart';
import '../services/rating_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import '../widgets/star_rating_widget.dart';
import 'business_navbar.dart';
import '../widgets/notification_overlay.dart';

class BusinessProfileScreen extends StatelessWidget {
  final String businessId;

  const BusinessProfileScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return NotificationWrapper(
      userId: businessId,
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<BusinessModel?>(
        stream: BusinessService.watchBusiness(businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  AppErrorHandler.getMessage(snapshot.error),
                  style: const TextStyle(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final business = snapshot.data;
          if (business == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.store_mall_directory_outlined,
                      color: AppColors.textLight, size: 48),
                  const SizedBox(height: 12),
                  const Text('Entreprise introuvable',
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, AppRoutes.login, (_) => false);
                      }
                    },
                    child: const Text('Se déconnecter'),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ─── Header ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: NotificationBell(userId: businessId),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                        gradient: AppColors.mainGradient),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          // Avatar — matricule image if available, else icon
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 3),
                              color: Colors.white
                                  .withValues(alpha: 0.15),
                            ),
                            child: ClipOval(
                              child: business.matriculeImageUrl != null &&
                                      business.matriculeImageUrl!.isNotEmpty
                                  ? Image.network(
                                      business.matriculeImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.store_rounded,
                                              color: Colors.white, size: 42),
                                    )
                                  : const Icon(Icons.store_rounded,
                                      color: Colors.white, size: 42),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            business.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            business.category,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Content ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Rating card
                      FutureBuilder<double>(
                        future: RatingService.getAverageRating(businessId),
                        builder: (context, snap) {
                          final avg = snap.data ?? 0.0;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: AppColors.softGradient,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.warning, size: 28),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      avg.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'Note moyenne',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                RatingBadge(rating: avg),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Info tiles
                      _infoTile(Icons.business_outlined, 'Nom',
                          business.name),
                      _infoTile(Icons.person_outline_rounded, 'Responsable',
                          business.ownerName.isNotEmpty
                              ? business.ownerName
                              : '—'),
                      _infoTile(Icons.mail_outline_rounded, 'Email',
                          business.email.isNotEmpty ? business.email : '—'),
                      _infoTile(Icons.category_outlined, 'Catégorie',
                          business.category.isNotEmpty
                              ? business.category
                              : '—'),
                      _infoTile(
                          Icons.badge_outlined,
                          'Matricule',
                          business.matricule.isNotEmpty
                              ? business.matricule
                              : '—'),

                      // Matricule document image
                      if (business.matriculeImageUrl != null &&
                          business.matriculeImageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.image_outlined,
                                        color: AppColors.primary, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Document matricule',
                                      style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(13)),
                                child: Image.network(
                                  business.matriculeImageUrl!,
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: AppColors.bg,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          color: AppColors.textLight),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Sign out
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await AuthService.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (_) => false,
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Se déconnecter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BusinessNavbar(
        currentIndex: 4,
        businessId: businessId,
      ),
    )); // NotificationWrapper
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
