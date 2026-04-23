import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── COLOR PALETTE ────────────────────────────────────────────────────────────

class AppColors {
  // Gradient palette
  static const Color pink   = Color(0xFFEC4899);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color blue   = Color(0xFF06B6D4);

  // Primary (purple — main interactive colour)
  static const Color primary      = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFFF5F3FF);
  static const Color primaryDark  = Color(0xFF6D28D9);

  // Accent (pink — hearts, badges, highlights)
  static const Color accent      = Color(0xFFEC4899);
  static const Color accentLight = Color(0xFFFDF2F8);

  // Surfaces
  static const Color bg      = Color(0xFFF9FAFB);
  static const Color card    = Colors.white;
  static const Color surface = Color(0xFFF3F4F6);

  // Text
  static const Color textDark  = Color(0xFF111827);
  static const Color textBody  = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);

  // Border
  static const Color border = Color(0xFFE5E7EB);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error   = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info    = Color(0xFF3B82F6);

  // ─── GRADIENTS ──────────────────────────────────────────────────────────────

  /// Main brand gradient: pink → purple → blue
  static const LinearGradient mainGradient = LinearGradient(
    colors: [pink, purple, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft pastel gradient for backgrounds
  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0xFFFDF2F8), Color(0xFFF5F3FF), Color(0xFFECFEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Pink → purple only (for buttons, CTAs)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [pink, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Card shimmer gradient
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFDF2F8), Color(0xFFF5F3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─── THEME DATA ───────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.primary,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary:          AppColors.primary,
        onPrimary:        Colors.white,
        secondary:        AppColors.accent,
        onSecondary:      Colors.white,
        surface:          AppColors.card,
        onSurface:        AppColors.textDark,
        error:            AppColors.error,
        onError:          Colors.white,
        tertiary:         AppColors.blue,
        onTertiary:       Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textDark),
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textLight),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight,
        labelStyle:
            const TextStyle(color: AppColors.primary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.textDark,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 14),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      iconTheme: const IconThemeData(color: AppColors.textDark),
      primaryIconTheme: const IconThemeData(color: AppColors.primary),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
          fontSize: 32,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        titleLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textBody,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
        ),
        labelSmall: TextStyle(
          color: AppColors.textLight,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────

/// Gradient button used across all screens
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double height;
  final IconData? icon;
  final LinearGradient? gradient;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.height = 54,
    this.icon,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          gradient: onTap == null
              ? const LinearGradient(
                  colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)])
              : (gradient ?? AppColors.primaryGradient),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Vibrant card with optional gradient border
class VibrantCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final bool gradientBorder;
  final double radius;

  const VibrantCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.gradientBorder = false,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: gradientBorder
            ? null
            : Border.all(color: AppColors.border),
      ),
      child: child,
    );

    if (gradientBorder) {
      return Container(
        decoration: BoxDecoration(
          gradient: AppColors.mainGradient,
          borderRadius: BorderRadius.circular(radius + 1.5),
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? AppColors.card,
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
    }

    return content;
  }
}

/// Gradient avatar ring (Instagram stories style)
class GradientAvatar extends StatelessWidget {
  final Widget child;
  final double size;
  final bool active;

  const GradientAvatar({
    super.key,
    required this.child,
    this.size = 48,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 6,
      height: size + 6,
      decoration: BoxDecoration(
        gradient: active ? AppColors.mainGradient : null,
        color: active ? null : AppColors.border,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(child: child),
      ),
    );
  }
}
