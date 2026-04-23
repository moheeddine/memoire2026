import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscure    = true;
  bool _loading    = false;
  bool _pressed    = false;
  int  _focused    = -1;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await AuthService.signIn(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      if (!mounted) return;
      switch (user.role) {
        case UserRole.client:
          Navigator.pushReplacementNamed(context, '/home');
        case UserRole.entreprise:
          Navigator.pushReplacementNamed(
            context,
            user.status == UserStatus.pending
                ? '/waiting'
                : '/business_dashboard',
          );
        case UserRole.admin:
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        default:
          Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _err(_authMsg(e.code));
    } catch (_) {
      if (mounted) _err('Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _err('Entrez votre email pour réinitialiser le mot de passe.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Email de réinitialisation envoyé !'),
          backgroundColor: AppColors.success,
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _err(_authMsg(e.code));
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  String _authMsg(String code) {
    switch (code) {
      case 'user-not-found':    return 'Aucun compte avec cet email.';
      case 'wrong-password':
      case 'invalid-credential':return 'Email ou mot de passe incorrect.';
      case 'invalid-email':     return 'Format email invalide.';
      case 'user-disabled':     return 'Ce compte a été désactivé.';
      case 'too-many-requests': return 'Trop de tentatives. Réessayez plus tard.';
      default:                  return 'Erreur : $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ─── gradient header ─────────────────────────────────────────────
          Container(
            height: MediaQuery.of(context).size.height * 0.42,
            decoration: const BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),

          // ─── decorative circles ──────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: _circle(200, Colors.white, 0.08),
          ),
          Positioned(
            top: 60,
            left: -80,
            child: _circle(160, Colors.white, 0.06),
          ),

          // ─── scrollable body ─────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Logo + title
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.location_city_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'CityOne',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bienvenue ! Connectez-vous',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ─── Form card ────────────────────────────────────────────
                  SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Container(
                        padding: const EdgeInsets.all(28),
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
                              const Text(
                                'Connexion',
                                style: TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Email field
                              _buildField(
                                index: 0,
                                ctrl: _emailCtrl,
                                hint: 'Email',
                                icon: Icons.mail_outline_rounded,
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
                                },
                              ),

                              const SizedBox(height: 14),

                              // Password field
                              _buildField(
                                index: 1,
                                ctrl: _passCtrl,
                                hint: 'Mot de passe',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Mot de passe requis';
                                  }
                                  if (v.length < 6) return 'Min. 6 caractères';
                                  return null;
                                },
                              ),

                              const SizedBox(height: 10),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resetPassword,
                                  child: const Text(
                                    'Mot de passe oublié ?',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Submit
                              GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _pressed = true),
                                onTapUp: (_) {
                                  setState(() => _pressed = false);
                                  _login();
                                },
                                onTapCancel: () =>
                                    setState(() => _pressed = false),
                                child: AnimatedScale(
                                  scale: _pressed ? 0.96 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: GradientButton(
                                      label: 'Se connecter',
                                      onTap: _login,
                                      loading: _loading,
                                      icon: Icons.login_rounded,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Register link
                  FadeTransition(
                    opacity: _fade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Pas encore de compte ? ",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RegisterScreen()),
                          ),
                          child: const Text(
                            "S'inscrire",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildField({
    required int index,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
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
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, color: focused ? AppColors.primary : AppColors.textLight, size: 20),
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

  Widget _circle(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: alpha),
        ),
      );
}
