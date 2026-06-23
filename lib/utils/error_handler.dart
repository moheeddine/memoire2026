import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── GLOBAL ERROR HANDLER ────────────────────────────────────────────────────
//
// Single source of truth for all Firebase/network error → user-friendly French
// message mapping. Never exposes raw Firebase error codes or exception strings
// to users. All raw details are written to the debug console only.
//
// Usage in screens:
//   catch (e) {
//     AppErrorHandler.showError(context, e, logContext: 'PromoService.add');
//   }
//
// Usage in services (message-only, no BuildContext):
//   catch (e) {
//     AppErrorHandler.log('QR scan', e);
//     return AppErrorHandler.getMessage(e);
//   }

class AppErrorHandler {
  AppErrorHandler._();

  // ─── Console logging (developer only, never shown to user) ────────────────

  static void log(String context, dynamic error, [StackTrace? trace]) {
    if (!kDebugMode) return;
    debugPrint('[AppError][$context] ${error.runtimeType}: $error');
    if (trace != null) debugPrint('[AppError][$context] StackTrace: $trace');
  }

  // ─── Message mapping ──────────────────────────────────────────────────────

  static String getMessage(dynamic error) {
    if (error is FirebaseAuthException) return _authMessage(error.code);
    if (error is FirebaseException)     return _firebaseMessage(error.code, error.plugin);

    final raw = error.toString().toLowerCase();
    if (raw.contains('network') || raw.contains('socket')) {
      return 'Pas de connexion internet. Vérifiez votre réseau.';
    }
    if (raw.contains('cancel') || raw.contains('annul') || raw.contains('abort')) {
      return 'Opération annulée.';
    }
    if (raw.contains('non connect') || raw.contains('not logged')) {
      return 'Vous devez être connecté pour effectuer cette action.';
    }
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  static String _authMessage(String? code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte avec cet email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'invalid-email':
        return 'Format email invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé.';
      case 'weak-password':
        return 'Mot de passe trop faible (min. 6 caractères).';
      case 'requires-recent-login':
        return 'Veuillez vous reconnecter pour continuer.';
      case 'network-request-failed':
        return 'Pas de connexion internet. Vérifiez votre réseau.';
      case 'operation-not-allowed':
        return 'Opération non autorisée. Contactez le support.';
      case 'account-exists-with-different-credential':
        return 'Un compte existe déjà avec cet email.';
      default:
        return 'Erreur d\'authentification. Veuillez réessayer.';
    }
  }

  static String _firebaseMessage(String? code, String? plugin) {
    // Cross-plugin codes
    switch (code) {
      case 'network-request-failed':
      case 'unavailable':
        return 'Pas de connexion internet. Vérifiez votre réseau.';
      case 'permission-denied':
      case 'unauthorized':
        return 'Accès refusé. Vous n\'avez pas les droits nécessaires.';
      case 'unauthenticated':
        return 'Veuillez vous connecter pour continuer.';
      case 'cancelled':
      case 'aborted':
        return 'Opération annulée. Veuillez réessayer.';
      case 'deadline-exceeded':
        return 'Délai d\'attente dépassé. Vérifiez votre connexion.';
      case 'resource-exhausted':
        return 'Limite de requêtes atteinte. Réessayez plus tard.';
    }

    // Storage-specific
    if (plugin == 'firebase_storage') {
      switch (code) {
        case 'object-not-found':     return 'Fichier introuvable.';
        case 'bucket-not-found':     return 'Erreur de configuration du stockage.';
        case 'quota-exceeded':       return 'Espace de stockage dépassé.';
        case 'retry-limit-exceeded': return 'Délai réseau dépassé. Réessayez.';
        case 'canceled':             return 'Téléchargement annulé.';
        default:                     return 'Erreur lors du téléchargement. Réessayez.';
      }
    }

    // Firestore-specific
    if (plugin == 'cloud_firestore') {
      switch (code) {
        case 'not-found':           return 'Élément introuvable.';
        case 'already-exists':      return 'Cet élément existe déjà.';
        case 'failed-precondition': return 'Opération impossible dans l\'état actuel.';
        default:                    return 'Erreur de base de données. Veuillez réessayer.';
      }
    }

    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  /// Logs [error] to the console and shows a user-friendly error SnackBar.
  static void showError(
    BuildContext context,
    dynamic error, {
    String? logContext,
  }) {
    log(logContext ?? 'ui', error);
    _snackBar(context, getMessage(error), isError: true);
  }

  /// Shows a pre-composed message as a styled SnackBar (no exception needed).
  static void showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    _snackBar(context, message, isError: isError);
  }

  static void _snackBar(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
