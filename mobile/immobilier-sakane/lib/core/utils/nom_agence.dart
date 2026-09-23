import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';

/// Le nom de l'agence, retenu au passage.
///
/// Seul le résumé de l'accueil le donne (`GET /api/dashboard/resume`).
/// Les autres écrans — les dossiers, par exemple — veulent l'écrire en
/// sous-titre sans rappeler le serveur pour un seul mot : il est donc
/// gardé sur le téléphone dès la première lecture, et relu tel quel.
///
/// Son absence n'est jamais un échec : le sous-titre se passe alors du
/// nom de l'agence.
class NomAgence {
  static const String _cle = 'nom_agence';

  static SharedPrefService? get _prefs {
    try {
      return Dependencies.get<SharedPrefService>();
    } catch (_) {
      return null;
    }
  }

  /// Retient le nom lu dans le résumé de l'accueil. Un nom vide n'efface
  /// pas celui déjà connu : une réponse partielle ne fait rien perdre.
  static void retenir(String? nom) {
    final propre = nom?.trim() ?? '';
    if (propre.isEmpty) return;
    try {
      _prefs?.putValue(_cle, propre);
    } catch (_) {}
  }

  /// Le nom retenu, ou une chaîne vide s'il n'a jamais été lu.
  static String get connu {
    try {
      return _prefs?.getValue<String>(_cle, '') ?? '';
    } catch (_) {
      return '';
    }
  }
}
