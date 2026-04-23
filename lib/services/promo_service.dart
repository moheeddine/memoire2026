import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/promo_model.dart';
import 'business_service.dart';
import 'storage_service.dart';

// ─── QR SCAN RESULT ──────────────────────────────────────────────────────────

enum QrScanStatus { success, invalid, expired, alreadyUsed, error }

class QrScanResult {
  final QrScanStatus status;
  final PromoModel? promo;
  final String message;

  const QrScanResult._({
    required this.status,
    required this.message,
    this.promo,
  });

  factory QrScanResult.success(PromoModel promo) => QrScanResult._(
        status: QrScanStatus.success,
        message: 'QR code validé ! Profitez de votre réduction.',
        promo: promo,
      );

  factory QrScanResult.invalid() => const QrScanResult._(
        status: QrScanStatus.invalid,
        message: 'QR code invalide ou non reconnu.',
      );

  factory QrScanResult.expired() => const QrScanResult._(
        status: QrScanStatus.expired,
        message: 'Cette promotion a expiré.',
      );

  factory QrScanResult.alreadyUsed() => const QrScanResult._(
        status: QrScanStatus.alreadyUsed,
        message: 'Vous avez déjà utilisé cette promotion.',
      );

  factory QrScanResult.error(String detail) => QrScanResult._(
        status: QrScanStatus.error,
        message: 'Erreur : $detail',
      );

  bool get isSuccess => status == QrScanStatus.success;
}

// ─── SERVICE ─────────────────────────────────────────────────────────────────

class PromoService {
  static final _db = FirebaseFirestore.instance;

  static const _qrPrefix = 'cityone://promo/';

  // ─── STREAMS ──────────────────────────────────────────────────────────────

  static Stream<List<PromoModel>> watchApproved() {
    return _db
        .collection('promos')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map(PromoModel.fromDocument)
            .toList());
  }

  static Stream<List<PromoModel>> watchByBusiness(String businessId) {
    return _db
        .collection('promos')
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snap) => snap.docs
            .map(PromoModel.fromDocument)
            .toList());
  }

  static Stream<List<PromoModel>> watchByStatus(String status) {
    return _db
        .collection('promos')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snap) => snap.docs
            .map(PromoModel.fromDocument)
            .toList());
  }

  // ─── FETCH (avec JOIN business) ───────────────────────────────────────────

  static Future<List<PromoModel>> getApprovedWithBusinessData({
    int limit = 30,
  }) async {
    try {
      final snap = await _db
          .collection('promos')
          .where('status', isEqualTo: 'approved')
          .limit(limit)
          .get();

      final promos = snap.docs.map(PromoModel.fromDocument).toList();
      return _enrichWithBusinessData(promos);
    } catch (_) {
      return [];
    }
  }

  static Future<List<PromoModel>> getByBusiness(String businessId) async {
    try {
      final snap = await _db
          .collection('promos')
          .where('businessId', isEqualTo: businessId)
          .get();

      return snap.docs.map(PromoModel.fromDocument).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<PromoModel>> _enrichWithBusinessData(
      List<PromoModel> promos) async {
    if (promos.isEmpty) return promos;

    final businessIds =
        promos.map((p) => p.businessId).toSet().toList();

    final businessMap =
        await BusinessService.getBusinessesMap(businessIds);

    return promos.map((promo) {
      final business = businessMap[promo.businessId];
      if (business == null) return promo;
      return promo.withBusinessData(
        businessName: business.name,
        category:     business.category,
        lat:          business.lat,
        lng:          business.lng,
      );
    }).toList();
  }

  // ─── READ SINGLE ─────────────────────────────────────────────────────────

  static Future<PromoModel?> getPromo(String id) async {
    try {
      final doc = await _db.collection('promos').doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return PromoModel.fromDocument(doc);
    } catch (_) {
      return null;
    }
  }

  // ─── WRITE ────────────────────────────────────────────────────────────────

  /// Creates a new promo. Pass [imageFiles] (XFile list from image_picker)
  /// and they will be uploaded to Storage at promos/{promoId}/ before saving.
  /// Throws on upload failure or Firestore write failure.
  static Future<void> addPromo({
    required String businessId,
    required String title,
    required String description,
    required int    discount,
    required String code,
    required String conditions,
    required DateTime expirationDate,
    List<XFile> imageFiles = const [],
  }) async {
    final business = await BusinessService.getBusinessData(businessId);

    // Pre-generate the Firestore doc ID — used for both QR and storage path.
    final ref         = _db.collection('promos').doc();
    final promoId     = ref.id;
    final promoCode   = promoId;
    final qrCodeValue = '$_qrPrefix$promoId';

    // Upload images to promos/{promoId}/ — throws on failure.
    List<String> imageUrls = const [];
    if (imageFiles.isNotEmpty) {
      imageUrls = await StorageService.uploadPromoImages(promoId, imageFiles);
    }

    await ref.set({
      'title':          title,
      'description':    description,
      'discount':       discount,
      'code':           code.toUpperCase(),
      'conditions':     conditions,
      'businessId':     businessId,
      'status':         PromoStatus.pending.name,
      'expirationDate': Timestamp.fromDate(expirationDate),
      'views':          0,
      'clicks':         0,
      'used':           0,
      'createdAt':      FieldValue.serverTimestamp(),
      'promoCode':      promoCode,
      'qrCodeValue':    qrCodeValue,
      'scannedBy':      [],
      'imageUrls':      imageUrls,
      if (business != null) ...{
        'businessName': business.name,
        'category':     business.category,
        'lat':          business.lat,
        'lng':          business.lng,
      },
    });
  }

  static Future<void> updateStatus(
      String promoId, PromoStatus status) async {
    await _db
        .collection('promos')
        .doc(promoId)
        .update({'status': status.name});
  }

  static Future<void> approve(String promoId) =>
      updateStatus(promoId, PromoStatus.approved);

  static Future<void> reject(String promoId) =>
      updateStatus(promoId, PromoStatus.rejected);

  static Future<void> end(String promoId) =>
      updateStatus(promoId, PromoStatus.ended);

  static Future<void> delete(String promoId) async {
    await _db.collection('promos').doc(promoId).delete();
  }

  // ─── QR CODE VALIDATION ───────────────────────────────────────────────────

  /// Validates a scanned QR value, marks the promo as used by this user,
  /// and increments business conversion stats. Returns a [QrScanResult].
  static Future<QrScanResult> validateAndUseQr(
      String userId, String qrValue) async {
    try {
      if (!qrValue.startsWith(_qrPrefix)) return QrScanResult.invalid();

      final promoId = qrValue.substring(_qrPrefix.length);
      if (promoId.isEmpty) return QrScanResult.invalid();

      final doc = await _db.collection('promos').doc(promoId).get();
      if (!doc.exists || doc.data() == null) return QrScanResult.invalid();

      final promo = PromoModel.fromDocument(doc);

      if (promo.isExpired) return QrScanResult.expired();
      if (promo.scannedBy.contains(userId)) return QrScanResult.alreadyUsed();

      // Atomic update: add user to scannedBy + increment used
      await _db.collection('promos').doc(promoId).update({
        'scannedBy': FieldValue.arrayUnion([userId]),
        'used':      FieldValue.increment(1),
      });

      // Increment business conversion stat
      await BusinessService.incrementStat(promo.businessId, 'conversions');

      return QrScanResult.success(promo);
    } catch (e) {
      return QrScanResult.error(e.toString());
    }
  }

  // ─── ANALYTICS (incréments atomiques) ────────────────────────────────────

  static Future<void> incrementView(String promoId) async {
    try {
      await _db.collection('promos').doc(promoId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  static Future<void> incrementClick(String promoId) async {
    try {
      await _db.collection('promos').doc(promoId).update({
        'clicks': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  static Future<void> incrementUsed(String promoId) async {
    try {
      await _db.collection('promos').doc(promoId).update({
        'used': FieldValue.increment(1),
      });
    } catch (_) {}
  }
}
