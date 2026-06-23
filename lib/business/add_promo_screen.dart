import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/promo_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_handler.dart';
import '../utils/validators.dart';
import '../widgets/required_label.dart';

class AddPromoScreen extends StatefulWidget {
  const AddPromoScreen({super.key});

  @override
  State<AddPromoScreen> createState() => _AddPromoScreenState();
}

class _AddPromoScreenState extends State<AddPromoScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _oldPriceCtrl   = TextEditingController();
  final _newPriceCtrl   = TextEditingController();
  final _codeCtrl       = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _maxResCtrl     = TextEditingController();

  DateTime?   _startDate;
  DateTime?   _expDate;
  bool        _loading          = false;
  bool        _uploading        = false;
  int         _uploadDone       = 0;
  int         _uploadTotal      = 0;
  List<XFile> _images           = [];
  int         _focused          = -1;
  bool        _isFlashDeal      = false;
  DateTime?   _flashEndTime;
  bool        _limitReservations = false;
  int?        _maxReservations;

  final _picker = ImagePicker();

  // ─── LIVE PRICE CALCULATION ───────────────────────────────────────────────
  // Updated on every keystroke in the price fields.

  double? _oldPrice;
  double? _newPrice;

  double? get _discountPct {
    if (_oldPrice == null || _newPrice == null || _oldPrice! <= 0) return null;
    if (_newPrice! >= _oldPrice!) return null;
    return ((_oldPrice! - _newPrice!) / _oldPrice!) * 100;
  }

  double? get _savedAmt {
    if (_oldPrice == null || _newPrice == null) return null;
    if (_newPrice! >= _oldPrice!) return null;
    return _oldPrice! - _newPrice!;
  }

  void _onPriceChanged() {
    final old = double.tryParse(
        _oldPriceCtrl.text.trim().replaceAll(',', '.'));
    final nw  = double.tryParse(
        _newPriceCtrl.text.trim().replaceAll(',', '.'));
    setState(() {
      _oldPrice = old;
      _newPrice = nw;
    });
  }

  @override
  void initState() {
    super.initState();
    _oldPriceCtrl.addListener(_onPriceChanged);
    _newPriceCtrl.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _oldPriceCtrl.dispose();
    _newPriceCtrl.dispose();
    _codeCtrl.dispose();
    _conditionsCtrl.dispose();
    _maxResCtrl.dispose();
    super.dispose();
  }

  // ─── IMAGE PICKER ─────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty && mounted) {
        setState(() => _images = (_images + picked).take(5).toList());
      }
    } catch (_) {}
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() => _images.removeAt(index));
  }

  // ─── DATE PICKERS ─────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context:     context,
      initialDate: DateTime.now(),
      firstDate:   DateTime.now().subtract(const Duration(days: 1)),
      lastDate:    DateTime(2030),
      builder: _datepickerTheme,
    );
    if (date != null && mounted) setState(() => _startDate = date);
  }

  Future<void> _pickExpDate() async {
    final date = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime(2030),
      builder: _datepickerTheme,
    );
    if (date != null && mounted) setState(() => _expDate = date);
  }

  Future<void> _pickFlashEndTime() async {
    final date = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().add(const Duration(hours: 24)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 30)),
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   Color(0xFFF97316),
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
          date.year, date.month, date.day, time.hour, time.minute));
  }

  Widget Function(BuildContext, Widget?) get _datepickerTheme =>
      (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary:   AppColors.primary,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          );

  // ─── SUBMIT ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Price validation
    final oldPrice = double.tryParse(
        _oldPriceCtrl.text.trim().replaceAll(',', '.'));
    final newPrice = double.tryParse(
        _newPriceCtrl.text.trim().replaceAll(',', '.'));

    if (oldPrice == null || oldPrice <= 0) {
      _err('Prix initial invalide.');
      return;
    }
    if (newPrice == null || newPrice <= 0) {
      _err('Prix promotionnel invalide.');
      return;
    }
    if (newPrice >= oldPrice) {
      _err('Le prix promotionnel doit être inférieur au prix initial.');
      return;
    }

    if (_expDate == null) {
      _err("Sélectionnez une date de fin.");
      return;
    }
    if (_startDate != null && _startDate!.isAfter(_expDate!)) {
      _err("La date de début doit être avant la date de fin.");
      return;
    }
    if (_isFlashDeal && _flashEndTime == null) {
      _err('Sélectionnez la date de fin du flash deal.');
      return;
    }
    if (_isFlashDeal && _flashEndTime != null &&
        _flashEndTime!.isBefore(DateTime.now())) {
      _err('La date de fin du flash deal doit être dans le futur.');
      return;
    }
    if (_isFlashDeal && _flashEndTime != null && _expDate != null &&
        _flashEndTime!.isAfter(
            DateTime(_expDate!.year, _expDate!.month, _expDate!.day, 23, 59, 59))) {
      _err("La fin du flash deal doit être avant la date d'expiration.");
      return;
    }
    if (_limitReservations) {
      final maxRes = int.tryParse(_maxResCtrl.text.trim());
      if (maxRes == null || maxRes < 1) {
        _err('Le nombre maximum de réservations doit être ≥ 1.');
        return;
      }
      _maxReservations = maxRes;
    } else {
      _maxReservations = null;
    }

    setState(() => _loading = true);

    try {
      final uid = AuthService.currentUid;
      if (uid == null) throw Exception('Non connecté.');

      if (_images.isNotEmpty && mounted) {
        setState(() {
          _uploading   = true;
          _uploadDone  = 0;
          _uploadTotal = _images.length;
        });
      }

      final discPct = ((oldPrice - newPrice) / oldPrice) * 100;
      final saved   = oldPrice - newPrice;

      await PromoService.addPromo(
        businessId:        uid,
        title:             _titleCtrl.text.trim(),
        description:       _descCtrl.text.trim(),
        oldPrice:          oldPrice,
        newPrice:          newPrice,
        discountPercentage: double.parse(discPct.toStringAsFixed(2)),
        savedAmount:       double.parse(saved.toStringAsFixed(2)),
        discount:          discPct.round(),
        code:              _codeCtrl.text.trim().toUpperCase(),
        conditions:        _conditionsCtrl.text.trim(),
        startDate:         _startDate,
        expirationDate:    DateTime(
          _expDate!.year, _expDate!.month, _expDate!.day, 23, 59, 59),
        imageFiles:        _images,
        isFlashDeal:       _isFlashDeal,
        flashEndTime:      _flashEndTime,
        maxReservations:   _maxReservations,
        onImageProgress: (done, total) {
          if (mounted) setState(() { _uploadDone = done; _uploadTotal = total; });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.rocket_launch_rounded, color: Colors.white),
          SizedBox(width: 10),
          Expanded(child: Text(
            'Promotion publiée ! Visible dans le fil d\'actualité.',
            style: TextStyle(fontWeight: FontWeight.w600),
          )),
        ]),
        backgroundColor: AppColors.success,
        behavior:  SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ));
      Navigator.pop(context);
    } catch (e) {
      AppErrorHandler.log('AddPromo', e);
      if (mounted) _err(AppErrorHandler.getMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading     = false;
          _uploading   = false;
          _uploadDone  = 0;
          _uploadTotal = 0;
        });
      }
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    AppErrorHandler.showMessage(context, msg, isError: true);
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned:         true,
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
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient),
                child: Stack(children: [
                  Positioned(
                    top: -40, right: -40,
                    child: _bgCircle(180, Colors.white, 0.10)),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:  MainAxisAlignment.end,
                        children: [
                          const Text('Nouvelle promotion',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Remplissez les informations de votre offre',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Form body ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Card 1: Informations générales ────────────────
                    _formCard(
                      icon:  Icons.info_outline_rounded,
                      title: 'Informations générales',
                      color: AppColors.primary,
                      children: [
                        const RequiredLabel('Titre de la promotion'),
                        _field(
                          index: 0, ctrl: _titleCtrl,
                          hint: 'Ex: Burger Gourmet -25%',
                          icon: Icons.title_rounded,
                          validator: Validators.promoTitle,
                        ),
                        const SizedBox(height: 16),
                        const RequiredLabel('Description'),
                        _field(
                          index: 1, ctrl: _descCtrl,
                          hint: 'Décrivez votre offre en détail (min. 20 caractères)…',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                          validator: Validators.promoDescription,
                        ),
                      ],
                    ),

                    // ── Card 2: Photos ────────────────────────────────
                    _formCard(
                      icon:  Icons.photo_camera_rounded,
                      title: 'Photos de la promotion',
                      color: const Color(0xFF0EA5E9),
                      children: [
                        _imageSection(),
                      ],
                    ),

                    // ── Card 3: Tarification ──────────────────────────
                    _formCard(
                      icon:  Icons.sell_rounded,
                      title: 'Tarification',
                      color: AppColors.primary,
                      children: [
                        Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const RequiredLabel('Prix initial (DT)'),
                              _priceField(
                                index: 2, ctrl: _oldPriceCtrl,
                                hint: '200',
                                icon: Icons.price_change_outlined,
                                color: AppColors.textMuted,
                              ),
                            ],
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const RequiredLabel('Prix promo (DT)'),
                              _priceField(
                                index: 3, ctrl: _newPriceCtrl,
                                hint: '150',
                                icon: Icons.local_offer_rounded,
                                color: AppColors.primary,
                              ),
                            ],
                          )),
                        ]),
                        if (_discountPct != null) ...[
                          const SizedBox(height: 14),
                          _PricePreviewCard(
                            oldPrice:    _oldPrice!,
                            newPrice:    _newPrice!,
                            discountPct: _discountPct!,
                            savedAmt:    _savedAmt!,
                          ),
                        ] else if (_oldPrice != null && _newPrice != null &&
                                   _newPrice! >= _oldPrice!) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: const Row(children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: AppColors.error, size: 16),
                              SizedBox(width: 8),
                              Expanded(child: Text(
                                'Le prix promotionnel doit être inférieur au prix initial.',
                                style: TextStyle(
                                    color: AppColors.error, fontSize: 12),
                              )),
                            ]),
                          ),
                        ],
                      ],
                    ),

                    // ── Card 4: Durée & Détails ───────────────────────
                    _formCard(
                      icon:  Icons.date_range_rounded,
                      title: 'Durée & Détails',
                      color: const Color(0xFF6366F1),
                      children: [
                        Row(children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Date de début'),
                              _dateTile(
                                icon:   Icons.play_circle_outline_rounded,
                                label:  _startDate == null
                                    ? 'Optionnel'
                                    : DateFormat('dd/MM/yyyy').format(_startDate!),
                                active: _startDate != null,
                                onTap:  _pickStartDate,
                                color:  const Color(0xFF6366F1),
                              ),
                            ],
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const RequiredLabel('Date de fin'),
                              _dateTile(
                                icon:   Icons.event_rounded,
                                label:  _expDate == null
                                    ? 'Sélectionner'
                                    : DateFormat('dd/MM/yyyy').format(_expDate!),
                                active: _expDate != null,
                                onTap:  _pickExpDate,
                                color:  AppColors.primary,
                              ),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 16),
                        _sectionLabel('Code promo (optionnel)'),
                        _field(
                          index: 4, ctrl: _codeCtrl,
                          hint: 'PROMO25',
                          icon: Icons.confirmation_number_outlined,
                          validator: Validators.promoCode,
                        ),
                        const SizedBox(height: 16),
                        _sectionLabel("Conditions d'utilisation"),
                        _field(
                          index: 5, ctrl: _conditionsCtrl,
                          hint: "Conditions d'utilisation…",
                          icon: Icons.info_outline_rounded,
                          maxLines: 3,
                          validator: Validators.promoConditions,
                        ),
                      ],
                    ),

                    // ── Card 5: Options avancées ──────────────────────
                    _formCard(
                      icon:  Icons.tune_rounded,
                      title: 'Options avancées',
                      color: const Color(0xFFF97316),
                      children: [
                        _sectionLabel('Offre Flash'),
                        const SizedBox(height: 8),
                        _flashDealSection(),
                        const SizedBox(height: 16),
                        _sectionLabel('Limite de réservations'),
                        const SizedBox(height: 8),
                        _reservationLimitSection(),
                      ],
                    ),

                    // ── Submit ────────────────────────────────────────
                    GradientButton(
                      label: _uploading && _uploadTotal > 0
                          ? 'Upload $_uploadDone / $_uploadTotal...'
                          : _uploading
                              ? 'Upload en cours...'
                              : _loading ? 'Publication...' : 'Publier la promotion',
                      icon:    Icons.rocket_launch_rounded,
                      onTap:   _loading ? null : _submit,
                      loading: _loading,
                    ),
                    if (_uploading && _uploadTotal > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadDone / _uploadTotal,
                          backgroundColor: AppColors.border,
                          color: AppColors.primary,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Image $_uploadDone sur $_uploadTotal envoyée…',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── IMAGE SECTION ────────────────────────────────────────────────────────

  Widget _imageSection() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 100, height: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(height: 4),
                  Text('${_images.length}/5',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          ..._images.asMap().entries.map((entry) {
            final i    = entry.key;
            final file = entry.value;
            return Stack(children: [
              Container(
                width: 100, height: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: FutureBuilder<Uint8List>(
                    future: file.readAsBytes(),
                    builder: (_, snap) => snap.hasData
                        ? Image.memory(snap.data!, fit: BoxFit.cover)
                        : const Center(child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)),
                  ),
                ),
              ),
              Positioned(
                top: 4, right: 14,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                        color: AppColors.error, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ]);
          }),
        ],
      ),
    );
  }

  // ─── FIELD HELPERS ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
        color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _field({
    required int index,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    final focused = _focused == index;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v ? index : -1),
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
              ? [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboard,
          validator: validator,
          style: const TextStyle(color: AppColors.textDark, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                color: focused ? AppColors.primary : AppColors.textLight,
                size: 18),
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textLight, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            errorStyle: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _priceField({
    required int index,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required Color color,
  }) {
    final focused = _focused == index;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v ? index : -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? color : AppColors.border,
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: TextFormField(
          controller:    ctrl,
          keyboardType:  const TextInputType.numberWithOptions(decimal: true),
          validator:     Validators.price,
          style: const TextStyle(
              color: AppColors.textDark, fontSize: 16,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                color: focused ? color : AppColors.textLight, size: 18),
            suffixText:      'DT',
            suffixStyle: TextStyle(
                color: focused ? color : AppColors.textLight,
                fontWeight: FontWeight.w600, fontSize: 13),
            hintText:  hint,
            hintStyle: const TextStyle(
                color: AppColors.textLight, fontSize: 15),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            errorStyle: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required IconData icon,
    required String   label,
    required bool     active,
    required VoidCallback onTap,
    required Color    color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : AppColors.border,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: active ? color : AppColors.textLight, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(label,
              style: TextStyle(
                color: active ? AppColors.textDark : AppColors.textLight,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis)),
          if (active)
            Icon(Icons.check_circle_rounded, color: color, size: 16),
        ]),
      ),
    );
  }

  Widget _flashDealSection() {
    const flashColor = Color(0xFFF97316);
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isFlashDeal ? const Color(0xFFFFF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isFlashDeal ? flashColor : AppColors.border,
            width: _isFlashDeal ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _isFlashDeal
                  ? const Color(0xFFFFF7ED) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: flashColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offre Flash', style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              Text('Compte à rebours visible par les clients',
                  style: TextStyle(
                      color: AppColors.textLight, fontSize: 12)),
            ],
          )),
          Switch(
            value: _isFlashDeal,
            activeTrackColor: flashColor,
            onChanged: (v) => setState(() {
              _isFlashDeal = v;
              if (!v) _flashEndTime = null;
            }),
          ),
        ]),
      ),
      if (_isFlashDeal) ...[
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickFlashEndTime,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _flashEndTime != null ? flashColor : AppColors.border,
                width: _flashEndTime != null ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.schedule_rounded,
                  color: _flashEndTime != null
                      ? flashColor : AppColors.textLight, size: 18),
              const SizedBox(width: 12),
              Text(
                _flashEndTime == null
                    ? 'Fin du flash deal (date & heure)'
                    : DateFormat('dd/MM/yyyy HH:mm').format(_flashEndTime!),
                style: TextStyle(
                  color: _flashEndTime == null
                      ? AppColors.textLight : AppColors.textDark,
                  fontSize: 14,
                  fontWeight: _flashEndTime != null
                      ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (_flashEndTime != null)
                const Icon(Icons.check_circle_rounded,
                    color: flashColor, size: 18),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _reservationLimitSection() {
    const limitColor = Color(0xFF6366F1);
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _limitReservations
              ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _limitReservations ? limitColor : AppColors.border,
            width: _limitReservations ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _limitReservations
                  ? const Color(0xFFEEF2FF) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_alt_rounded,
                color: limitColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Limiter les réservations', style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600, fontSize: 14)),
              Text('Définir un nombre maximum de réservations',
                  style: TextStyle(
                      color: AppColors.textLight, fontSize: 12)),
            ],
          )),
          Switch(
            value: _limitReservations,
            activeTrackColor: limitColor,
            onChanged: (v) => setState(() {
              _limitReservations = v;
              if (!v) { _maxResCtrl.clear(); _maxReservations = null; }
            }),
          ),
        ]),
      ),
      if (_limitReservations) ...[
        const SizedBox(height: 10),
        _field(
          index: 6, ctrl: _maxResCtrl,
          hint: 'Ex: 50',
          icon: Icons.confirmation_number_rounded,
          keyboard: TextInputType.number,
          validator: Validators.maxReservations,
        ),
      ],
    ]);
  }

  Widget _formCard({
    required IconData     icon,
    required String       title,
    required Color        color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bgCircle(double size, Color color, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha)),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Live price calculation preview card
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PricePreviewCard extends StatelessWidget {
  final double oldPrice;
  final double newPrice;
  final double discountPct;
  final double savedAmt;

  const _PricePreviewCard({
    required this.oldPrice,
    required this.newPrice,
    required this.discountPct,
    required this.savedAmt,
  });

  // Badge colour intensifies with discount size
  Color get _badgeColor {
    if (discountPct >= 60) return const Color(0xFFDC2626); // red
    if (discountPct >= 40) return const Color(0xFFEA580C); // orange-red
    if (discountPct >= 20) return const Color(0xFFF97316); // orange
    return AppColors.success;                               // green
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.##', 'fr_FR');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _badgeColor.withValues(alpha: 0.08),
            AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _badgeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calculate_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('Aperçu du calcul automatique',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            // Discount badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _badgeColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _badgeColor.withValues(alpha: 0.4),
                    blurRadius: 8, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '-${discountPct.toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),

          // Prices row
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prix initial', style: TextStyle(
                    color: AppColors.textLight, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(oldPrice)} DT',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.error,
                    decorationThickness: 2,
                  ),
                ),
              ],
            )),
            Container(width: 1, height: 32, color: AppColors.border),
            Expanded(child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prix promo', style: TextStyle(
                      color: AppColors.textLight, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '${fmt.format(newPrice)} DT',
                    style: TextStyle(
                      color: _badgeColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )),
          ]),

          const SizedBox(height: 12),

          // Savings chip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.savings_rounded,
                  color: AppColors.success, size: 15),
              const SizedBox(width: 6),
              Text(
                'Économie : ${fmt.format(savedAmt)} DT',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 13, fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
