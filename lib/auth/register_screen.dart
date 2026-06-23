import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../models/category_model.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/category_service.dart';
import '../services/storage_service.dart';
import '../utils/app_routes.dart';
import '../utils/error_handler.dart';
import '../utils/validators.dart';
import '../widgets/required_label.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isClient = true;
  LatLng? _location;
  bool _loading = false;
  bool _obscure        = true;
  bool _obscureConfirm = true;
  int _focused         = -1;
  String? _selectedCategory;
  File? _matriculeImage;
  bool _contractAccepted = false;

  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passCtrl        = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _commerceCtrl    = TextEditingController();
  final _matriculeCtrl   = TextEditingController();

  List<CategoryModel> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _passCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getAll();
    if (mounted) setState(() => _categories = cats);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _commerceCtrl.dispose();
    _matriculeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isClient && _location == null) {
      _err('Veuillez choisir la localisation de votre commerce.');
      return;
    }
    if (!_isClient && _selectedCategory == null) {
      _err('Veuillez sélectionner une catégorie.');
      return;
    }
    if (!_isClient && !_contractAccepted) {
      _err("Vous devez accepter les conditions d'utilisation.");
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isClient) {
        await AuthService.createClient(
          name:     _nameCtrl.text.trim(),
          email:    _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        final user = await AuthService.createBusiness(
          ownerName:    _nameCtrl.text.trim(),
          email:        _emailCtrl.text.trim(),
          password:     _passCtrl.text,
          commerceName: _commerceCtrl.text.trim(),
          matricule:    _matriculeCtrl.text.trim(),
          category:     _selectedCategory!,
          lat:          _location!.latitude,
          lng:          _location!.longitude,
        );
        if (_matriculeImage != null) {
          final url = await StorageService.uploadMatricule(
              user.uid, _matriculeImage!);
          if (url != null) {
            await BusinessService.updateMatriculeImageUrl(user.uid, url);
          }
        }
      }

      if (!mounted) return;
      if (_isClient) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.waiting, (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _err(_authErr(e.code));
    } catch (e) {
      AppErrorHandler.log('Register', e);
      if (mounted) _err(AppErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) {
    AppErrorHandler.showMessage(context, msg, isError: true);
  }

  String _authErr(String code) => AppErrorHandler.getMessage(
        FirebaseAuthException(code: code),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Gradient header
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -50,
            child: _circle(180, Colors.white, 0.08),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Créer un compte',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple.withValues(alpha: 0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Toggle client / entreprise
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                _toggleTab('Client', true),
                                _toggleTab('Entreprise', false),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          const RequiredLabel('Nom complet'),
                          _field(0, _nameCtrl, 'Nom complet',
                              Icons.person_outline_rounded,
                              validator: Validators.fullName),
                          const SizedBox(height: 14),

                          const RequiredLabel('Email'),
                          _field(1, _emailCtrl, 'Email',
                              Icons.mail_outline_rounded,
                              keyboard: TextInputType.emailAddress,
                              validator: Validators.email),
                          const SizedBox(height: 14),

                          const RequiredLabel('Mot de passe'),
                          _field(2, _passCtrl, 'Mot de passe',
                              Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: Validators.password),
                          if (_passCtrl.text.isNotEmpty)
                            _passwordStrengthBar(_passCtrl.text),
                          const SizedBox(height: 14),
                          const RequiredLabel('Confirmer le mot de passe'),
                          _field(
                            5,
                            _confirmPassCtrl,
                            'Confirmer le mot de passe',
                            Icons.lock_outline_rounded,
                            isPassword: true,
                            customObscure: _obscureConfirm,
                            onToggleObscure: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Veuillez confirmer votre mot de passe';
                              }
                              if (v != _passCtrl.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),

                          // Business-only fields
                          if (!_isClient) ...[
                            const SizedBox(height: 14),
                            const RequiredLabel('Nom du commerce'),
                            _field(3, _commerceCtrl, 'Nom du commerce',
                                Icons.store_outlined,
                                validator: Validators.commerceName),
                            const SizedBox(height: 14),
                            const RequiredLabel('Matricule fiscal'),
                            _field(4, _matriculeCtrl, 'Matricule fiscal',
                                Icons.badge_outlined,
                                validator: Validators.matricule),
                            const SizedBox(height: 12),

                            // Matricule image picker
                            _imagePicker(),

                            const SizedBox(height: 20),

                            const RequiredLabel('Catégorie'),
                            const SizedBox(height: 2),
                            if (_categories.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.border),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Chargement des catégories...',
                                        style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 14)),
                                  ],
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _selectedCategory != null
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: _selectedCategory != null ? 2 : 1,
                                  ),
                                ),
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedCategory,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 4),
                                  ),
                                  hint: const Text(
                                    'Sélectionner une catégorie',
                                    style: TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 14),
                                  ),
                                  items: _categories.map((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat.name,
                                      child: Text(
                                        '${cat.icon}  ${cat.name}',
                                        style: const TextStyle(
                                          color: AppColors.textDark,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(
                                      () => _selectedCategory = v),
                                ),
                              ),

                            const SizedBox(height: 20),

                            const RequiredLabel('Localisation du commerce'),
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push<LatLng>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MapPickerScreen(),
                                  ),
                                );
                                if (result != null) {
                                  setState(() => _location = result);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _location != null
                                      ? AppColors.primaryLight
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _location != null
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_rounded,
                                        color: _location != null
                                            ? AppColors.primary
                                            : AppColors.textLight),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _location == null
                                            ? 'Choisir localisation du commerce'
                                            : 'Lat: ${_location!.latitude.toStringAsFixed(4)}, '
                                                'Lng: ${_location!.longitude.toStringAsFixed(4)}',
                                        style: TextStyle(
                                          color: _location != null
                                              ? AppColors.primary
                                              : AppColors.textLight,
                                        ),
                                      ),
                                    ),
                                    if (_location != null)
                                      const Icon(Icons.check_circle,
                                          color: AppColors.success, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Contract checkbox (business only)
                          if (!_isClient) ...[
                            const SizedBox(height: 8),
                            _contractSection(),
                          ],

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              label: _isClient
                                  ? 'Créer mon compte'
                                  : 'Envoyer la demande',
                              onTap: _register,
                              loading: _loading,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: RichText(
                                text: const TextSpan(
                                  text: 'Déjà inscrit ? ',
                                  style: TextStyle(color: AppColors.textMuted),
                                  children: [
                                    TextSpan(
                                      text: 'Se connecter',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _toggleTab(String label, bool isClient) {
    final active = _isClient == isClient;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isClient = isClient),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: active ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textMuted,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    int index,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isPassword          = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    bool? customObscure,
    VoidCallback? onToggleObscure,
  }) {
    final focused   = _focused == index;
    final isObscure = customObscure ?? _obscure;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v ? index : -1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? AppColors.primary : AppColors.border,
            width: focused ? 2 : 1,
          ),
        ),
        child: TextFormField(
          controller: ctrl,
          obscureText: isPassword ? isObscure : false,
          keyboardType: keyboard,
          validator: validator,
          style: const TextStyle(color: AppColors.textDark, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon,
                color: focused ? AppColors.primary : AppColors.textLight,
                size: 20),
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textLight),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    onPressed: onToggleObscure ??
                        () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _imagePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked != null) {
          setState(() => _matriculeImage = File(picked.path));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _matriculeImage != null
              ? AppColors.primaryLight
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _matriculeImage != null
                ? AppColors.primary
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.upload_file_rounded,
                color: _matriculeImage != null
                    ? AppColors.primary
                    : AppColors.textLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _matriculeImage != null
                    ? 'Image sélectionnée ✓'
                    : 'Photo du matricule fiscal (optionnel)',
                style: TextStyle(
                  color: _matriculeImage != null
                      ? AppColors.primary
                      : AppColors.textLight,
                  fontSize: 13,
                ),
              ),
            ),
            if (_matriculeImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_matriculeImage!,
                    width: 40, height: 40, fit: BoxFit.cover),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contractSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _contractAccepted
            ? AppColors.primaryLight
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _contractAccepted ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _contractAccepted,
                onChanged: (v) =>
                    setState(() => _contractAccepted = v ?? false),
                activeColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Text(
                  "J'accepte les conditions d'utilisation",
                  style: TextStyle(
                    color: _contractAccepted
                        ? AppColors.primary
                        : AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: GestureDetector(
              onTap: _showContractDialog,
              child: const Text(
                'Lire le contrat →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContractDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.article_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text("Conditions d'utilisation",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContractSection('1. Engagement général',
                    "En rejoignant PromoCity, je m'engage à respecter les règles de la communauté et à utiliser la plateforme de bonne foi."),
                _ContractSection('2. Contenu des promotions',
                    "Je m'engage à ne publier que des promotions réelles et honnêtes. Tout contenu frauduleux, trompeur ou contraire aux bonnes mœurs est strictement interdit."),
                _ContractSection('3. Informations exactes',
                    "Je certifie que les informations fournies lors de mon inscription (nom, matricule fiscal, localisation) sont exactes et à jour."),
                _ContractSection('4. Responsabilité',
                    "Je suis seul responsable des promotions publiées sous mon compte. PromoCity se réserve le droit de supprimer tout contenu ne respectant pas ces conditions."),
                _ContractSection('5. Modération',
                    "PromoCity se réserve le droit de suspendre ou supprimer tout compte ne respectant pas les présentes conditions, sans préavis."),
                _ContractSection('6. Données personnelles',
                    "Les données collectées sont utilisées uniquement dans le cadre du service PromoCity et ne sont pas cédées à des tiers."),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              if (mounted) setState(() => _contractAccepted = true);
              Navigator.pop(ctx);
            },
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }

  Widget _passwordStrengthBar(String password) {
    final score = Validators.passwordStrength(password);
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF6366F1),
    ];
    final labels = ['Très faible', 'Faible', 'Moyen', 'Fort', 'Très fort'];
    final barColor = colors[(score - 1).clamp(0, 4)];
    final label = score == 0 ? '' : labels[(score - 1).clamp(0, 4)];

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < score ? barColor : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: barColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _circle(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha),
        ),
      );
}

// ─── MAP PICKER ───────────────────────────────────────────────────────────────

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _pos = const LatLng(35.0382, 9.4849);

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _pos = LatLng(pos.latitude, pos.longitude));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[MapPicker] location error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir position'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _pos,
              initialZoom: 15,
              onPositionChanged: (pos, _) {
                if (pos.center != null) _pos = pos.center!;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.memoire2026',
              ),
            ],
          ),
          const Center(
            child: Icon(Icons.location_pin, color: AppColors.accent, size: 45),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: GradientButton(
              label: 'Confirmer cette position',
              onTap: () => Navigator.pop(context, _pos),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CONTRACT SECTION WIDGET ──────────────────────────────────────────────────

class _ContractSection extends StatelessWidget {
  final String title;
  final String body;
  const _ContractSection(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
