import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/business_service.dart';
import '../services/storage_service.dart';

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
  bool _obscure = true;
  int _focused  = -1;
  String? _selectedCategory;
  File? _matriculeImage;

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _commerceCtrl = TextEditingController();
  final _matriculeCtrl= TextEditingController();

  static const _categories = [
    'café', 'resto', 'vetement', 'reparation', 'publinet', 'librairie',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
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

    setState(() => _loading = true);
    try {
      if (_isClient) {
        await AuthService.createClient(
          name:     _nameCtrl.text.trim(),
          email:    _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      } else {
        final user = await AuthService.createBusiness(
          ownerName:    _nameCtrl.text.trim(),
          email:        _emailCtrl.text.trim(),
          password:     _passCtrl.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isClient
            ? 'Compte créé avec succès !'
            : 'Demande envoyée ! En attente de validation.'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) _err(_authErr(e.code));
    } catch (e) {
      if (mounted) _err('Erreur : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  String _authErr(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Cet email est déjà utilisé.';
      case 'weak-password':        return 'Mot de passe trop faible (min. 6 caractères).';
      case 'invalid-email':        return 'Format email invalide.';
      default:                     return 'Erreur : $code';
    }
  }

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

                          _field(0, _nameCtrl, 'Nom complet',
                              Icons.person_outline_rounded,
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Requis' : null),
                          const SizedBox(height: 14),

                          _field(1, _emailCtrl, 'Email',
                              Icons.mail_outline_rounded,
                              keyboard: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email requis';
                                }
                                if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                                    .hasMatch(v.trim())) {
                                  return 'Format invalide';
                                }
                                return null;
                              }),
                          const SizedBox(height: 14),

                          _field(2, _passCtrl, 'Mot de passe',
                              Icons.lock_outline_rounded,
                              isPassword: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requis';
                                if (v.length < 6) return 'Min. 6 caractères';
                                return null;
                              }),

                          // Business-only fields
                          if (!_isClient) ...[
                            const SizedBox(height: 14),
                            _field(3, _commerceCtrl, 'Nom du commerce',
                                Icons.store_outlined,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Requis' : null),
                            const SizedBox(height: 14),
                            _field(4, _matriculeCtrl, 'Matricule fiscal',
                                Icons.badge_outlined,
                                validator: (v) =>
                                    v == null || v.trim().isEmpty ? 'Requis' : null),
                            const SizedBox(height: 12),

                            // Matricule image picker
                            _imagePicker(),

                            const SizedBox(height: 20),

                            const Text('Catégorie',
                                style: TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((cat) {
                                final sel = _selectedCategory == cat;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedCategory = cat),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: sel
                                          ? AppColors.primaryGradient
                                          : null,
                                      color: sel ? null : AppColors.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: sel
                                            ? Colors.transparent
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : AppColors.textMuted,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 20),

                            // Map picker
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
    bool isPassword = false,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    final focused = _focused == index;
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
          obscureText: isPassword ? _obscure : false,
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
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
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
    } catch (_) {}
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
