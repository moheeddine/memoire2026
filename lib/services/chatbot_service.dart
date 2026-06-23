import '../models/promo_model.dart';
import 'promo_service.dart';

// Intent détecté depuis le message utilisateur
enum IntentType {
  greeting,
  searchByCategory,
  bestPromos,
  nearbyPromos,
  help,
  unknown,
}

class _Intent {
  final IntentType type;
  final String? category; // présent si type == searchByCategory

  const _Intent(this.type, {this.category});
}

class ChatbotService {
  // ─── POINT D'ENTRÉE PUBLIC ────────────────────────────────────────────────

  static Future<String> processMessage(String userInput) async {
    final normalized = userInput.toLowerCase().trim();
    final intent = _detectIntent(normalized);
    return _handleIntent(intent);
  }

  // ─── DÉTECTION D'INTENTION ────────────────────────────────────────────────

  static _Intent _detectIntent(String input) {
    // 1. Salutation
    if (_anyOf(input, ['bonjour', 'salut', 'hello', 'hi', 'salam', 'bonsoir'])) {
      return const _Intent(IntentType.greeting);
    }

    // 2. Aide
    if (_anyOf(input, ['aide', 'help', 'comment', 'que sais-tu', 'quoi faire'])) {
      return const _Intent(IntentType.help);
    }

    // 3. Meilleures promos
    if (_anyOf(input, ['meilleur', 'top', 'recommand', 'suggest', 'best', 'max'])) {
      return const _Intent(IntentType.bestPromos);
    }

    // 4. Promos proches
    if (_anyOf(input, ['proche', 'pres', 'autour', 'nearby', 'near', 'km'])) {
      return const _Intent(IntentType.nearbyPromos);
    }

    // 5. Recherche par catégorie
    final cat = _extractCategory(input);
    if (cat != null) {
      return _Intent(IntentType.searchByCategory, category: cat);
    }

    // 6. Recherche générale (toutes les promos)
    if (_anyOf(input, ['promo', 'offre', 'réduction', 'reduction', 'discount', 'deal'])) {
      return const _Intent(IntentType.bestPromos);
    }

    return const _Intent(IntentType.unknown);
  }

  // ─── EXTRACTION DE CATÉGORIE ──────────────────────────────────────────────

  static String? _extractCategory(String input) {
    final categoryKeywords = <String, List<String>>{
      'café':       ['café', 'cafe', 'coffee', 'cappuccino', 'espresso'],
      'resto':      ['resto', 'restaurant', 'manger', 'pizza', 'burger', 'food', 'repas', 'plat'],
      'vetement':   ['vetement', 'vêtement', 'mode', 'habit', 'chemise', 'robe', 'pantalon', 'fringue'],
      'librairie':  ['librairie', 'livre', 'book', 'papier', 'cahier', 'stylo'],
      'reparation': ['reparation', 'réparation', 'réparer', 'garage', 'panne', 'service'],
      'publinet':   ['internet', 'publinet', 'pc', 'cyber', 'wifi', 'ordinateur'],
    };

    for (final entry in categoryKeywords.entries) {
      if (_anyOf(input, entry.value)) return entry.key;
    }
    return null;
  }

  // ─── HANDLERS D'INTENTION ─────────────────────────────────────────────────

  static Future<String> _handleIntent(_Intent intent) async {
    switch (intent.type) {
      case IntentType.greeting:
        return _greetingResponse();

      case IntentType.help:
        return _helpResponse();

      case IntentType.searchByCategory:
        return _searchByCategoryResponse(intent.category!);

      case IntentType.bestPromos:
        return _bestPromosResponse();

      case IntentType.nearbyPromos:
        return _nearbyPromosResponse();

      case IntentType.unknown:
        return _unknownResponse();
    }
  }

  // ─── RÉPONSES STATIQUES ───────────────────────────────────────────────────

  static String _greetingResponse() {
    return 'Bonjour ! Je suis CityBot 🤖\n\n'
        'Je peux vous aider à :\n'
        '• Trouver des promos par catégorie\n'
        '• Suggérer les meilleures offres\n'
        '• Localiser des commerces\n\n'
        'Que cherchez-vous aujourd\'hui ?';
  }

  static String _helpResponse() {
    return '📖 Voici ce que je sais faire :\n\n'
        '☕ "promos café" → cafés en promo\n'
        '🍕 "promos resto" → restaurants\n'
        '👗 "promos vêtement" → mode\n'
        '📚 "promos librairie" → livres\n'
        '🔧 "promos réparation" → services\n'
        '💻 "promos publinet" → cybercafés\n\n'
        '🏆 "meilleures promos" → top offres\n'
        '📍 "promos proches" → autour de vous\n\n'
        'Essayez !';
  }

  static String _unknownResponse() {
    return 'Je n\'ai pas bien compris 🤔\n\n'
        'Essayez par exemple :\n'
        '• "promos café"\n'
        '• "meilleures offres"\n'
        '• "aide"\n\n'
        'Tapez "aide" pour voir toutes les commandes.';
  }

  // ─── RÉPONSES DYNAMIQUES (avec PromoService) ──────────────────────────────

  static Future<String> _searchByCategoryResponse(String category) async {
    try {
      final promos = await PromoService.getApprovedWithBusinessData(limit: 5);
      final filtered = promos
          .where((p) => p.category?.toLowerCase() == category.toLowerCase())
          .take(3)
          .toList();

      if (filtered.isEmpty) {
        return '😔 Aucune promo "$category" disponible en ce moment.\n\n'
            'Revenez plus tard ou essayez une autre catégorie.';
      }

      return _formatPromoList(
        filtered,
        header: 'Promos "$category" disponibles 🎉',
      );
    } catch (_) {
      return '⚠️ Erreur lors de la recherche. Réessayez.';
    }
  }

  static Future<String> _bestPromosResponse() async {
    try {
      final promos = await PromoService.getApprovedWithBusinessData(limit: 20);
      if (promos.isEmpty) {
        return '😔 Aucune promotion disponible en ce moment.';
      }

      // Trier par discount DESC
      final sorted = List<PromoModel>.from(promos)
        ..sort((a, b) => b.discount.compareTo(a.discount));

      return _formatPromoList(
        sorted.take(3).toList(),
        header: '🏆 Top promos du moment',
      );
    } catch (_) {
      return '⚠️ Erreur lors de la recherche. Réessayez.';
    }
  }

  static Future<String> _nearbyPromosResponse() async {
    try {
      final promos = await PromoService.getApprovedWithBusinessData(limit: 10);
      if (promos.isEmpty) {
        return '😔 Aucune promotion disponible en ce moment.';
      }

      // Retourner les promos qui ont une position (enrichies)
      final withPos = promos.where((p) => p.lat != null).take(3).toList();

      if (withPos.isEmpty) {
        return '📍 Activez votre localisation pour voir les promos proches.\n\n'
            'En attendant, voici quelques offres disponibles :\n'
            '${_buildPromoLines(promos.take(3).toList())}';
      }

      return _formatPromoList(withPos, header: '📍 Promos à proximité');
    } catch (_) {
      return '⚠️ Erreur lors de la recherche. Réessayez.';
    }
  }

  // ─── FORMATEURS ───────────────────────────────────────────────────────────

  static String _formatPromoList(
    List<PromoModel> promos, {
    required String header,
  }) {
    final buffer = StringBuffer('$header\n\n');
    buffer.write(_buildPromoLines(promos));
    buffer.write('\n💡 Tapez "aide" pour plus d\'options.');
    return buffer.toString();
  }

  static String _buildPromoLines(List<PromoModel> promos) {
    final buffer = StringBuffer();
    for (final p in promos) {
      buffer.write('🔖 ${p.title} — -${p.discount}%\n');
      if (p.businessName != null) {
        buffer.write('   📍 ${p.businessName}\n');
      }
      if (p.code.isNotEmpty) {
        buffer.write('   🎫 Code : ${p.code}\n');
      }
      buffer.write('\n');
    }
    return buffer.toString().trimRight();
  }

  // ─── UTILITAIRE ───────────────────────────────────────────────────────────

  static bool _anyOf(String input, List<String> keywords) {
    return keywords.any((k) => input.contains(k));
  }
}
