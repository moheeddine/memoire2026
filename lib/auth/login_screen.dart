import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscure = true;
  bool isPressed = false;
  int focusedIndex = -1;

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Stack(
        children: [

          /// 🌌 BACKGROUND
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeProvider.isDark
                    ? [
                        Color(0xFF020617),
                        Color(0xFF0B1120),
                      ]
                    : [
                        Color(0xFFF8FAFC),
                        Color(0xFFE2E8F0),
                      ],
              ),
            ),
          ),

          /// 💡 LIGHT EFFECT
          Positioned(
            top: -120,
            left: -100,
            child: radialGlow(400),
          ),

          Positioned(
            bottom: -150,
            right: -120,
            child: radialGlow(500),
          ),

          /// 🔥 CARD
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  width: 370,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: themeProvider.isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: themeProvider.isDark
                            ? Colors.white10
                            : Colors.black12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Text(
                        "Bienvenue",
                        style: TextStyle(
                          color: themeProvider.isDark
                              ? Colors.white
                              : Colors.black87,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Connexion sécurisée",
                        style: TextStyle(
                          color: themeProvider.isDark
                              ? Colors.white38
                              : Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 35),

                      /// EMAIL
                      field(
                        index: 0,
                        controller: emailController,
                        hint: "Email",
                        icon: Icons.mail_outline,
                        themeProvider: themeProvider,
                      ),

                      const SizedBox(height: 18),

                      /// PASSWORD
                      field(
                        index: 1,
                        controller: passwordController,
                        hint: "Mot de passe",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        themeProvider: themeProvider,
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(
                            color: themeProvider.isDark
                                ? Colors.white38
                                : Colors.black45,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      /// LOGIN BUTTON
                      GestureDetector(
                        onTapDown: (_) => setState(() => isPressed = true),
                        onTapUp: (_) => setState(() => isPressed = false),
                        onTapCancel: () => setState(() => isPressed = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 55,
                          transform: Matrix4.identity()
                            ..scale(isPressed ? 0.96 : 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF7C3AED),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              "Se connecter",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      /// REGISTER LINK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Pas de compte ? ",
                              style: TextStyle(
                                  color: themeProvider.isDark
                                      ? Colors.white54
                                      : Colors.black54)),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => RegisterScreen()),
                              );
                            },
                            child: Text(
                              "S'inscrire",
                              style: TextStyle(
                                color: Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// 🌗 THEME BUTTON (FINAL FIX 🔥)
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  themeProvider.toggleTheme();
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    themeProvider.isDark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// LIGHT
  Widget radialGlow(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color(0xFF6366F1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  /// FIELD
  Widget field({
    required int index,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ThemeProvider themeProvider,
    bool isPassword = false,
  }) {
    bool isFocused = focusedIndex == index;

    return Focus(
      onFocusChange: (value) {
        setState(() {
          focusedIndex = value ? index : -1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: themeProvider.isDark
              ? Colors.white.withOpacity(0.05)
              : Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFocused
                ? Color(0xFF6366F1)
                : Colors.transparent,
          ),
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword ? obscure : false,
          style: TextStyle(
              color: themeProvider.isDark
                  ? Colors.white
                  : Colors.black),
          decoration: InputDecoration(
            icon: Icon(icon,
                color: themeProvider.isDark
                    ? Colors.white70
                    : Colors.grey),
            hintText: hint,
            hintStyle: TextStyle(
                color: themeProvider.isDark
                    ? Colors.white38
                    : Colors.grey),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}