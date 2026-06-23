import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoStatus { pending, approved, rejected, ended, expired, unknown }

class PromoModel {
  final String id;
  final String title;
  final String description;

  // ─── Pricing (new system) ─────────────────────────────────────────────────
  // Old promos only have [discount] (int %).
  // New promos also carry [oldPrice], [newPrice], [discountPercentage],
  // [savedAmount] for rich display.
  final double? oldPrice;          // original price in DT
  final double? newPrice;          // promotional price in DT
  final double? discountPercentage;// precise % e.g. 25.0
  final double? savedAmount;       // oldPrice - newPrice
  // Legacy field kept for backward compat; computed from discountPercentage
  // if available, otherwise stored directly.
  final int    discount;

  final String code;
  final String conditions;
  final DateTime? startDate;
  final DateTime? expirationDate;
  final String businessId;
  final PromoStatus status;
  final int views;
  final int clicks;
  final int used;
  final DateTime? createdAt;

  // QR code fields
  final String? promoCode;
  final String? qrCodeValue;
  final List<String> scannedBy;

  // Flash deal
  final bool      isFlashDeal;
  final DateTime? flashEndTime;

  // Media
  final List<String> imageUrls;

  // Limitation fields
  final int?  maxReservations;
  final int   currentReservations;
  final bool  isActive;

  // Denormalized from business (client-side join, not stored again)
  final String? businessName;
  final String? category;
  final double? lat;
  final double? lng;
  final double? distanceMeters;

  const PromoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.discount,
    required this.code,
    required this.conditions,
    required this.businessId,
    required this.status,
    // Pricing
    this.oldPrice,
    this.newPrice,
    this.discountPercentage,
    this.savedAmount,
    // Dates
    this.startDate,
    this.expirationDate,
    this.views = 0,
    this.clicks = 0,
    this.used = 0,
    this.createdAt,
    this.promoCode,
    this.qrCodeValue,
    this.scannedBy    = const [],
    this.imageUrls    = const [],
    this.isFlashDeal  = false,
    this.flashEndTime,
    this.maxReservations,
    this.currentReservations = 0,
    this.isActive = true,
    this.businessName,
    this.category,
    this.lat,
    this.lng,
    this.distanceMeters,
  });

  // ─── FACTORY ─────────────────────────────────────────────────────────────

  factory PromoModel.fromMap(String id, Map<String, dynamic> map) {
    final discPct   = (map['discountPercentage'] as num?)?.toDouble();
    final legacyInt = (map['discount'] as num?)?.toInt() ?? 0;
    return PromoModel(
      id:               id,
      title:            map['title']        as String? ?? '',
      description:      map['description']  as String? ?? '',
      // Pricing
      oldPrice:          (map['oldPrice']          as num?)?.toDouble(),
      newPrice:          (map['newPrice']           as num?)?.toDouble(),
      discountPercentage: discPct,
      savedAmount:       (map['savedAmount']        as num?)?.toDouble(),
      discount:          discPct?.round() ?? legacyInt,
      code:             map['code']        as String? ?? '',
      conditions:       map['conditions']  as String? ?? '',
      businessId:       map['businessId']  as String? ?? '',
      status:           _parseStatus(map['status'] as String?),
      startDate:        (map['startDate']      as Timestamp?)?.toDate(),
      expirationDate:   (map['expirationDate'] as Timestamp?)?.toDate(),
      views:            (map['views']  as num?)?.toInt() ?? 0,
      clicks:           (map['clicks'] as num?)?.toInt() ?? 0,
      used:             (map['used']   as num?)?.toInt() ?? 0,
      createdAt:        (map['createdAt'] as Timestamp?)?.toDate(),
      promoCode:        map['promoCode']   as String?,
      qrCodeValue:      map['qrCodeValue'] as String?,
      scannedBy:        List<String>.from(map['scannedBy'] as List? ?? []),
      imageUrls:        List<String>.from(map['imageUrls'] as List? ?? []),
      isFlashDeal:      map['isFlashDeal'] as bool? ?? false,
      flashEndTime:     (map['flashEndTime'] as Timestamp?)?.toDate(),
      maxReservations:     (map['maxReservations']     as num?)?.toInt(),
      currentReservations: (map['currentReservations'] as num?)?.toInt() ?? 0,
      isActive:            map['isActive'] as bool? ?? true,
      businessName: map['businessName'] as String?,
      category:     map['category']     as String?,
      lat:          (map['lat'] as num?)?.toDouble(),
      lng:          (map['lng'] as num?)?.toDouble(),
    );
  }

  factory PromoModel.fromDocument(DocumentSnapshot doc) {
    return PromoModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ─── TO MAP ───────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'title':       title,
      'description': description,
      // Pricing
      if (oldPrice != null)          'oldPrice':          oldPrice,
      if (newPrice != null)          'newPrice':          newPrice,
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (savedAmount != null)       'savedAmount':       savedAmount,
      'discount':    discount,
      'code':        code,
      'conditions':  conditions,
      'businessId':  businessId,
      'status':      status.name,
      if (startDate != null)
        'startDate': Timestamp.fromDate(startDate!),
      if (expirationDate != null)
        'expirationDate': Timestamp.fromDate(expirationDate!),
      'views':   views,
      'clicks':  clicks,
      'used':    used,
      'createdAt': FieldValue.serverTimestamp(),
      if (promoCode != null)   'promoCode':   promoCode,
      if (qrCodeValue != null) 'qrCodeValue': qrCodeValue,
      'scannedBy': scannedBy,
      'imageUrls': imageUrls,
      'isFlashDeal': isFlashDeal,
      if (isFlashDeal && flashEndTime != null)
        'flashEndTime': Timestamp.fromDate(flashEndTime!),
      'isActive':            isActive,
      'currentReservations': currentReservations,
      if (maxReservations != null) 'maxReservations': maxReservations,
    };
  }

  // ─── COPY WITH ────────────────────────────────────────────────────────────

  PromoModel withBusinessData({
    required String businessName,
    required String category,
    required double lat,
    required double lng,
  }) {
    return _copyWith(
      businessName: businessName,
      category:     category,
      lat:          lat,
      lng:          lng,
    );
  }

  PromoModel withDistance(double meters) => _copyWith(distanceMeters: meters);

  PromoModel _copyWith({
    String?  businessName,
    String?  category,
    double?  lat,
    double?  lng,
    double?  distanceMeters,
  }) {
    return PromoModel(
      id:               id,
      title:            title,
      description:      description,
      oldPrice:         oldPrice,
      newPrice:         newPrice,
      discountPercentage: discountPercentage,
      savedAmount:      savedAmount,
      discount:         discount,
      code:             code,
      conditions:       conditions,
      businessId:       businessId,
      status:           status,
      startDate:        startDate,
      expirationDate:   expirationDate,
      views:            views,
      clicks:           clicks,
      used:             used,
      createdAt:        createdAt,
      promoCode:        promoCode,
      qrCodeValue:      qrCodeValue,
      scannedBy:        scannedBy,
      imageUrls:        imageUrls,
      isFlashDeal:      isFlashDeal,
      flashEndTime:     flashEndTime,
      maxReservations:      maxReservations,
      currentReservations:  currentReservations,
      isActive:         isActive,
      businessName:     businessName  ?? this.businessName,
      category:         category      ?? this.category,
      lat:              lat           ?? this.lat,
      lng:              lng           ?? this.lng,
      distanceMeters:   distanceMeters ?? this.distanceMeters,
    );
  }

  // ─── COMPUTED DISPLAY HELPERS ─────────────────────────────────────────────

  /// Whether this promo carries full pricing data (oldPrice + newPrice).
  bool get hasPricingData => oldPrice != null && newPrice != null;

  /// Effective discount % for display (precise or legacy int).
  double get effectiveDiscountPct => discountPercentage ?? discount.toDouble();

  /// Savings amount for display.
  double? get effectiveSavedAmount =>
      savedAmount ?? (hasPricingData ? oldPrice! - newPrice! : null);

  // ─── STATUS / EXPIRATION ─────────────────────────────────────────────────

  bool get isApproved  => status == PromoStatus.approved;
  bool get isPending   => status == PromoStatus.pending;
  bool get isExpired   =>
      expirationDate != null && expirationDate!.isBefore(DateTime.now());
  bool get isFlashActive =>
      isFlashDeal && flashEndTime != null &&
      flashEndTime!.isAfter(DateTime.now());

  bool get isLimitReached =>
      maxReservations != null && currentReservations >= maxReservations!;

  bool get isEffectivelyActive =>
      isActive && !isLimitReached &&
      (expirationDate == null || expirationDate!.isAfter(DateTime.now()));

  int? get remainingSpots =>
      maxReservations != null ? maxReservations! - currentReservations : null;

  double? get distanceKm =>
      distanceMeters != null ? distanceMeters! / 1000 : null;

  String get distanceLabel =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : '--';

  // ─── URGENCY ──────────────────────────────────────────────────────────────

  /// Hours remaining until expiry. Null if no expiration date.
  double? get hoursUntilExpiry {
    if (expirationDate == null) return null;
    final diff = expirationDate!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inMinutes / 60.0;
  }

  /// True when less than 24 hours remain. Shows "Expire bientôt" badge.
  bool get isExpiringSoon {
    final h = hoursUntilExpiry;
    return h != null && h > 0 && h < 24;
  }

  /// Less than 6 hours remaining — high urgency.
  bool get isCriticallyExpiring {
    final h = hoursUntilExpiry;
    return h != null && h > 0 && h < 6;
  }

  /// Less than 1 hour remaining — emergency urgency.
  bool get isEmergencyExpiring {
    final h = hoursUntilExpiry;
    return h != null && h > 0 && h < 1;
  }

  /// Emoji prefix for urgency level: 🚨 < 1h, ⚠️ < 6h, ⏰ < 24h.
  String get urgencyEmoji {
    if (isEmergencyExpiring)  return '🚨';
    if (isCriticallyExpiring) return '⚠️';
    if (isExpiringSoon)       return '⏰';
    return '';
  }

  /// Short countdown label for cards (e.g. "⏰ 23h" / "⚠️ 5h 30m" / "🚨 45m").
  String get urgencyCountdown {
    final h = hoursUntilExpiry;
    if (h == null || h <= 0) return '';
    if (h < 1) {
      final mins = (h * 60).round();
      return '🚨 ${mins}m';
    }
    if (h < 6) {
      final hours = h.floor();
      final mins  = ((h - hours) * 60).round();
      return mins > 0 ? '⚠️ ${hours}h ${mins}m' : '⚠️ ${hours}h';
    }
    return '⏰ ${h.floor()}h';
  }

  // ─── PARSE ────────────────────────────────────────────────────────────────

  static PromoStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':  return PromoStatus.pending;
      case 'approved': return PromoStatus.approved;
      case 'rejected': return PromoStatus.rejected;
      case 'ended':    return PromoStatus.ended;
      case 'expired':  return PromoStatus.expired;
      default:         return PromoStatus.unknown;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PromoModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PromoModel(id: $id, title: $title, discount: ${effectiveDiscountPct.toStringAsFixed(0)}%)';
}
