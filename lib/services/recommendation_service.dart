import 'package:geolocator/geolocator.dart';
import '../models/promo_model.dart';
import 'promo_service.dart';
import 'favorite_service.dart';

/// Advanced AI recommendation engine.
///
/// Score formula (weights sum to 1.0):
///   proximity      × 0.25
///   isFavorite     × 0.20
///   categoryAffin  × 0.15
///   discount       × 0.15  ← new: higher discount → higher score
///   popularity     × 0.10
///   flashBonus     × 0.08
///   recency        × 0.07
class RecommendationService {
  static const double _maxDistM  = 10000; // 10 km cap
  static const double _wProx     = 0.25;
  static const double _wFav      = 0.20;
  static const double _wCat      = 0.15;
  static const double _wDiscount = 0.15;
  static const double _wPop      = 0.10;
  static const double _wFlash    = 0.08;
  static const double _wRecency  = 0.07;

  // ─── PUBLIC API ───────────────────────────────────────────────────────────

  static Future<List<PromoModel>> getRecommendations({
    required String userId,
    required double userLat,
    required double userLng,
    int limit = 5,
  }) async {
    final all = await PromoService.getApprovedWithBusinessData();
    if (all.isEmpty) return [];
    // Defensive filter: cache may contain promos that expired mid-session.
    final promos = all.where((p) => p.isEffectivelyActive).toList();
    if (promos.isEmpty) return [];

    final withPos = promos.where((p) => p.lat != null && p.lng != null).toList();
    if (withPos.isEmpty) return promos.take(limit).toList();

    // Enrich with distance
    final withDist = withPos.map((p) {
      final dist = Geolocator.distanceBetween(
          userLat, userLng, p.lat!, p.lng!);
      return p.withDistance(dist);
    }).toList();

    // Fetch user data for scoring
    final favoritePromoIds  = await FavoriteService.getFavoritePromoIds(userId);
    final preferredCats     = _extractCategories(withDist, favoritePromoIds);
    final maxViews          = _maxValue(withDist, (p) => p.views + p.clicks);
    final now               = DateTime.now();

    // Score every promo
    final scored = withDist.map((p) {
      final score = _score(
        promo:          p,
        isFav:          favoritePromoIds.contains(p.id),
        prefCats:       preferredCats,
        maxEngagement:  maxViews,
        now:            now,
      );
      return _ScoredPromo(promo: p, score: score);
    }).toList();

    // Sort by score desc, break ties by distance
    scored.sort((a, b) {
      final diff = b.score.compareTo(a.score);
      if (diff != 0) return diff;
      final dA = a.promo.distanceMeters ?? double.maxFinite;
      final dB = b.promo.distanceMeters ?? double.maxFinite;
      return dA.compareTo(dB);
    });

    return scored.take(limit).map((s) => s.promo).toList();
  }

  /// Returns promos sorted by popularity / distance ratio.
  static Future<List<PromoModel>> getPopularNearby({
    required double userLat,
    required double userLng,
    int limit = 5,
  }) async {
    final all = await PromoService.getApprovedWithBusinessData();
    if (all.isEmpty) return [];
    final promos = all.where((p) => p.isEffectivelyActive).toList();
    if (promos.isEmpty) return [];

    final withPos = promos.where((p) => p.lat != null && p.lng != null).toList();
    if (withPos.isEmpty) return promos.take(limit).toList();

    final withDist = withPos.map((p) {
      final dist = Geolocator.distanceBetween(
          userLat, userLng, p.lat!, p.lng!);
      return p.withDistance(dist);
    }).toList();

    // Score = (views + used * 2) / (distanceKm + 1)
    withDist.sort((a, b) {
      final popA = (a.views + a.used * 2).toDouble();
      final popB = (b.views + b.used * 2).toDouble();
      final dkmA = (a.distanceMeters ?? _maxDistM) / 1000;
      final dkmB = (b.distanceMeters ?? _maxDistM) / 1000;
      final sA = popA / (dkmA + 1);
      final sB = popB / (dkmB + 1);
      return sB.compareTo(sA);
    });

    return withDist.take(limit).toList();
  }

  // ─── SCORING ──────────────────────────────────────────────────────────────

  static double _score({
    required PromoModel  promo,
    required bool        isFav,
    required Set<String> prefCats,
    required int         maxEngagement,
    required DateTime    now,
  }) {
    final prox     = _proximityScore(promo.distanceMeters ?? _maxDistM);
    final fav      = isFav ? 1.0 : 0.0;
    final cat      = _categoryScore(promo.category, prefCats);
    final discount = _discountScore(promo.effectiveDiscountPct);
    final pop      = _popularityScore(promo.views + promo.clicks, maxEngagement);
    final flash    = _flashScore(promo, now);
    final recency  = _recencyScore(promo.createdAt, now);

    return (prox     * _wProx)
         + (fav      * _wFav)
         + (cat      * _wCat)
         + (discount * _wDiscount)
         + (pop      * _wPop)
         + (flash    * _wFlash)
         + (recency  * _wRecency);
  }

  /// Normalises discount % to [0,1]. 70%+ → max score.
  static double _discountScore(double pct) =>
      (pct / 70.0).clamp(0.0, 1.0);

  static double _proximityScore(double distM) {
    if (distM <= 0) return 1.0;
    if (distM >= _maxDistM) return 0.0;
    return 1.0 - (distM / _maxDistM);
  }

  static double _categoryScore(String? cat, Set<String> prefCats) {
    if (cat == null || prefCats.isEmpty) return 0.0;
    return prefCats.contains(cat) ? 1.0 : 0.0;
  }

  static double _popularityScore(int engagement, int maxEngagement) {
    if (maxEngagement <= 0) return 0.0;
    return (engagement / maxEngagement).clamp(0.0, 1.0);
  }

  static double _flashScore(PromoModel promo, DateTime now) {
    if (!promo.isFlashDeal || promo.flashEndTime == null) return 0.0;
    final remaining = promo.flashEndTime!.difference(now);
    if (remaining.isNegative) return 0.0;
    if (remaining.inHours < 2) return 1.0;   // urgent
    if (remaining.inHours < 6) return 0.7;
    return 0.4;
  }

  static double _recencyScore(DateTime? createdAt, DateTime now) {
    if (createdAt == null) return 0.0;
    final ageDays = now.difference(createdAt).inDays;
    if (ageDays <= 1)  return 1.0;
    if (ageDays <= 7)  return 0.75;
    if (ageDays <= 30) return 0.40;
    return 0.0;
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  static Set<String> _extractCategories(
      List<PromoModel> promos, Set<String> favoriteIds) {
    return promos
        .where((p) => favoriteIds.contains(p.id) && p.category != null)
        .map((p) => p.category!)
        .toSet();
  }

  static int _maxValue(List<PromoModel> promos, int Function(PromoModel) fn) {
    return promos.fold<int>(1, (prev, p) {
      final v = fn(p);
      return v > prev ? v : prev;
    });
  }
}

// ─── INTERNAL DATA CLASS ──────────────────────────────────────────────────────

class _ScoredPromo {
  final PromoModel promo;
  final double     score;
  const _ScoredPromo({required this.promo, required this.score});
}
