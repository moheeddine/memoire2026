import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/required_label.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ForgotPasswordScreen
//
// Flow:
//   1 — User enters email → local validation
//   2 — Firebase sendPasswordResetEmail()
//   3 — Success: always show generic confirmation (security: never reveal
//       whether an email exists).  user-not-found is silently treated as
//       success.
//   4 — Hard errors (network, rate-limit): shown as SnackBar; screen stays
//       on the input state so the user can retry.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ForgotPasswordScreen extends StatefulWidget {
  /// Optional: pre-fills the email field with the value from the login screen.
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;

  bool _loading = false;
  bool _sent    = false;
  bool _focused = false;

  // ── Entrance animation (slide + fade on open) ────────────────────────────
  late final AnimationController _entCtrl;
  late final Animation<double>   _entFade;
  late final Animation<Offset>   _entSlide;

  // ── Success checkmark animation ──────────────────────────────────────────
  late final AnimationController _okCtrl;
  late final Animation<double>   _okScale;
  late final Animation<double>   _okFade;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');

    _entCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _entFade  = CurvedAnimation(parent: _entCtrl, curve: Curves.easeIn);
    _entSlide = Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entCtrl, curve: Curves.easeOut));

    _okCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _okScale = CurvedAnimation(parent: _okCtrl, curve: Curves.elasticOut);
    _okFade  = CurvedAnimation(parent: _okCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _entCtrl.dispose();
    _okCtrl.dispose();
    super.dispose();
  }

  // ─── SUBMIT ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await AuthService.sendPasswordReset(_emailCtrl.text.trim());
      if (!mounted) return;
      _onSuccess();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'user-not-found':
          // Security: do not reveal whether the account exists — treat as success.
          _onSuccess();
        case 'too-many-requests':
          setState(() => _loading = false);
          _showError('Trop de tentatives. Veuillez réessayer dans quelques minutes.');
        case 'network-request-failed':
          setState(() => _loading = false);
          _showError('Pas de connexion internet. Vérifiez votre réseau.');
        case 'invalid-email':
          setState(() => _loading = false);
          _showError('Format email invalide.');
        default:
          setState(() => _loading = false);
          _showError('Une erreur est survenue. Veuillez réessayer.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Une erreur est survenue. Veuillez réessayer.');
    }
  }

  void _onSuccess() {
    setState(() { _loading = false; _sent = true; });
    _okCtrl.forward();
  }

  void _retry() {
    _okCtrl.reset();
    setState(() => _sent = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ]),
        backgroundColor: AppColors.error,
        behavior:  SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin:   const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // ── Gradient header ────────────────────────────────────────────────
        Container(
          height: MediaQuery.of(context).size.height * 0.42,
          decoration: const BoxDecoration(
            gradient: AppColors.mainGradient,
            borderRadius: BorderRadius.only(
              bottomLeft:  Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),

        // ── Decorative circles ─────────────────────────────────────────────
        Positioned(top: -60, right: -60, child: _circle(200, Colors.white, 0.08)),
        Positioned(top:  60, left: -80, child: _circle(160, Colors.white, 0.06)),

        // ── Content ────────────────────────────────────────────────────────
        SafeArea(
          child: Column(children: [
            // Back arrow
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  const SizedBox(height: 4),

                  // Header logo + title
                  FadeTransition(
                    opacity: _entFade,
                    child: _buildHeader(),
                  ),

                  const SizedBox(height: 32),

                  // Card
                  SlideTransition(
                    position: _entSlide,
                    child: FadeTransition(
                      opacity: _entFade,
                      child: Container(
                        width: double.infinity,
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve:  Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end:   Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: _sent ? _buildSuccess() : _buildForm(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 36),
      ),
      const SizedBox(height: 14),
      const Text(
        'PromoCity',
        style: TextStyle(
          color: Colors.white, fontSize: 28,
          fontWeight: FontWeight.w800, letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Réinitialisation du mot de passe',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
      ),
    ]);
  }

  // ─── FORM STATE ───────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card title row
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Mot de passe oublié ?',
                style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          const Text(
            'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13, height: 1.55),
          ),

          const SizedBox(height: 22),

          const RequiredLabel('Email'),
          _buildEmailField(),

          const SizedBox(height: 22),

          // CTA button
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label:   'Envoyer le lien',
              onTap:   _loading ? null : _submit,
              loading: _loading,
              icon:    Icons.send_rounded,
            ),
          ),

          const SizedBox(height: 14),

          // Back to login
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted),
              child: const Text(
                '← Retour à la connexion',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SUCCESS STATE ────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // Animated checkmark circle
        ScaleTransition(
          scale: _okScale,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
          ),
        ),

        const SizedBox(height: 20),

        // Confirmation text
        FadeTransition(
          opacity: _okFade,
          child: Column(children: [
            const Text(
              'Email envoyé !',
              style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Si cet email est associé à un compte, un lien de réinitialisation a été envoyé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pensez à vérifier vos spams.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Sent-to badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mail_outline_rounded,
                    color: AppColors.primary, size: 15),
                const SizedBox(width: 8),
                Text(
                  _emailCtrl.text.trim(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // Back to login
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            label: 'Retour à la connexion',
            onTap: () => Navigator.pop(context),
            icon:  Icons.login_rounded,
          ),
        ),

        const SizedBox(height: 10),

        // Resend link
        Center(
          child: TextButton(
            onPressed: _retry,
            style: TextButton.styleFrom(foregroundColor: AppColors.textLight),
            child: const Text('Renvoyer le lien', style: TextStyle(fontSize: 12)),
          ),
        ),

        const SizedBox(height: 4),
      ],
    );
  }

  // ─── EMAIL FIELD ──────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? AppColors.primary : AppColors.border,
            width: _focused ? 2 : 1,
          ),
        ),
        child: TextFormField(
          controller:    _emailCtrl,
          keyboardType:  TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onFieldSubmitted: (_) { if (!_loading) _submit(); },
          validator: Validators.email,
          style: const TextStyle(color: AppColors.textDark, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.mail_outline_rounded,
              color: _focused ? AppColors.primary : AppColors.textLight,
              size: 20,
            ),
            hintText:  'votre@email.com',
            hintStyle: const TextStyle(color: AppColors.textLight),
            border:    InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _circle(double size, Color color, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );
}
