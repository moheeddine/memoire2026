import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoStatus { pending, approved, rejected, ended, unknown }

class PromoModel {
  final String id;
  final String title;
  final String description;
  final int discount;
  final String code;
  final String conditions;
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

  // Media
  final List<String> imageUrls;

  // Champs enrichis après JOIN avec BusinessModel (non stockés dans Firestore)
  final String? businessName;
  final String? category;
  final double? lat;
  final double? lng;
  // Distance calculée côté client (non stockée)
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
    this.expirationDate,
    this.views = 0,
    this.clicks = 0,
    this.used = 0,
    this.createdAt,
    this.promoCode,
    this.qrCodeValue,
    this.scannedBy = const [],
    this.imageUrls = const [],
    // Champs enrichis — null par défaut
    this.businessName,
    this.category,
    this.lat,
    this.lng,
    this.distanceMeters,
  });

  // ─── FACTORY ─────────────────────────────────────────────────────────────

  factory PromoModel.fromMap(String id, Map<String, dynamic> map) {
    return PromoModel(
      id:             id,
      title:          map['title'] as String? ?? '',
      description:    map['description'] as String? ?? '',
      discount:       (map['discount'] as num?)?.toInt() ?? 0,
      code:           map['code'] as String? ?? '',
      conditions:     map['conditions'] as String? ?? '',
      businessId:     map['businessId'] as String? ?? '',
      status:         _parseStatus(map['status'] as String?),
      expirationDate: (map['expirationDate'] as Timestamp?)?.toDate(),
      views:          (map['views'] as num?)?.toInt() ?? 0,
      clicks:         (map['clicks'] as num?)?.toInt() ?? 0,
      used:           (map['used'] as num?)?.toInt() ?? 0,
      createdAt:      (map['createdAt'] as Timestamp?)?.toDate(),
      promoCode:      map['promoCode'] as String?,
      qrCodeValue:    map['qrCodeValue'] as String?,
      scannedBy:      List<String>.from(map['scannedBy'] as List? ?? []),
      imageUrls:      List<String>.from(map['imageUrls'] as List? ?? []),
      // Denormalized fields — stored at creation time from business doc
      businessName:   map['businessName'] as String?,
      category:       map['category'] as String?,
      lat:            (map['lat'] as num?)?.toDouble(),
      lng:            (map['lng'] as num?)?.toDouble(),
    );
  }

  factory PromoModel.fromDocument(DocumentSnapshot doc) {
    return PromoModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ─── TO MAP (pour Firestore — sans champs enrichis) ───────────────────────

  Map<String, dynamic> toMap() {
    return {
      'title':          title,
      'description':    description,
      'discount':       discount,
      'code':           code,
      'conditions':     conditions,
      'businessId':     businessId,
      'status':         status.name,
      if (expirationDate != null)
        'expirationDate': Timestamp.fromDate(expirationDate!),
      'views':          views,
      'clicks':         clicks,
      'used':           used,
      'createdAt':      FieldValue.serverTimestamp(),
      if (promoCode != null)    'promoCode':   promoCode,
      if (qrCodeValue != null)  'qrCodeValue': qrCodeValue,
      'scannedBy':   scannedBy,
      'imageUrls':   imageUrls,
    };
  }

  // ─── COPY WITH (pour enrichissement après JOIN) ───────────────────────────

  PromoModel withBusinessData({
    required String businessName,
    required String category,
    required double lat,
    required double lng,
  }) {
    return PromoModel(
      id:             id,
      title:          title,
      description:    description,
      discount:       discount,
      code:           code,
      conditions:     conditions,
      businessId:     businessId,
      status:         status,
      expirationDate: expirationDate,
      views:          views,
      clicks:         clicks,
      used:           used,
      createdAt:      createdAt,
      promoCode:      promoCode,
      qrCodeValue:    qrCodeValue,
      scannedBy:      scannedBy,
      imageUrls:      imageUrls,
      businessName:   businessName,
      category:       category,
      lat:            lat,
      lng:            lng,
      distanceMeters: distanceMeters,
    );
  }

  PromoModel withDistance(double meters) {
    return PromoModel(
      id:             id,
      title:          title,
      description:    description,
      discount:       discount,
      code:           code,
      conditions:     conditions,
      businessId:     businessId,
      status:         status,
      expirationDate: expirationDate,
      views:          views,
      clicks:         clicks,
      used:           used,
      createdAt:      createdAt,
      promoCode:      promoCode,
      qrCodeValue:    qrCodeValue,
      scannedBy:      scannedBy,
      imageUrls:      imageUrls,
      businessName:   businessName,
      category:       category,
      lat:            lat,
      lng:            lng,
      distanceMeters: meters,
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool get isApproved => status == PromoStatus.approved;
  bool get isPending  => status == PromoStatus.pending;
  bool get isExpired  =>
      expirationDate != null && expirationDate!.isBefore(DateTime.now());

  double? get distanceKm =>
      distanceMeters != null ? distanceMeters! / 1000 : null;

  String get distanceLabel =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : '--';

  static PromoStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':  return PromoStatus.pending;
      case 'approved': return PromoStatus.approved;
      case 'rejected': return PromoStatus.rejected;
      case 'ended':    return PromoStatus.ended;
      default:         return PromoStatus.unknown;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromoModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PromoModel(id: $id, title: $title, discount: $discount%)';
}
