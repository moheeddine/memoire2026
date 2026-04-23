import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/rating_service.dart';
import '../theme/app_theme.dart';
import '../widgets/star_rating_widget.dart';
import 'business_navbar.dart';

class BusinessProfileScreen extends StatelessWidget {
  final String businessId;

  const BusinessProfileScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<BusinessModel?>(
        future: BusinessService.getBusinessData(businessId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary));
          }

          final business = snapshot.data;

          return CustomScrollView(
            slivers: [
              // ─── Header ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.mainGradient,
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.store_rounded,
                                color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            business?.name ?? 'Mon Entreprise',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            business?.category ?? '',
                            style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.8),
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
                      // Rating
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
                      _infoTile(
                          Icons.mail_outline_rounded, 'Email', email),
                      _infoTile(Icons.category_outlined, 'Catégorie',
                          business?.category ?? '—'),
                      _infoTile(Icons.person_outline_rounded,
                          'Responsable', business?.ownerName ?? '—'),
                      _infoTile(
                          Icons.badge_outlined,
                          'Matricule',
                          business?.matricule.isNotEmpty == true
                              ? business!.matricule
                              : '—'),

                      const SizedBox(height: 24),

                      // Sign out
                      GradientButton(
                        label: 'Se déconnecter',
                        icon: Icons.logout_rounded,
                        onTap: () async {
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          }
                        },
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEF4444),
                            Color(0xFFDC2626)
                          ],
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
    );
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
