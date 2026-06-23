class Validators {
  // ─── EMAIL ─────────────────────────────────────────────────────────────────

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email requis';
    final trimmed = v.trim();
    // Rejects: test@, abc, user@.com, @domain.com, user@domain
    if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(trimmed)) {
      return 'Format invalide (ex: user@gmail.com)';
    }
    if (trimmed.contains('..')) return 'Format invalide (points consécutifs)';
    return null;
  }

  // ─── PASSWORD ──────────────────────────────────────────────────────────────

  /// Full-strength password used during registration.
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis';
    if (v.length < 8) return 'Min. 8 caractères requis';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Au moins 1 majuscule (A–Z) requise';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Au moins 1 minuscule (a–z) requise';
    if (!RegExp(r'\d').hasMatch(v)) return 'Au moins 1 chiffre (0–9) requis';
    if (!RegExp(r'[!@#\$%^&*()\-_=+\[\]{};:,.<>?/\\|~`]').hasMatch(v)) {
      return 'Au moins 1 caractère spécial (!@#\$…) requis';
    }
    return null;
  }

  /// Relaxed check used only on the login screen (don't leak password rules).
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis';
    if (v.length < 6) return 'Min. 6 caractères';
    return null;
  }

  /// Returns 0–5 based on how many strength criteria the password satisfies.
  static int passwordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*()\-_=+\[\]{};:,.<>?/\\|~`]').hasMatch(password)) {
      score++;
    }
    return score;
  }

  // ─── PRICE ─────────────────────────────────────────────────────────────────

  /// Validates a monetary price field (DT).
  /// Accepts comma or dot as decimal separator.
  static String? price(String? v) {
    if (v == null || v.trim().isEmpty) return 'Prix requis';
    final cleaned = v.trim().replaceAll(',', '.');
    final n = double.tryParse(cleaned);
    if (n == null) return 'Entrez un nombre valide (ex: 150 ou 149.99)';
    if (n <= 0)    return 'Le prix doit être supérieur à 0';
    if (n > 999999) return 'Prix trop élevé';
    return null;
  }

  // ─── PHONE ─────────────────────────────────────────────────────────────────

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro de téléphone requis';
    // Strip spaces, dashes, dots — common formatting characters
    final cleaned = v.trim().replaceAll(RegExp(r'[\s\-\.]'), '');
    // Accept international (+213…) or local (0…) formats, 8–15 digits
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleaned)) {
      return 'Numéro invalide (ex: 0555 123 456 ou +213555123456)';
    }
    return null;
  }

  // ─── NAMES ─────────────────────────────────────────────────────────────────

  static String? fullName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nom complet requis';
    final t = v.trim();
    if (t.length < 2) return 'Min. 2 caractères';
    if (t.length > 60) return 'Max. 60 caractères';
    if (RegExp(r'\d').hasMatch(t)) return 'Le nom ne peut pas contenir de chiffres';
    return null;
  }

  static String? commerceName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nom du commerce requis';
    final t = v.trim();
    if (t.length < 2) return 'Min. 2 caractères';
    if (t.length > 80) return 'Max. 80 caractères';
    return null;
  }

  // ─── PROMO FIELDS ──────────────────────────────────────────────────────────

  static String? promoTitle(String? v) {
    if (v == null || v.trim().isEmpty) return 'Titre requis';
    if (v.trim().length < 5) return 'Min. 5 caractères';
    if (v.trim().length > 80) return 'Max. 80 caractères';
    return null;
  }

  static String? promoDescription(String? v) {
    if (v == null || v.trim().isEmpty) return 'Description requise';
    if (v.trim().length < 20) return 'Min. 20 caractères pour une bonne description';
    if (v.trim().length > 500) return 'Max. 500 caractères';
    return null;
  }

  static String? promoDiscount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Réduction requise';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Entrez un nombre entier';
    if (n <= 0) return 'La réduction doit être supérieure à 0 %';
    if (n > 100) return 'La réduction ne peut pas dépasser 100 %';
    return null;
  }

  static String? promoCode(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional field
    final code = v.trim();
    if (code.length < 3) return 'Min. 3 caractères';
    if (code.length > 20) return 'Max. 20 caractères';
    if (code.contains(' ')) return 'Aucun espace autorisé';
    if (!RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(code)) {
      return 'Lettres, chiffres, - et _ uniquement';
    }
    return null;
  }

  static String? maxReservations(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nombre de réservations requis';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Entrez un nombre entier';
    if (n < 1) return 'Doit être au moins 1';
    if (n > 10000) return 'Max. 10 000 réservations';
    return null;
  }

  // ─── BUSINESS REGISTRATION ─────────────────────────────────────────────────

  /// Algerian matricule fiscal: 8–30 alphanumeric chars, slashes and dashes allowed.
  static String? matricule(String? v) {
    if (v == null || v.trim().isEmpty) return 'Matricule fiscal requis';
    final t = v.trim();
    if (t.length < 8) return 'Matricule trop court (min. 8 caractères)';
    if (t.length > 30) return 'Matricule trop long (max. 30 caractères)';
    if (!RegExp(r'^[A-Za-z0-9/\-]+$').hasMatch(t)) {
      return 'Caractères invalides (lettres, chiffres, / et - autorisés)';
    }
    return null;
  }

  // ─── RESERVATION ───────────────────────────────────────────────────────────

  /// Optional free-text message with a reasonable length cap.
  static String? optionalMessage(String? v) {
    if (v == null || v.trim().isEmpty) return null; // truly optional
    if (v.trim().length > 300) return 'Max. 300 caractères';
    return null;
  }

  // ─── PROMO CONDITIONS ──────────────────────────────────────────────────────

  /// Optional free-text conditions — blank is allowed, but cap at 1 000 chars.
  static String? promoConditions(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (v.trim().length > 1000) return 'Max. 1 000 caractères';
    return null;
  }

  // ─── GENERIC ───────────────────────────────────────────────────────────────

  static String? required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ce champ est requis';
    return null;
  }
}
