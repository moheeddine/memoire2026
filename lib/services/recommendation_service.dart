import 'package:geolocator/geolocator.dart';
import '../models/promo_model.dart';
import 'promo_service.dart';
import 'favorite_service.dart';

class RecommendationService {
  // ─── ALGORITHME DE SCORE ──────────────────────────────────────────────────
  //
  // Score final = (proximité * 0.40)
  //             + (catégorie préférée * 0.40)
  //             + (popularité * 0.20)
  //
  // - Proximité   : normalisée sur 10 km max (1.0 = ≤ 500m, 0.0 = ≥ 10km)
  // - Catégorie   : 1.0 si l'user a favoris dans cette catégorie, 0.0 sinon
  // - Popularité  : normalisée sur le max de vues de la session

  static const double _maxDistanceM  = 10000; // 10 km
  static const double _wProximity    = 0.40;
  static const double _wCategory     = 0.40;
  static const double _wPopularity   = 0.20;

  // ─── POINT D'ENTRÉE PUBLIC ────────────────────────────────────────────────

  static Future<List<PromoModel>> getRecommendations({
    required String userId,
    required double userLat,
    required double userLng,
    int limit = 4,
  }) async {
    // 1. Charger promos approuvées avec données business (JOIN inclus)
    final promos = await PromoService.getApprovedWithBusinessData();
    if (promos.isEmpty) return [];

    // 2. Filtrer celles qui ont une position connue
    final withPos = promos
        .where((p) => p.lat != null && p.lng != null)
        .toList();
    if (withPos.isEmpty) return promos.take(limit).toList();

    // 3. Enrichir avec la distance
    final withDist = withPos.map((p) {
      final dist = Geolocator.distanceBetween(
        userLat, userLng, p.lat!, p.lng!,
      );
      return p.withDistance(dist);
    }).toList();

    // 4. Récupérer les catégories préférées de l'user
    final prefCats = await _getPreferredCategories(userId, withDist);

    // 5. Calculer le score max de vues pour normalisation
    final maxViews = withDist
        .map((p) => p.views)
        .fold<int>(1, (prev, v) => v > prev ? v : prev);

    // 6. Calculer le score de chaque promo
    final scored = withDist.map((p) {
      final score = _score(
        promo:         p,
        prefCats:      prefCats,
        maxViews:      maxViews,
      );
      return _ScoredPromo(promo: p, score: score);
    }).toList();

    // 7. Trier DESC par score et retourner les N premiers
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.promo).toList();
  }

  // ─── SCORE ────────────────────────────────────────────────────────────────

  static double _score({
    required PromoModel  promo,
    required Set<String> prefCats,
    required int         maxViews,
  }) {
    final proximityScore = _proximityScore(promo.distanceMeters ?? _maxDistanceM);
    final categoryScore  = _categoryScore(promo.category, prefCats);
    final popularityScore = _popularityScore(promo.views, maxViews);

    return (proximityScore * _wProximity)
         + (categoryScore  * _wCategory)
         + (popularityScore * _wPopularity);
  }

  static double _proximityScore(double distanceM) {
    if (distanceM <= 0) return 1.0;
    if (distanceM >= _maxDistanceM) return 0.0;
    return 1.0 - (distanceM / _maxDistanceM);
  }

  static double _categoryScore(String? cat, Set<String> prefCats) {
    if (cat == null || prefCats.isEmpty) return 0.0;
    return prefCats.contains(cat) ? 1.0 : 0.0;
  }

  static double _popularityScore(int views, int maxViews) {
    if (maxViews <= 0) return 0.0;
    return views / maxViews;
  }

  // ─── CATÉGORIES PRÉFÉRÉES ─────────────────────────────────────────────────
  // Déduites depuis les promos favorites de l'utilisateur

  static Future<Set<String>> _getPreferredCategories(
    String userId,
    List<PromoModel> allPromos,
  ) async {
    try {
      final favoriteIds = await FavoriteService.getFavoritePromoIds(userId);
      if (favoriteIds.isEmpty) return {};

      final favPromos = allPromos
          .where((p) => favoriteIds.contains(p.id) && p.category != null)
          .toList();

      return favPromos.map((p) => p.category!).toSet();
    } catch (_) {
      return {};
    }
  }
}

// ─── DATA CLASS INTERNE ───────────────────────────────────────────────────────

class _ScoredPromo {
  final PromoModel promo;
  final double     score;
  const _ScoredPromo({required this.promo, required this.score});
}
