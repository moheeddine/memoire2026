import '../models/promo_model.dart';

/// Lightweight utility for computing expiration and spot availability labels.
/// Pure logic — no state, no streams.
class PromoExpirationChecker {
  PromoExpirationChecker._();

  /// Returns a human-readable countdown string for the promo's expiration.
  /// Returns null if no expiration date.
  static String? expirationCountdown(PromoModel promo) {
    if (promo.expirationDate == null) return null;
    final diff = promo.expirationDate!.difference(DateTime.now());
    if (diff.isNegative) return 'Expirée';
    if (diff.inDays >= 1) {
      final days  = diff.inDays;
      final hours = diff.inHours - days * 24;
      return hours > 0
          ? 'Expire dans ${days}j ${hours}h'
          : 'Expire dans ${days}j';
    }
    if (diff.inHours >= 1) {
      final hours   = diff.inHours;
      final minutes = diff.inMinutes - hours * 60;
      return minutes > 0
          ? 'Expire dans ${hours}h ${minutes}m'
          : 'Expire dans ${hours}h';
    }
    final minutes = diff.inMinutes;
    if (minutes <= 0) return 'Expirée';
    return 'Expire dans ${minutes}m';
  }

  /// Returns a human-readable string for remaining spots.
  /// Returns null if there is no reservation limit.
  static String? remainingSpotsLabel(PromoModel promo) {
    final spots = promo.remainingSpots;
    if (spots == null) return null;
    if (spots <= 0) return 'Complet';
    if (spots <= 5) return '⚠️ $spots places restantes';
    return '👥 $spots places restantes';
  }

  /// Returns true if a notification should be sent (promo almost full: <=5 spots left).
  static bool isAlmostFull(PromoModel promo) {
    final spots = promo.remainingSpots;
    return spots != null && spots <= 5 && spots > 0;
  }
}
