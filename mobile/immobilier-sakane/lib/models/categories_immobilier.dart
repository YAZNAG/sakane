// Les trois familles de biens et leurs compteurs, tels que le serveur
// les rend : `GET /api/dashboard/immobilier/categories`.
//
// Rien n'est compté ici : le serveur seul sait combien de biens sont
// disponibles, loués ou sans mandat. Chaque champ tolère son absence —
// une réponse partielle laisse l'écran utilisable, avec les libellés
// que l'application connaît déjà.

/// Un état à l'intérieur d'une famille : « 24 disponibles ».
class EtatCategorie {
  final String code;
  final String libelle;
  final int nombre;

  /// La teinte de la pastille, nommée par le serveur : vert, bleu,
  /// orange, rouge. Inconnue : la pastille reste grise.
  final String ton;

  const EtatCategorie({
    this.code = '',
    this.libelle = '',
    this.nombre = 0,
    this.ton = '',
  });

  factory EtatCategorie.fromJson(Map<String, dynamic> json) {
    return EtatCategorie(
      code: _texte(json['code']),
      libelle: _texte(json['libelle']),
      nombre: _entier(json['nombre']) ?? 0,
      ton: _texte(json['ton']),
    );
  }
}

/// Une famille de biens : location vacances, longue durée ou vente.
class CategorieImmobilier {
  /// `rent-short`, `rent-long` ou `selle` : le code de type de
  /// transaction déjà utilisé par le reste de l'application.
  final String code;
  final String libelle;
  final String detail;

  /// Le nom de l'icône (`key`, `document`, `tag`…) et de la teinte
  /// (`vert`, `violet`, `orange`) : l'écran les traduit en dessin et en
  /// couleur, et garde les siens s'il ne les connaît pas.
  final String icone;
  final String couleur;

  final int total;
  final List<EtatCategorie> etats;

  const CategorieImmobilier({
    this.code = '',
    this.libelle = '',
    this.detail = '',
    this.icone = '',
    this.couleur = '',
    this.total = 0,
    this.etats = const [],
  });

  factory CategorieImmobilier.fromJson(Map<String, dynamic> json) {
    final etats = json['etats'];
    return CategorieImmobilier(
      code: _texte(json['code']),
      libelle: _texte(json['libelle']),
      detail: _texte(json['detail']),
      icone: _texte(json['icone']),
      couleur: _texte(json['couleur']),
      total: _entier(json['total']) ?? 0,
      etats: etats is List
          ? etats
              .whereType<Map>()
              .map((e) => EtatCategorie.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// Le tableau de bord des catégories : le total, les biens désactivés et
/// les trois familles.
class CategoriesImmobilier {
  final int total;
  final int desactives;
  final List<CategorieImmobilier> categories;

  const CategoriesImmobilier({
    this.total = 0,
    this.desactives = 0,
    this.categories = const [],
  });

  /// La famille d'un code, ou nulle si le serveur ne l'a pas rendue.
  CategorieImmobilier? parCode(String code) {
    for (final c in categories) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// Lit `{data: {...}}` ou directement le contenu.
  static CategoriesImmobilier depuis(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] is Map) corps = corps['data'];
    if (corps is! Map) return const CategoriesImmobilier();
    final json = Map<String, dynamic>.from(corps);

    final categories = json['categories'];
    return CategoriesImmobilier(
      total: _entier(json['total']) ?? 0,
      desactives: _entier(json['desactives']) ?? 0,
      categories: categories is List
          ? categories
              .whereType<Map>()
              .map((c) =>
                  CategorieImmobilier.fromJson(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
    );
  }
}

String _texte(dynamic valeur, {String defaut = ''}) {
  if (valeur == null) return defaut;
  final texte = valeur.toString().trim();
  return texte.isEmpty ? defaut : texte;
}

int? _entier(dynamic valeur) {
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.round();
  if (valeur is String) return int.tryParse(valeur.trim());
  return null;
}
