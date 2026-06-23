import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/promo_model.dart';
import '../utils/error_handler.dart';
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
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(PromoModel.fromDocument)
            .where((p) => p.isEffectivelyActive)
            .toList());
  }

  static Stream<List<PromoModel>> watchFlashDeals() {
    return _db
        .collection('promos')
        .where('status', isEqualTo: 'approved')
        .where('isFlashDeal', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(PromoModel.fromDocument)
            .where((p) => p.isFlashActive)
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

  /// Retourne uniquement les promos actives et non expirées d'un business.
  /// Utilisé par le Dashboard Entreprise pour ne pas afficher les expirées.
  static Stream<List<PromoModel>> watchActiveByBusiness(String businessId) {
    return _db
        .collection('promos')
        .where('businessId', isEqualTo: businessId)
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) => snap.docs
            .map(PromoModel.fromDocument)
            .where((p) => !p.isExpired)
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
    final now = DateTime.now();
    if (_approvedCache != null &&
        _approvedCacheAt != null &&
        now.difference(_approvedCacheAt!) < _cacheTtl) {
      return _approvedCache!;
    }

    try {
      final snap = await _db
          .collection('promos')
          .where('status', isEqualTo: 'approved')
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();

      final promos  = snap.docs.map(PromoModel.fromDocument).toList();
      final enriched = await _enrichWithBusinessData(promos);
      final result   = enriched.where((p) => p.isEffectivelyActive).toList();
      _approvedCache   = result;
      _approvedCacheAt = now;
      return result;
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
    // Pricing — new system (at least one of the two groups must be provided)
    double? oldPrice,
    double? newPrice,
    double? discountPercentage,
    double? savedAmount,
    // Legacy fallback (computed automatically when oldPrice/newPrice are given)
    int     discount = 0,
    required String code,
    required String conditions,
    DateTime? startDate,
    required DateTime expirationDate,
    List<XFile> imageFiles            = const [],
    bool isFlashDeal                  = false,
    DateTime? flashEndTime,
    int? maxReservations,
    void Function(int done, int total)? onImageProgress,
  }) async {
    // Derive legacy int discount from new pricing when available.
    final effectiveDiscount = discountPercentage?.round() ?? discount;

    final business = await BusinessService.getBusinessData(businessId);

    final ref         = _db.collection('promos').doc();
    final promoId     = ref.id;
    final promoCode   = promoId;
    final qrCodeValue = '$_qrPrefix$promoId';

    List<String> imageUrls = const [];
    if (imageFiles.isNotEmpty) {
      imageUrls = await StorageService.uploadPromoImages(
        promoId,
        imageFiles,
        onProgress: onImageProgress,
      );
    }

    await ref.set({
      'title':       title,
      'description': description,
      // Pricing
      if (oldPrice != null)          'oldPrice':          oldPrice,
      if (newPrice != null)          'newPrice':          newPrice,
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (savedAmount != null)       'savedAmount':       savedAmount,
      'discount':    effectiveDiscount,
      'code':        code.toUpperCase(),
      'conditions':  conditions,
      'businessId':  businessId,
      'status':      PromoStatus.approved.name,
      if (startDate != null)
        'startDate': Timestamp.fromDate(startDate),
      'expirationDate': Timestamp.fromDate(expirationDate),
      'views':   0,
      'clicks':  0,
      'used':    0,
      'createdAt':   FieldValue.serverTimestamp(),
      'promoCode':   promoCode,
      'qrCodeValue': qrCodeValue,
      'scannedBy':   [],
      'imageUrls':   imageUrls,
      'isFlashDeal': isFlashDeal,
      if (isFlashDeal && flashEndTime != null)
        'flashEndTime': Timestamp.fromDate(flashEndTime),
      'isActive':            true,
      'currentReservations': 0,
      if (maxReservations != null) 'maxReservations': maxReservations,
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

  static Future<void> updatePromo({
    required String promoId,
    required String title,
    required String description,
    double? oldPrice,
    double? newPrice,
    double? discountPercentage,
    double? savedAmount,
    int     discount = 0,
    required String code,
    required String conditions,
    DateTime? startDate,
    required DateTime expirationDate,
    bool isFlashDeal      = false,
    DateTime? flashEndTime,
    int? maxReservations,
  }) async {
    final effectiveDiscount = discountPercentage?.round() ?? discount;
    final data = <String, dynamic>{
      'title':       title,
      'description': description,
      if (oldPrice != null)          'oldPrice':          oldPrice,
      if (newPrice != null)          'newPrice':          newPrice,
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (savedAmount != null)       'savedAmount':       savedAmount,
      'discount':    effectiveDiscount,
      'code':        code.toUpperCase(),
      'conditions':  conditions,
      if (startDate != null)
        'startDate': Timestamp.fromDate(startDate),
      'expirationDate': Timestamp.fromDate(expirationDate),
      'isFlashDeal':    isFlashDeal,
    };

    if (isFlashDeal && flashEndTime != null) {
      data['flashEndTime'] = Timestamp.fromDate(flashEndTime);
    } else {
      data['flashEndTime'] = FieldValue.delete();
    }

    if (maxReservations != null) {
      data['maxReservations'] = maxReservations;
    } else {
      data['maxReservations'] = FieldValue.delete();
    }

    await _db.collection('promos').doc(promoId).update(data);
  }

  static Future<void> delete(String promoId) async {
    await _db.collection('promos').doc(promoId).delete();
  }

  // ─── RESERVATION LIMIT ────────────────────────────────────────────────────

  /// Atomically increments currentReservations. Returns false if limit already reached.
  static Future<bool> tryIncrementReservations(String promoId) async {
    try {
      final ref = _db.collection('promos').doc(promoId);
      bool ok = false;
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data();
        if (data == null) return;
        final max = data['maxReservations'] as int?;
        final cur = (data['currentReservations'] as num?)?.toInt() ?? 0;
        if (max != null && cur >= max) return; // limit hit
        tx.update(ref, {
          'currentReservations': FieldValue.increment(1),
          if (max != null && cur + 1 >= max) 'isActive': false,
        });
        ok = true;
      });
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Marks a promo inactive (used when expiration date is reached).
  static Future<void> deactivate(String promoId) async {
    try {
      await _db.collection('promos').doc(promoId).update({'isActive': false});
    } catch (_) {}
  }

  // ─── APPROVED PROMOS CACHE ────────────────────────────────────────────────
  // Prevents duplicate Firestore reads when multiple callers (e.g. recommendations
  // + popular-nearby) request the same approved-promo list within a short window.
  static List<PromoModel>? _approvedCache;
  static DateTime?         _approvedCacheAt;
  static const Duration    _cacheTtl = Duration(minutes: 2);

  // Debounce: run at most once per app session.
  static DateTime? _lastExpireCheck;

  /// Batch-marks all promos whose expirationDate has passed as
  /// isActive=false / status='expired'. Uses a single-field range query on
  /// expirationDate (no composite index required). Returns count updated.
  static Future<int> autoExpirePromos() async {
    final now = DateTime.now();
    if (_lastExpireCheck != null &&
        now.difference(_lastExpireCheck!).inMinutes < 15) { return 0; }
    _lastExpireCheck = now;

    try {
      final snap = await _db
          .collection('promos')
          .where('expirationDate',
              isLessThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      if (snap.docs.isEmpty) return 0;

      final batch = _db.batch();
      var count = 0;

      for (final doc in snap.docs) {
        final data     = doc.data();
        final isActive = data['isActive'] as bool? ?? true;
        final status   = data['status']   as String? ?? '';
        // Only touch promos still considered active/approved
        if (!isActive || status == 'expired' || status == 'ended' ||
            status == 'rejected' || status == 'pending') { continue; }

        batch.update(doc.reference, {
          'isActive': false,
          'status':   'expired',
        });
        count++;
      }

      if (count > 0) await batch.commit();
      if (kDebugMode) debugPrint('[PromoService] autoExpire: $count promo(s) expired');
      return count;
    } catch (e) {
      if (kDebugMode) debugPrint('[PromoService] autoExpire error: $e');
      return 0;
    }
  }

  /// Returns true if the promo should still accept reservations.
  static bool canReserve(PromoModel promo) => promo.isEffectivelyActive;

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
      AppErrorHandler.log('QR.validate', e);
      return QrScanResult.error(AppErrorHandler.getMessage(e));
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
