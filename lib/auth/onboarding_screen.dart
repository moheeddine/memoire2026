import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  late AnimationController _iconCtrl;
  late Animation<double> _iconScale;

  static const _pages = [
    _OnboardingData(
      icon: Icons.location_on_rounded,
      title: 'Promos près de vous',
      desc:
          'Découvrez les meilleures offres autour de vous en temps réel grâce à la géolocalisation.',
      gradient: [AppColors.pink, Color(0xFFFF8C42)],
    ),
    _OnboardingData(
      icon: Icons.auto_awesome_rounded,
      title: 'IA qui apprend vos goûts',
      desc:
          'Notre intelligence artificielle analyse vos habitudes et vous suggère les offres les plus pertinentes.',
      gradient: [AppColors.purple, AppColors.pink],
    ),
    _OnboardingData(
      icon: Icons.savings_rounded,
      title: 'Économisez à chaque sortie',
      desc:
          'Utilisez vos codes promo directement et naviguez vers le commerce en un clic.',
      gradient: [AppColors.blue, AppColors.purple],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut),
    );
    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _goLogin();
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Soft gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ..._pages[_currentPage].gradient,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _goLogin,
                        child: Text(
                          'Passer',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) {
                      setState(() => _currentPage = i);
                      _iconCtrl.forward(from: 0);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _OnboardingPage(
                      data: _pages[i],
                      iconScale: _iconScale,
                      isActive: i == _currentPage,
                    ),
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Column(
                    children: [
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == i ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 28),

                      // CTA button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _next,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _currentPage == _pages.length - 1
                                    ? 'Commencer →'
                                    : 'Suivant →',
                                style: TextStyle(
                                  color: _pages[_currentPage].gradient.first,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DATA MODEL ───────────────────────────────────────────────────────────────

class _OnboardingData {
  final IconData icon;
  final String title;
  final String desc;
  final List<Color> gradient;

  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.gradient,
  });
}

// ─── PAGE WIDGET ──────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final Animation<double> iconScale;
  final bool isActive;

  const _OnboardingPage({
    required this.data,
    required this.iconScale,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          ScaleTransition(
            scale: isActive ? iconScale : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.gradient.first.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                data.icon,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            data.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
