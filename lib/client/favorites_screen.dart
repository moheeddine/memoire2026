import 'package:flutter/material.dart';
import '../models/favorite_model.dart';
import '../models/promo_model.dart';
import '../models/business_model.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../services/promo_service.dart';
import '../services/business_service.dart';
import '../theme/app_theme.dart';
import '../widgets/client_navbar.dart';
import 'promo_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Mes Favoris',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Vos promos et commerces préférés',
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
          ),
          if (uid == null)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Connectez-vous pour voir vos favoris.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: StreamBuilder<List<FavoriteModel>>(
                stream: FavoriteService.watchFavorites(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }

                  final favorites = snap.data ?? [];

                  if (favorites.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_border_rounded,
                                color: AppColors.accent, size: 36),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun favori pour le moment',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explorez les promos et ajoutez vos préférées !',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: favorites.length,
                    itemBuilder: (context, i) {
                      final fav = favorites[i];
                      if (fav.isPromoFavorite) {
                        return _PromoFavCard(
                          promoId: fav.promoId!,
                          favDocId: fav.id,
                        );
                      }
                      if (fav.isBusinessFavorite) {
                        return _BusinessFavCard(
                          businessId: fav.businessId!,
                          favDocId: fav.id,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: const ClientNavbar(currentIndex: 1),
    );
  }
}

// ─── PROMO FAV CARD ──────────────────────────────────────────────────────────

class _PromoFavCard extends StatelessWidget {
  final String promoId;
  final String favDocId;

  const _PromoFavCard({required this.promoId, required this.favDocId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PromoModel?>(
      future: PromoService.getPromo(promoId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (!snap.hasData || snap.data == null) {
          return const _DeletedCard();
        }

        final promo = snap.data!;

        return _FavCard(
          title: promo.title,
          subtitle: promo.businessName ?? '',
          badge: '-${promo.discount}%',
          badgeColor: AppColors.accent,
          icon: Icons.local_offer_rounded,
          iconBgColor: AppColors.accentLight,
          iconColor: AppColors.accent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PromoDetailScreen(promo: promo)),
          ),
          onRemove: () => _remove(context),
        );
      },
    );
  }

  Future<void> _remove(BuildContext context) async {
    try {
      await FavoriteService.removeFavorite(favDocId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Retiré des favoris'),
            backgroundColor: AppColors.textDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }
}

// ─── BUSINESS FAV CARD ───────────────────────────────────────────────────────

class _BusinessFavCard extends StatelessWidget {
  final String businessId;
  final String favDocId;

  const _BusinessFavCard({required this.businessId, required this.favDocId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BusinessModel?>(
      future: BusinessService.getBusinessData(businessId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCard();
        }
        if (!snap.hasData || snap.data == null) {
          return const _DeletedCard();
        }

        final business = snap.data!;

        return _FavCard(
          title: business.name,
          subtitle: business.category,
          badge: business.category,
          badgeColor: AppColors.primary,
          icon: Icons.store_rounded,
          iconBgColor: AppColors.primaryLight,
          iconColor: AppColors.primary,
          onTap: () {},
          onRemove: () => _remove(context),
        );
      },
    );
  }

  Future<void> _remove(BuildContext context) async {
    try {
      await FavoriteService.removeFavorite(favDocId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Retiré des favoris'),
            backgroundColor: AppColors.textDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }
}

// ─── SHARED CARD ─────────────────────────────────────────────────────────────

class _FavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.favorite_rounded,
                  color: AppColors.accent, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UTILITY CARDS ───────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      ),
    );
  }
}

class _DeletedCard extends StatelessWidget {
  const _DeletedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.broken_image_rounded, color: AppColors.textLight),
          SizedBox(width: 12),
          Text('Promo expirée ou supprimée',
              style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
