import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/promo_model.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../services/promo_service.dart';
import '../services/rating_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import '../widgets/promo_image_gallery.dart';
import '../widgets/required_label.dart';
import '../widgets/star_rating_widget.dart';
import '../services/notification_manager.dart';
import '../services/reservation_service.dart';
import '../utils/validators.dart';
import '../utils/promo_expiration_checker.dart';
import '../widgets/comment_section.dart';
import 'chat_screen.dart';
import 'qr_scanner_screen.dart';

class PromoDetailScreen extends StatefulWidget {
  final PromoModel promo;

  /// Si renseigné, la section commentaires scrolle et surligne ce commentaire.
  final String? scrollToCommentId;

  const PromoDetailScreen({
    super.key,
    required this.promo,
    this.scrollToCommentId,
  });

  @override
  State<PromoDetailScreen> createState() => _PromoDetailScreenState();
}

class _PromoDetailScreenState extends State<PromoDetailScreen> {
  bool _isFav                  = false;
  double _rating               = 0.0;
  bool _codeCopied             = false;
  bool _hasActiveReservation   = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;

    if (widget.promo.id.isNotEmpty) {
      PromoService.incrementView(widget.promo.id);
    }

    final results = await Future.wait([
      FavoriteService.isFavoritePromo(uid, widget.promo.id),
      RatingService.getUserRating(uid, widget.promo.businessId),
      ReservationService.hasActiveReservation(uid, widget.promo.id),
    ]);
    if (mounted) {
      setState(() {
        _isFav                = results[0] as bool;
        _rating               = (results[1] as double?) ?? 0.0;
        _hasActiveReservation = (results[2] as bool) || !widget.promo.isEffectivelyActive;
      });
    }
  }

  Future<void> _toggleFav() async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    final added = await FavoriteService.togglePromoFavorite(uid, widget.promo.id);
    if (mounted) setState(() => _isFav = added);
  }

  Future<void> _rate(double score) async {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    await RatingService.rate(uid, widget.promo.businessId, score);
    if (mounted) setState(() => _rating = score);
  }

  Future<void> _useCode() async {
    final uid = AuthService.currentUid;
    if (uid != null) await PromoService.incrementUsed(widget.promo.id);
    await Clipboard.setData(ClipboardData(text: widget.promo.code));
    if (mounted) {
      setState(() => _codeCopied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copié dans le presse-papiers !'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _codeCopied = false);
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final promo = widget.promo;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // ── Sticky reservation CTA ─────────────────────────────────────────────
      bottomNavigationBar: _StickyReservationBar(
        promo: promo,
        hasActiveReservation: _hasActiveReservation,
        onReserve: () => _showReservationModal(promo),
      ),
      body: CustomScrollView(
        slivers: [
          // ─── Hero header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: promo.imageUrls.isNotEmpty ? 300.0 : 240.0,
            pinned: true,
            backgroundColor: Colors.transparent,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textDark, size: 18),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFav ? AppColors.accent : AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: promo.imageUrls.isNotEmpty
                  // ── Image gallery header ──────────────────────────────────
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: PromoImageGallery(imageUrls: promo.imageUrls),
                        ),
                        // Discount badge overlaid at bottom-left (above dots)
                        Positioned(
                          bottom: 52,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '-${promo.discount}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  // ── Gradient header (no images) ───────────────────────────
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.mainGradient,
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -40, right: -40,
                            child: _bgCircle(180, Colors.white, 0.1),
                          ),
                          Positioned(
                            bottom: -30, left: -30,
                            child: _bgCircle(120, Colors.white, 0.08),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '-${promo.discount}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (promo.businessName != null)
                                  Text(
                                    promo.businessName!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // ─── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + distance
                  Text(
                    promo.title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (promo.lat != null && promo.lng != null) ...[
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          promo.distanceLabel,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      const Icon(Icons.remove_red_eye_outlined,
                          color: AppColors.textLight, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${promo.views} vues',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (promo.isExpired) _badge('Expirée', AppColors.error),
                      if (promo.category != null)
                        _badge(promo.category!, AppColors.primary),
                      _badge('${promo.used} utilisations', AppColors.success),
                      // Expiration countdown badge
                      Builder(builder: (_) {
                        final countdown =
                            PromoExpirationChecker.expirationCountdown(promo);
                        if (countdown == null) return const SizedBox.shrink();
                        final isExp = countdown == 'Expirée';
                        return _badge(
                          '⏳ $countdown',
                          isExp ? AppColors.error : const Color(0xFFF97316),
                        );
                      }),
                      // Remaining spots badge
                      Builder(builder: (_) {
                        final spotsLabel =
                            PromoExpirationChecker.remainingSpotsLabel(promo);
                        if (spotsLabel == null) return const SizedBox.shrink();
                        final isFull = spotsLabel == 'Complet';
                        return _badge(
                          spotsLabel,
                          isFull
                              ? AppColors.error
                              : PromoExpirationChecker.isAlmostFull(promo)
                                  ? const Color(0xFF8B5CF6)
                                  : AppColors.info,
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Description
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          promo.description,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Conditions
                  if (promo.conditions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionCard(
                      borderColor: AppColors.warning,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              promo.conditions,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Promo code
                  if (promo.code.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _useCode,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppColors.softGradient,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CODE PROMO',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    promo.code,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Appuyez pour copier',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _codeCopied
                                    ? Icons.check_circle_rounded
                                    : Icons.copy_rounded,
                                key: ValueKey(_codeCopied),
                                color: _codeCopied
                                    ? AppColors.success
                                    : AppColors.primary,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ─── QR Code card ────────────────────────────────────────
                  if (promo.qrCodeValue != null) ...[
                    const SizedBox(height: 20),
                    _QrCard(
                      qrValue: promo.qrCodeValue!,
                      promoCode: promo.promoCode ?? promo.id,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ─── Action buttons ──────────────────────────────────────
                  GradientButton(
                    label: 'Utiliser ce code promo',
                    onTap: _useCode,
                    icon: Icons.local_offer_rounded,
                  ),

                  if (promo.lat != null && promo.lng != null) ...[
                    const SizedBox(height: 10),
                    _outlineBtn(
                      label: 'Naviguer vers le commerce',
                      icon: Icons.navigation_rounded,
                      onTap: () => _openMap(promo.lat!, promo.lng!),
                    ),
                  ],

                  const SizedBox(height: 10),
                  _outlineBtn(
                    label: 'Scanner un QR code',
                    icon: Icons.qr_code_scanner_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const QrScannerScreen()),
                    ),
                  ),

                  if (promo.businessName != null) ...[
                    const SizedBox(height: 10),
                    _outlineBtn(
                      label: 'Contacter le commerce',
                      icon: Icons.chat_bubble_outline_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            businessId:   promo.businessId,
                            businessName: promo.businessName!,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ─── Rating ──────────────────────────────────────────────
                  const SizedBox(height: 24),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Évaluer ce commerce',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StarRatingWidget(
                          rating: _rating,
                          size: 32,
                          onRate: _rate,
                        ),
                      ],
                    ),
                  ),

                  // ─── Comments & Reviews ───────────────────────────────────
                  const SizedBox(height: 24),
                  CommentSection(
                    promoId:           promo.id,
                    businessId:        promo.businessId,
                    promoTitle:        promo.title,
                    scrollToCommentId: widget.scrollToCommentId,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RESERVATION MODAL ────────────────────────────────────────────────────

  void _showReservationModal(PromoModel promo) {
    if (!promo.isEffectivelyActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette offre n\'est plus disponible.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final nameCtrl    = TextEditingController();
    final phoneCtrl   = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey     = GlobalKey<FormState>();
    bool loading      = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final mq           = MediaQuery.of(ctx);
          final keyboardH    = mq.viewInsets.bottom;
          final maxSheetH    = mq.size.height * 0.90 - keyboardH;
          return Padding(
          padding: EdgeInsets.only(bottom: keyboardH),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxSheetH.clamp(200.0, double.infinity)),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.bookmark_add_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Réserver cette offre',
                                style: TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                            Text(promo.title,
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text('Valable 24h après confirmation',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const RequiredLabel('Votre nom'),
                  _modalField(nameCtrl, 'Votre nom',
                      Icons.person_outline_rounded,
                      validator: Validators.fullName),
                  const SizedBox(height: 12),
                  const RequiredLabel('Téléphone'),
                  _modalField(
                      phoneCtrl, 'Téléphone', Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      validator: Validators.phone),
                  const SizedBox(height: 12),
                  _modalField(messageCtrl, 'Message (optionnel)',
                      Icons.message_outlined,
                      maxLines: 2,
                      validator: Validators.optionalMessage),
                  const SizedBox(height: 24),

                  GradientButton(
                    label: loading
                        ? 'Réservation en cours…'
                        : 'Confirmer la réservation',
                    icon: Icons.bookmark_added_rounded,
                    loading: loading,
                    onTap: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setLocal(() => loading = true);

                            final uid = AuthService.currentUid;
                            if (uid == null) return;

                            try {
                              final reservation =
                                  await ReservationService.create(
                                userId:     uid,
                                promoId:    promo.id,
                                promoTitle: promo.title,
                                businessId: promo.businessId,
                                userName:   nameCtrl.text.trim(),
                                phone:      phoneCtrl.text.trim(),
                                message:    messageCtrl.text.trim(),
                              );
                              await NotificationManager.reservationCreated(
                                reservationId: reservation.id,
                                promoTitle:    promo.title,
                                expiresAt:     reservation.expiresAt,
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() => _hasActiveReservation = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.bookmark_added_rounded,
                                            color: Colors.white),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Réservation confirmée ! Valable 24h.',
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              AppErrorHandler.log('Reservation.create', e);
                              if (ctx.mounted) {
                                setLocal(() => loading = false);
                                AppErrorHandler.showError(ctx, e,
                                    logContext: 'Reservation.create');
                              }
                            }
                          },
                  ),
                ],
                ), // Column
              ), // SingleChildScrollView
            ), // Form
          ), // Container
        ); // return Padding
        }, // StatefulBuilder block
      ), // StatefulBuilder
    ).whenComplete(() {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      messageCtrl.dispose();
    });
  }

  Widget _modalField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: validator,
        style:
            const TextStyle(color: AppColors.textDark, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: AppColors.textLight, size: 18),
          hintText: hint,
          hintStyle: const TextStyle(
              color: AppColors.textLight, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  Widget _sectionCard({required Widget child, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _outlineBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _bgCircle(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha),
        ),
      );
}

// ─── QR CODE CARD ─────────────────────────────────────────────────────────────

class _QrCard extends StatefulWidget {
  final String qrValue;
  final String promoCode;

  const _QrCard({required this.qrValue, required this.promoCode});

  @override
  State<_QrCard> createState() => _QrCardState();
}

class _QrCardState extends State<_QrCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header row (always visible)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    // QR icon with gradient bg
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Code de la promotion',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.promoCode,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable QR image
            if (_expanded) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // QR code widget
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: QrImageView(
                        data: widget.qrValue,
                        version: QrVersions.auto,
                        size: 200,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.purple,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Présentez ce QR code au commerçant\npour valider votre réduction',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── STICKY RESERVATION BAR ───────────────────────────────────────────────────

class _StickyReservationBar extends StatelessWidget {
  final PromoModel promo;
  final bool       hasActiveReservation;
  final VoidCallback onReserve;

  const _StickyReservationBar({
    required this.promo,
    required this.hasActiveReservation,
    required this.onReserve,
  });

  String get _label {
    if (hasActiveReservation) { return 'Déjà réservée ✓'; }
    if (promo.isExpired || promo.status == PromoStatus.expired) {
      return 'Offre expirée';
    }
    if (promo.isLimitReached) { return 'Offre complète'; }
    if (!promo.isEffectivelyActive) { return 'Non disponible'; }
    return 'Réserver cette offre';
  }

  IconData get _icon {
    if (hasActiveReservation) { return Icons.bookmark_added_rounded; }
    if (!promo.isEffectivelyActive || promo.isLimitReached) {
      return Icons.block_rounded;
    }
    return Icons.bookmark_add_rounded;
  }

  bool get _canReserve =>
      !hasActiveReservation && promo.isEffectivelyActive && !promo.isLimitReached;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: _canReserve
              ? GestureDetector(
                  onTap: onReserve,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.primaryShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_icon,
                          color: hasActiveReservation
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _label,
                        style: TextStyle(
                          color: hasActiveReservation
                              ? AppColors.success
                              : AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
