import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_routes.dart';
import 'dashboard_screen.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onApproved(String uid) {
    if (_navigated) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Votre compte a été activé !',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(businessId: uid),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<UserModel?>(
        stream: AuthService.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          if (user?.status == UserStatus.active) {
            _onApproved(uid);
          }

          return Container(
            decoration: const BoxDecoration(gradient: AppColors.softGradient),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Animated clock icon
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: AppColors.mainGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.35),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.white,
                            size: 54,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Title
                      const Text(
                        'Demande envoyée',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Description
                      const Text(
                        "Votre compte est en attente de validation par l'administrateur.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color:
                                  AppColors.warning.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.warning.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notifications_outlined,
                                color: AppColors.warning, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Vous recevrez une notification dès que votre compte sera activé.',
                                style: TextStyle(
                                  color: AppColors.textBody,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Steps
                      const SizedBox(height: 24),
                      const _StepRow(
                          number: '1',
                          text: 'Dossier soumis à l\'administrateur'),
                      const SizedBox(height: 10),
                      const _StepRow(
                          number: '2',
                          text: 'Vérification de votre matricule fiscal'),
                      const SizedBox(height: 10),
                      const _StepRow(
                          number: '3',
                          text: 'Activation et accès au dashboard'),

                      const Spacer(),

                      // Logout
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: 'Se déconnecter',
                          icon: Icons.logout_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          onTap: () async {
                            await AuthService.signOut();
                            if (!context.mounted) return;
                            Navigator.pushNamedAndRemoveUntil(
                                context, AppRoutes.login, (_) => false);
                          },
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textBody,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
