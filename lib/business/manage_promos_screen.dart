import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/promo_model.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import '../utils/promo_expiration_checker.dart';
import '../widgets/qr_card_widget.dart';
import '../widgets/required_label.dart';
import 'business_navbar.dart';
import '../widgets/notification_overlay.dart';

class ManagePromosScreen extends StatelessWidget {
  final String businessId;

  const ManagePromosScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return NotificationWrapper(
      userId: businessId,
      child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mes promotions',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(
                userId: businessId, iconColor: AppColors.textDark),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: StreamBuilder<List<PromoModel>>(
        stream: PromoService.watchByBusiness(businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final promos = snapshot.data ?? [];

          if (promos.isEmpty) {
            return const AppEmptyState(
              icon: Icons.local_offer_rounded,
              message: 'Aucune promotion\nCréez votre première offre !',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: promos.length,
            itemBuilder: (context, i) => _PromoCard(promo: promos[i]),
          );
        },
      ),
      bottomNavigationBar: BusinessNavbar(
        currentIndex: 2,
        businessId: businessId,
      ),
    )); // NotificationWrapper
  }
}

// ─── PROMO CARD ───────────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final PromoModel promo;

  const _PromoCard({required this.promo});

  static ({Color color, String label}) _effectiveStatus(PromoModel p) {
    if (p.status == PromoStatus.expired || p.isExpired) {
      return (color: AppColors.error, label: 'Expirée');
    }
    if (p.status == PromoStatus.rejected) {
      return (color: AppColors.error, label: 'Refusée');
    }
    if (p.status == PromoStatus.ended) {
      return (color: AppColors.textLight, label: 'Terminée');
    }
    if (p.status == PromoStatus.pending) {
      return (color: AppColors.warning, label: 'En attente');
    }
    // status == approved below
    if (p.isLimitReached) {
      return (color: const Color(0xFFF97316), label: 'Complète');
    }
    if (!p.isActive) return (color: AppColors.textLight, label: 'Désactivée');
    return (color: AppColors.success, label: 'Active');
  }

  @override
  Widget build(BuildContext context) {
    final status = _effectiveStatus(promo);
    final countdown = PromoExpirationChecker.expirationCountdown(promo);
    final spotsLabel = PromoExpirationChecker.remainingSpotsLabel(promo);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + discount
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    promo.title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '-${promo.discount}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 12, color: AppColors.textLight),
                const SizedBox(width: 3),
                Text('${promo.views}',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
                const SizedBox(width: 10),
                const Icon(Icons.confirmation_number_outlined,
                    size: 12, color: AppColors.textLight),
                const SizedBox(width: 3),
                Text('${promo.used} utilisés',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11)),
                if (promo.maxReservations != null) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.people_outline,
                      size: 12, color: AppColors.textLight),
                  const SizedBox(width: 3),
                  Text(
                    '${promo.currentReservations}/${promo.maxReservations}',
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),

          // Countdown / spots badges
          if (countdown != null || spotsLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (countdown != null)
                    _badge('⏳ $countdown', AppColors.warning),
                  if (spotsLabel != null)
                    _badge(
                      spotsLabel,
                      PromoExpirationChecker.isAlmostFull(promo)
                          ? const Color(0xFFF97316)
                          : AppColors.primary,
                    ),
                ],
              ),
            ),

          // Status + action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusBadge(status.label, status.color),
                Row(
                  children: [
                    if (promo.status != PromoStatus.ended &&
                        promo.status != PromoStatus.rejected) ...[
                      _actionBtn(
                        icon: Icons.edit_outlined,
                        color: AppColors.primary,
                        onTap: () => _openEditSheet(context),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (promo.qrCodeValue != null) ...[
                      _actionBtn(
                        icon: Icons.qr_code_2_rounded,
                        color: AppColors.purple,
                        onTap: () => _showQrSheet(context),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (promo.status == PromoStatus.approved ||
                        promo.status == PromoStatus.pending) ...[
                      _actionBtn(
                        icon: Icons.stop_circle_outlined,
                        color: AppColors.textMuted,
                        onTap: () => PromoService.end(promo.id),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _actionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      onTap: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      );

  Widget _statusBadge(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      );

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPromoSheet(promo: promo),
    );
  }

  void _showQrSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                QrCardWidget(promo: promo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${promo.title}" définitivement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PromoService.delete(promo.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Promo supprimée'),
            backgroundColor: AppColors.textDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

// ─── EDIT BOTTOM SHEET ────────────────────────────────────────────────────────

class _EditPromoSheet extends StatefulWidget {
  final PromoModel promo;

  const _EditPromoSheet({required this.promo});

  @override
  State<_EditPromoSheet> createState() => _EditPromoSheetState();
}

class _EditPromoSheetState extends State<_EditPromoSheet> {
  final _formKey = GlobalKey<FormState>();

  late final _titleCtrl =
      TextEditingController(text: widget.promo.title);
  late final _descCtrl =
      TextEditingController(text: widget.promo.description);
  late final _discountCtrl =
      TextEditingController(text: widget.promo.discount.toString());
  late final _codeCtrl =
      TextEditingController(text: widget.promo.code);
  late final _conditionsCtrl =
      TextEditingController(text: widget.promo.conditions);
  late final _maxResCtrl = TextEditingController(
      text: widget.promo.maxReservations?.toString() ?? '');

  late DateTime? _expDate = widget.promo.expirationDate;
  late bool _isFlashDeal = widget.promo.isFlashDeal;
  late DateTime? _flashEndTime = widget.promo.flashEndTime;
  late bool _limitReservations = widget.promo.maxReservations != null;

  bool _loading = false;
  int _focused = -1;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _codeCtrl.dispose();
    _conditionsCtrl.dispose();
    _maxResCtrl.dispose();
    super.dispose();
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expDate == null) {
      _err("Sélectionnez une date d'expiration.");
      return;
    }
    final discount = int.tryParse(_discountCtrl.text.trim());
    if (discount == null || discount <= 0 || discount > 100) {
      _err('Réduction invalide (1-100%).');
      return;
    }
    if (_isFlashDeal && _flashEndTime == null) {
      _err('Sélectionnez la date de fin du flash deal.');
      return;
    }
    int? maxRes;
    if (_limitReservations) {
      maxRes = int.tryParse(_maxResCtrl.text.trim());
      if (maxRes == null || maxRes < 1) {
        _err('Le nombre maximum de réservations doit être >= 1.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      await PromoService.updatePromo(
        promoId:        widget.promo.id,
        title:          _titleCtrl.text.trim(),
        description:    _descCtrl.text.trim(),
        discount:       discount,
        code:           _codeCtrl.text.trim().toUpperCase(),
        conditions:     _conditionsCtrl.text.trim(),
        expirationDate: _expDate!,
        isFlashDeal:    _isFlashDeal,
        flashEndTime:   _flashEndTime,
        maxReservations: maxRes,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Promotion mise à jour !',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      AppErrorHandler.log('ManagePromos.update', e);
      if (mounted) _err(AppErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin:
                    const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.38),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modifier la promotion',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Mettez à jour les informations',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Form
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const RequiredLabel('Titre'),
                      _field(
                        0, _titleCtrl,
                        'Titre de la promotion',
                        Icons.title_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      const RequiredLabel('Description'),
                      _field(
                        1, _descCtrl,
                        'Décrivez votre offre...',
                        Icons.description_outlined,
                        maxLines: 3,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Requis'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const RequiredLabel('Réduction (%)'),
                                _field(
                                  2, _discountCtrl,
                                  '40',
                                  Icons.percent_rounded,
                                  keyboard:
                                      TextInputType.number,
                                  validator: (v) {
                                    if (v == null ||
                                        v.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    final n = int.tryParse(
                                        v.trim());
                                    return (n == null ||
                                            n <= 0 ||
                                            n > 100)
                                        ? '1–100%'
                                        : null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const RequiredLabel('Code promo'),
                                _field(
                                  3, _codeCtrl,
                                  'PIZZA40',
                                  Icons.local_offer_rounded,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      const RequiredLabel("Date d'expiration"),
                      _datePicker(),
                      const SizedBox(height: 14),

                      _label("Conditions d'utilisation"),
                      _field(
                        4, _conditionsCtrl,
                        "Conditions d'utilisation...",
                        Icons.info_outline_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 14),

                      _label('Flash Deal'),
                      _flashSection(),
                      const SizedBox(height: 14),

                      _label('Limite de réservations'),
                      _limitSection(),
                      const SizedBox(height: 24),

                      GradientButton(
                        label: _loading
                            ? 'Enregistrement...'
                            : 'Enregistrer les modifications',
                        icon: Icons.save_rounded,
                        onTap: _loading ? null : _save,
                        loading: _loading,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Form helpers ──────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _field(
    int idx,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    final focused = _focused == idx;
    return Focus(
      onFocusChange: (v) =>
          setState(() => _focused = v ? idx : -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? AppColors.primary : AppColors.border,
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color:
                        AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          validator: validator,
          style: const TextStyle(
              color: AppColors.textDark, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: focused
                  ? AppColors.primary
                  : AppColors.textLight,
              size: 18,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textLight, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            errorStyle:
                const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _expDate ??
              DateTime.now().add(const Duration(days: 7)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null && mounted) {
          setState(() => _expDate = date);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expDate != null
                ? AppColors.primary
                : AppColors.border,
            width: _expDate != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: _expDate != null
                  ? AppColors.primary
                  : AppColors.textLight,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              _expDate == null
                  ? 'Sélectionner une date'
                  : DateFormat('dd/MM/yyyy').format(_expDate!),
              style: TextStyle(
                color: _expDate == null
                    ? AppColors.textLight
                    : AppColors.textDark,
                fontSize: 14,
                fontWeight: _expDate != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (_expDate != null)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _flashSection() {
    const flashColor = Color(0xFFF97316);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isFlashDeal
                ? const Color(0xFFFFF7ED)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  _isFlashDeal ? flashColor : AppColors.border,
              width: _isFlashDeal ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _isFlashDeal
                      ? const Color(0xFFFFF7ED)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: flashColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Offre Flash',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Switch(
                value: _isFlashDeal,
                activeTrackColor: flashColor,
                onChanged: (v) => setState(() {
                  _isFlashDeal = v;
                  if (!v) _flashEndTime = null;
                }),
              ),
            ],
          ),
        ),
        if (_isFlashDeal) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickFlashEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _flashEndTime != null
                      ? flashColor
                      : AppColors.border,
                  width: _flashEndTime != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: _flashEndTime != null
                        ? flashColor
                        : AppColors.textLight,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _flashEndTime == null
                        ? 'Fin du flash deal (date & heure)'
                        : DateFormat('dd/MM/yyyy HH:mm')
                            .format(_flashEndTime!),
                    style: TextStyle(
                      color: _flashEndTime == null
                          ? AppColors.textLight
                          : AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_flashEndTime != null)
                    const Icon(Icons.check_circle_rounded,
                        color: flashColor, size: 18),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _limitSection() {
    const limitColor = Color(0xFF6366F1);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _limitReservations
                ? const Color(0xFFEEF2FF)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _limitReservations
                  ? limitColor
                  : AppColors.border,
              width: _limitReservations ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _limitReservations
                      ? const Color(0xFFEEF2FF)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.people_alt_rounded,
                    color: limitColor, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Limiter les réservations',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Switch(
                value: _limitReservations,
                activeTrackColor: limitColor,
                onChanged: (v) => setState(() {
                  _limitReservations = v;
                  if (!v) _maxResCtrl.clear();
                }),
              ),
            ],
          ),
        ),
        if (_limitReservations) ...[
          const SizedBox(height: 8),
          _field(
            5, _maxResCtrl,
            'Ex: 50',
            Icons.confirmation_number_rounded,
            keyboard: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Requis';
              final n = int.tryParse(v.trim());
              return (n == null || n < 1) ? 'Doit être >= 1' : null;
            },
          ),
        ],
      ],
    );
  }

  Future<void> _pickFlashEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _flashEndTime ??
          DateTime.now().add(const Duration(hours: 24)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF97316),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() => _flashEndTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute,
        ));
  }
}
