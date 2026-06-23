import 'package:cloud_firestore/cloud_firestore.dart';

enum BusinessStatus { active, pending, rejected, unknown }

class BusinessStats {
  final int views;
  final int clicks;
  final int conversions;
  final int savings;

  const BusinessStats({
    this.views = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.savings = 0,
  });

  factory BusinessStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BusinessStats();
    return BusinessStats(
      views:       (map['views'] as num?)?.toInt() ?? 0,
      clicks:      (map['clicks'] as num?)?.toInt() ?? 0,
      conversions: (map['conversions'] as num?)?.toInt() ?? 0,
      savings:     (map['savings'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'views':       views,
    'clicks':      clicks,
    'conversions': conversions,
    'savings':     savings,
  };
}

class WeeklyViews {
  final int lun, mar, mer, jeu, ven, sam, dim;

  const WeeklyViews({
    this.lun = 0, this.mar = 0, this.mer = 0,
    this.jeu = 0, this.ven = 0, this.sam = 0, this.dim = 0,
  });

  factory WeeklyViews.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WeeklyViews();
    return WeeklyViews(
      lun: (map['lun'] as num?)?.toInt() ?? 0,
      mar: (map['mar'] as num?)?.toInt() ?? 0,
      mer: (map['mer'] as num?)?.toInt() ?? 0,
      jeu: (map['jeu'] as num?)?.toInt() ?? 0,
      ven: (map['ven'] as num?)?.toInt() ?? 0,
      sam: (map['sam'] as num?)?.toInt() ?? 0,
      dim: (map['dim'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'lun': lun, 'mar': mar, 'mer': mer,
    'jeu': jeu, 'ven': ven, 'sam': sam, 'dim': dim,
  };

  List<int> get asList => [lun, mar, mer, jeu, ven, sam, dim];
  int get max => asList.reduce((a, b) => a > b ? a : b);
}

class BusinessModel {
  final String uid;
  final String name;
  final String ownerName;
  final String email;
  final String matricule;
  final String category;
  final double lat;
  final double lng;
  final BusinessStatus status;
  final BusinessStats stats;
  final WeeklyViews weeklyViews;
  final DateTime? createdAt;
  final String? matriculeImageUrl;
  final double averageRating;
  final int ratingCount;

  const BusinessModel({
    required this.uid,
    required this.name,
    required this.ownerName,
    required this.email,
    required this.matricule,
    required this.category,
    required this.lat,
    required this.lng,
    required this.status,
    this.stats = const BusinessStats(),
    this.weeklyViews = const WeeklyViews(),
    this.createdAt,
    this.matriculeImageUrl,
    this.averageRating = 0.0,
    this.ratingCount = 0,
  });

  // ─── FACTORY ─────────────────────────────────────────────────────────────

  factory BusinessModel.fromMap(String uid, Map<String, dynamic> map) {
    return BusinessModel(
      uid:        uid,
      name:       map['name'] as String? ?? '',
      ownerName:  map['ownerName'] as String? ?? '',
      email:      map['email'] as String? ?? '',
      matricule:  map['matricule'] as String? ?? '',
      category:   map['category'] as String? ?? '',
      lat:        (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng:        (map['lng'] as num?)?.toDouble() ?? 0.0,
      status:     _parseStatus(map['status'] as String?),
      stats:      BusinessStats.fromMap(
                    map['stats'] as Map<String, dynamic>?),
      weeklyViews: WeeklyViews.fromMap(
                    map['weekly_views'] as Map<String, dynamic>?),
      createdAt:         (map['createdAt'] as Timestamp?)?.toDate(),
      matriculeImageUrl: map['matriculeImageUrl'] as String?,
      averageRating:     (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount:       (map['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory BusinessModel.fromDocument(DocumentSnapshot doc) {
    return BusinessModel.fromMap(
      doc.id,
      doc.data() as Map<String, dynamic>? ?? {},
    );
  }

  // ─── TO MAP ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'name':         name,
      'ownerName':    ownerName,
      'email':        email,
      'matricule':    matricule,
      'category':     category,
      'lat':          lat,
      'lng':          lng,
      'status':       status.name,
      'stats':        stats.toMap(),
      'weekly_views': weeklyViews.toMap(),
    };
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  bool get isActive  => status == BusinessStatus.active;
  bool get isPending => status == BusinessStatus.pending;

  static BusinessStatus _parseStatus(String? value) {
    switch (value) {
      case 'active':   return BusinessStatus.active;
      case 'pending':  return BusinessStatus.pending;
      case 'rejected': return BusinessStatus.rejected;
      default:         return BusinessStatus.unknown;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessModel && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'BusinessModel(uid: $uid, name: $name, status: ${status.name})';
}
