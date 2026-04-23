import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../models/promo_model.dart';
import '../services/business_service.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';
import 'business_navbar.dart';

class DashboardScreen extends StatelessWidget {
  final String businessId;

  const DashboardScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: BusinessNavbar(
        currentIndex: 0,
        businessId: businessId,
      ),
      body: StreamBuilder<BusinessModel?>(
        stream: BusinessService.watchBusiness(businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final business = snapshot.data;
          if (business == null) {
            return const Center(
              child: Text('Commerce introuvable',
                  style: TextStyle(color: AppColors.textMuted)),
            );
          }

          return CustomScrollView(
            slivers: [
              // ─── Header ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.mainGradient,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.store_rounded,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        business.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        business.category,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Dashboard · ${DateTime.now().year}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ─── Content ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _StatCard(
                            label: 'Vues',
                            value: business.stats.views.toString(),
                            growth: _growth(business.stats.views),
                            icon: Icons.visibility_rounded,
                            color: AppColors.info,
                          ),
                          _StatCard(
                            label: 'Clics',
                            value: business.stats.clicks.toString(),
                            growth: _growth(business.stats.clicks),
                            icon: Icons.ads_click_rounded,
                            color: AppColors.primary,
                          ),
                          _StatCard(
                            label: 'Conversions',
                            value: business.stats.conversions.toString(),
                            growth: _growth(business.stats.conversions),
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                          ),
                          _StatCard(
                            label: 'Économies',
                            value: '${business.stats.savings} DT',
                            growth: _growth(business.stats.savings),
                            icon: Icons.savings_rounded,
                            color: AppColors.warning,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Weekly chart
                      const Text(
                        'Vues cette semaine',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _bar('Lun', business.weeklyViews.lun,
                                business.weeklyViews.max),
                            _bar('Mar', business.weeklyViews.mar,
                                business.weeklyViews.max),
                            _bar('Mer', business.weeklyViews.mer,
                                business.weeklyViews.max),
                            _bar('Jeu', business.weeklyViews.jeu,
                                business.weeklyViews.max),
                            _bar('Ven', business.weeklyViews.ven,
                                business.weeklyViews.max),
                            _bar('Sam', business.weeklyViews.sam,
                                business.weeklyViews.max),
                            _bar('Dim', business.weeklyViews.dim,
                                business.weeklyViews.max),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Active promos
                      const Text(
                        'Mes promotions actives',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      StreamBuilder<List<PromoModel>>(
                        stream: PromoService.watchByBusiness(businessId),
                        builder: (context, promoSnap) {
                          if (!promoSnap.hasData) {
                            return const SizedBox.shrink();
                          }

                          final approved = promoSnap.data!
                              .where(
                                  (p) => p.status == PromoStatus.approved)
                              .toList();

                          if (approved.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      color: AppColors.textLight, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Aucune promotion active',
                                    style: TextStyle(
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: approved
                                .map((p) => _PromoTile(promo: p))
                                .toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(String day, int value, int maxValue) {
    final height = maxValue > 0
        ? ((value / maxValue) * 90).clamp(6.0, 90.0)
        : 6.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: const TextStyle(color: AppColors.textLight, fontSize: 11),
        ),
      ],
    );
  }

  String _growth(int value) {
    if (value == 0) return '0%';
    return '+${(value / 10).toStringAsFixed(0)}%';
  }
}

// ─── STAT CARD ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String growth;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.growth,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '↑ $growth',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── PROMO TILE ───────────────────────────────────────────────────────────────

class _PromoTile extends StatelessWidget {
  final PromoModel promo;

  const _PromoTile({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_offer_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  '${promo.views} vues · ${promo.used} utilisations',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Actif',
              style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
