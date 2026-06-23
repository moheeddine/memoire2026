import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── DESIGN TOKENS — COLORS ───────────────────────────────────────────────────

class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color pink   = Color(0xFFEC4899);
  static const Color purple = Color(0xFF7C3AED);
  static const Color blue   = Color(0xFF3B82F6); // alias for info, kept for back-compat
  static const Color orange = Color(0xFFF97316);

  // ── Primary (deep violet) ─────────────────────────────────────────────────
  static const Color primary      = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFF5F3FF);
  static const Color primaryDark  = Color(0xFF6D28D9);

  // ── Accent (pink) ─────────────────────────────────────────────────────────
  static const Color accent      = Color(0xFFEC4899);
  static const Color accentLight = Color(0xFFFDF2F8);

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color bg      = Color(0xFFF8FAFC);
  static const Color card    = Colors.white;
  static const Color surface = Color(0xFFF3F4F6);

  // ── Text — all WCAG AA+ compliant against white (#FFFFFF) ─────────────────
  // Previous textLight (0xFF9CA3AF) had 2.8:1 contrast — FAILS WCAG AA.
  // Every value below meets the 4.5:1 minimum for normal text.
  static const Color textDark  = Color(0xFF111827); // 19.7:1 — AAA
  static const Color textBody  = Color(0xFF374151); // 10.8:1 — AAA
  static const Color textMuted = Color(0xFF4B5563); //  7.6:1 — AAA (was 6B7280)
  static const Color textLight = Color(0xFF6B7280); //  4.6:1 — AA  (was 9CA3AF)

  // ── Icon system ───────────────────────────────────────────────────────────
  // Named semantically so icon colour choices are deliberate, not accidental.
  static const Color iconDark   = textDark;   // max-contrast (titles, primary actions)
  static const Color iconBody   = textBody;   // default on-surface icon
  static const Color iconMuted  = textMuted;  // secondary / inactive icons
  static const Color iconSubtle = textLight;  // decorative / placeholder only

  // ── Border ────────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color error   = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info    = Color(0xFF3B82F6);

  // ── Gradients ─────────────────────────────────────────────────────────────
  // 2-stop professional brand gradient (violet → rose).
  static const LinearGradient mainGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Horizontal variant for buttons / chips.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows (semantic helpers) ────────────────────────────────────────────
  /// Standard card shadow — neutral depth + optional colour ambient glow.
  static List<BoxShadow> cardShadow({Color? tint}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    if (tint != null)
      BoxShadow(
        color: tint.withValues(alpha: 0.12),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
  ];

  static List<BoxShadow> get primaryShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

// ─── DESIGN TOKENS — SPACING ──────────────────────────────────────────────────

class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
}

// ─── DESIGN TOKENS — RADII ────────────────────────────────────────────────────

class AppRadius {
  static const double sm   = 10;
  static const double md   = 14;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double pill = 100;

  static BorderRadius get smR   => BorderRadius.circular(sm);
  static BorderRadius get mdR   => BorderRadius.circular(md);
  static BorderRadius get lgR   => BorderRadius.circular(lg);
  static BorderRadius get xlR   => BorderRadius.circular(xl);
  static BorderRadius get xxlR  => BorderRadius.circular(xxl);
  static BorderRadius get pillR => BorderRadius.circular(pill);
}

// ─── THEME DATA ───────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.primary,

      colorScheme: const ColorScheme.light(
        primary:           AppColors.primary,
        onPrimary:         Colors.white,
        secondary:         AppColors.accent,
        onSecondary:       Colors.white,
        surface:           AppColors.card,
        onSurface:         AppColors.textDark,
        surfaceContainer:  AppColors.surface,
        error:             AppColors.error,
        onError:           Colors.white,
        tertiary:          AppColors.orange,
        onTertiary:        Colors.white,
        outline:           AppColors.border,
        outlineVariant:    AppColors.border,
      ),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // textDark gives icons maximum contrast on white appbar
        iconTheme: IconThemeData(color: AppColors.textDark, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.textMuted, size: 22),
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // ── Icon defaults ─────────────────────────────────────────────────────
      // textBody (10.8:1 contrast) instead of old textLight (2.8:1) ensures
      // any icon without an explicit colour is readable on any light surface.
      iconTheme: const IconThemeData(color: AppColors.textBody, size: 22),
      primaryIconTheme: const IconThemeData(color: AppColors.primary, size: 22),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlR,
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input decoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        // Global prefix/suffix icon colour — textMuted passes WCAG AA
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdR,
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),

      // ── Elevated button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdR),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight,
        labelStyle: const TextStyle(
            color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: BorderSide.none,
        iconTheme: const IconThemeData(color: AppColors.primary, size: 14),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: AppRadius.mdR),
        backgroundColor: AppColors.textDark,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: AppColors.primary,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xxlR),
        elevation: 8,
        titleTextStyle: const TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
      ),

      // ── BottomNavigationBar ───────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textBody,
        textColor: AppColors.textDark,
        subtitleTextStyle:
            TextStyle(color: AppColors.textMuted, fontSize: 13),
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),

      // ── Text theme ────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -1,
        ),
        displayMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w800,
          fontSize: 28,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        titleSmall: TextStyle(
          color: AppColors.textBody,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textBody,
          fontSize: 15,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: AppColors.textBody,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
        labelSmall: TextStyle(
          color: AppColors.textLight,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE DESIGN SYSTEM WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── AppIconBox ───────────────────────────────────────────────────────────────
/// Solid coloured icon container — white icon on full-opacity background.
///
/// Always fully visible regardless of surrounding card colour.
/// `solid` = true (default): opaque background + white icon + coloured glow.
/// `solid` = false: 18 % tint background + coloured icon (for subtle contexts).
class AppIconBox extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final double   size;
  final double?  iconSize;
  final bool     solid;

  const AppIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size     = 44,
    this.iconSize,
    this.solid    = true,
  });

  @override
  Widget build(BuildContext context) {
    final iSize = iconSize ?? size * 0.48;
    if (solid) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.27),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.38),
              blurRadius: size * 0.35,
              offset: Offset(0, size * 0.14),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iSize),
      );
    }
    // Soft variant — tinted bg + coloured icon (use in non-card contexts)
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(icon, color: color, size: iSize),
    );
  }
}

// ─── AppStatCard ──────────────────────────────────────────────────────────────
/// Live-updating dashboard stat card backed by a Firestore stream.
class AppStatCard<T> extends StatelessWidget {
  final String        label;
  final String?       sublabel;
  final IconData      icon;
  final Color         color;
  final Stream<T>     stream;
  final int Function(T) count;
  final VoidCallback? onTap;
  final bool          compact;

  const AppStatCard({
    super.key,
    required this.label,
    this.sublabel,
    required this.icon,
    required this.color,
    required this.stream,
    required this.count,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snap) {
        final n = snap.hasData ? count(snap.data as T) : 0;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.lgR,
              boxShadow: [
                // Neutral depth shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                // Coloured ambient glow
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: compact ? _compactBody(n) : _fullBody(n),
          ),
        );
      },
    );
  }

  Widget _fullBody(int n) => Row(
    children: [
      AppIconBox(icon: icon, color: color, size: 52, iconSize: 26),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$n',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                  color: AppColors.textBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
            if (sublabel != null)
              Text(sublabel!,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  )),
          ],
        ),
      ),
      if (onTap != null)
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 12),
        ),
    ],
  );

  Widget _compactBody(int n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppIconBox(icon: icon, color: color, size: 38, iconSize: 19),
      const SizedBox(height: 12),
      Text('$n',
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
      if (sublabel != null)
        Text(sublabel!,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 10,
            )),
    ],
  );
}

// ─── AppSectionTitle ──────────────────────────────────────────────────────────
/// Consistent section heading used across all screens.
class AppSectionTitle extends StatelessWidget {
  final String        title;
  final String?       action;
  final VoidCallback? onAction;

  const AppSectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── AppStatusBadge ───────────────────────────────────────────────────────────
/// Pill-shaped coloured badge — replaces ad-hoc Container + Text patterns.
class AppStatusBadge extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppEmptyState ────────────────────────────────────────────────────────────
/// Consistent empty / all-clear state for lists and streams.
/// Use `fullScreen: true` for screen-level empty states (centered icon + text).
/// Use `fullScreen: false` (default) for inline banner inside a list.
class AppEmptyState extends StatelessWidget {
  final String        message;
  final IconData      icon;
  final String?       action;
  final VoidCallback? onAction;
  final bool          fullScreen;

  const AppEmptyState({
    super.key,
    required this.message,
    this.icon       = Icons.check_circle_rounded,
    this.action,
    this.onAction,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (fullScreen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 20),
                AppPressable(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: AppRadius.pillR,
                      boxShadow: AppColors.primaryShadow,
                    ),
                    child: Text(
                      action!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Inline banner variant (default)
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.lgR,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
        ],
      ),
    );
  }
}

// ─── AppInfoBadge ─────────────────────────────────────────────────────────────
/// Compact inline info badge — for expiry countdowns, spot counts, etc.
class AppInfoBadge extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;

  const AppInfoBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GradientButton ───────────────────────────────────────────────────────────
/// Primary CTA button with gradient background + optional icon.
class GradientButton extends StatelessWidget {
  final String           label;
  final VoidCallback?    onTap;
  final bool             loading;
  final double           height;
  final IconData?        icon;
  final LinearGradient?  gradient;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading  = false,
    this.height   = 54,
    this.icon,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !loading;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          gradient: disabled
              ? const LinearGradient(
                  colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)])
              : (gradient ?? AppColors.primaryGradient),
          borderRadius: AppRadius.mdR,
          boxShadow: disabled ? null : AppColors.primaryShadow,
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

// ─── VibrantCard ──────────────────────────────────────────────────────────────
/// Card with optional gradient border (Instagram-style).
class VibrantCard extends StatelessWidget {
  final Widget        child;
  final EdgeInsets?   padding;
  final Color?        color;
  final bool          gradientBorder;
  final double        radius;

  const VibrantCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.gradientBorder = false,
    this.radius         = 20,
  });

  @override
  Widget build(BuildContext context) {
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

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppColors.cardShadow(),
      ),
      child: child,
    );
  }
}

// ─── AppSkeletonLoader ────────────────────────────────────────────────────────
/// Animated shimmer placeholder for any loading state.
/// Leave [width] null to fill the available horizontal space.
class AppSkeletonLoader extends StatefulWidget {
  final double? width;
  final double  height;
  final double  radius;

  const AppSkeletonLoader({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  State<AppSkeletonLoader> createState() => _AppSkeletonLoaderState();
}

class _AppSkeletonLoaderState extends State<AppSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.80).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final box = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            color: AppColors.border.withValues(alpha: _anim.value),
          ),
          child: const SizedBox.expand(),
        );
        return widget.width != null
            ? SizedBox(width: widget.width, height: widget.height, child: box)
            : SizedBox(height: widget.height, child: box);
      },
    );
  }
}

// ─── AppSkeletonCard ──────────────────────────────────────────────────────────
/// Shimmer card placeholder matching the standard list-card shape.
/// Drop-in replacement for a CircularProgressIndicator in list loading states.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:     const EdgeInsets.only(bottom: 12),
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: AppRadius.lgR,
        border:       Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          AppSkeletonLoader(width: 56, height: 56, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLoader(height: 14, radius: 7),
                SizedBox(height: 8),
                AppSkeletonLoader(width: 140, height: 12, radius: 6),
                SizedBox(height: 6),
                AppSkeletonLoader(width: 90, height: 10, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppPressable ─────────────────────────────────────────────────────────────
/// Adds a scale-down press animation + haptic feedback to any child widget.
/// Replaces bare `GestureDetector` on every tappable card/button.
class AppPressable extends StatefulWidget {
  final Widget        child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double        scale;
  final bool          haptic;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale  = 0.97,
    this.haptic = true,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _down(_) => setState(() => _pressed = true);
  void _up(_) {
    setState(() => _pressed = false);
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }
  void _cancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   _down,
      onTapUp:     _up,
      onTapCancel: _cancel,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale:    _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve:    Curves.easeInOut,
        child:    widget.child,
      ),
    );
  }
}

// ─── GradientAvatar ───────────────────────────────────────────────────────────
/// Instagram-style gradient ring around an avatar.
class GradientAvatar extends StatelessWidget {
  final Widget child;
  final double size;
  final bool   active;

  const GradientAvatar({
    super.key,
    required this.child,
    this.size   = 48,
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
