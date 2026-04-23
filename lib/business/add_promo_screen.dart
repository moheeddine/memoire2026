import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/promo_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class AddPromoScreen extends StatefulWidget {
  const AddPromoScreen({super.key});

  @override
  State<AddPromoScreen> createState() => _AddPromoScreenState();
}

class _AddPromoScreenState extends State<AddPromoScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _titleCtrl         = TextEditingController();
  final _descCtrl          = TextEditingController();
  final _discountCtrl      = TextEditingController();
  final _codeCtrl          = TextEditingController();
  final _conditionsCtrl    = TextEditingController();

  DateTime?     _expDate;
  bool          _loading        = false;
  bool          _uploading      = false;
  List<XFile>   _images         = [];
  int           _focused        = -1;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    _codeCtrl.dispose();
    _conditionsCtrl.dispose();
    super.dispose();
  }

  // ─── Image picker ─────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty && mounted) {
        setState(() {
          _images = (_images + picked).take(5).toList();
        });
      }
    } catch (_) {}
  }

  void _removeImage(int index) =>
      setState(() => _images.removeAt(index));

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
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

    setState(() => _loading = true);

    try {
      final uid = AuthService.currentUid;
      if (uid == null) throw Exception('Non connecté.');

      // Show upload indicator if images are selected
      if (_images.isNotEmpty && mounted) {
        setState(() => _uploading = true);
      }

      await PromoService.addPromo(
        businessId:     uid,
        title:          _titleCtrl.text.trim(),
        description:    _descCtrl.text.trim(),
        discount:       discount,
        code:           _codeCtrl.text.trim(),
        conditions:     _conditionsCtrl.text.trim(),
        expirationDate: _expDate!,
        imageFiles:     _images,
      );

      await NotificationService.notifyNewPromo(_titleCtrl.text.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                'Promotion soumise ! En attente de validation.',
                style: TextStyle(fontWeight: FontWeight.w600),
              )),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _err(e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('[firebase_storage/', '[Storage: ')
            .split(']').last.trim());
      }
    } finally {
      if (mounted) setState(() { _loading = false; _uploading = false; });
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
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
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient),
                child: Stack(
                  children: [
                    Positioned(
                        top: -40,
                        right: -40,
                        child: _bgCircle(180, Colors.white, 0.1)),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            20, 50, 20, 16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Nouvelle promotion',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Remplissez les informations de votre offre',
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Form ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image upload section
                    _sectionLabel('Photos de la promotion'),
                    _imageSection(),

                    const SizedBox(height: 20),

                    _sectionLabel('Titre de la promotion'),
                    _field(
                      index: 0,
                      ctrl: _titleCtrl,
                      hint: 'Ex: Pizza Large -40%',
                      icon: Icons.title_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Requis'
                              : null,
                    ),

                    const SizedBox(height: 16),

                    _sectionLabel('Description'),
                    _field(
                      index: 1,
                      ctrl: _descCtrl,
                      hint: 'Décrivez votre offre...',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      validator: (v) =>
                          v == null || v.trim().isEmpty
                              ? 'Requis'
                              : null,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Réduction (%)'),
                              _field(
                                index: 2,
                                ctrl: _discountCtrl,
                                hint: '40',
                                icon: Icons.percent_rounded,
                                keyboard:
                                    TextInputType.number,
                                validator: (v) {
                                  if (v == null ||
                                      v.trim().isEmpty) {
                                    return 'Requis';
                                  }
                                  final n = int.tryParse(
                                      v.trim());
                                  if (n == null ||
                                      n <= 0 ||
                                      n > 100) {
                                    return '1–100%';
                                  }
                                  return null;
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
                              _sectionLabel('Code promo'),
                              _field(
                                index: 3,
                                ctrl: _codeCtrl,
                                hint: 'PIZZA40',
                                icon: Icons.local_offer_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _sectionLabel("Date d'expiration"),
                    _datePicker(),

                    const SizedBox(height: 16),

                    _sectionLabel("Conditions d'utilisation"),
                    _field(
                      index: 4,
                      ctrl: _conditionsCtrl,
                      hint: "Conditions d'utilisation...",
                      icon: Icons.info_outline_rounded,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 30),

                    GradientButton(
                      label: _uploading
                          ? 'Upload images...'
                          : _loading
                              ? 'Publication...'
                              : 'Publier la promotion',
                      icon: Icons.rocket_launch_rounded,
                      onTap: _loading ? null : _submit,
                      loading: _loading,
                    ),

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
          // Add button
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    '${_images.length}/5',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // Image previews
          ..._images.asMap().entries.map((entry) {
            final i    = entry.key;
            final file = entry.value;
            return Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: FutureBuilder<Uint8List>(
                      future: file.readAsBytes().then((v) => v),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          );
                        }
                        return Image.memory(
                          snap.data!,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => _removeImage(i),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── FORM HELPERS ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
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
  }

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
      onFocusChange: (v) =>
          setState(() => _focused = v ? index : -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                focused ? AppColors.primary : AppColors.border,
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppColors.primary
                        .withValues(alpha: 0.1),
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
          initialDate:
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

  Widget _bgCircle(double size, Color color, double alpha) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha),
        ),
      );
}

