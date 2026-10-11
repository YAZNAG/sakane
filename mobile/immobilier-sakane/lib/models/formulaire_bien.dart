/// Ce que le serveur dit avant que le formulaire d'un bien ne s'affiche :
/// les types de biens et, pour chacun, les caractéristiques qui lui sont
/// propres ; les équipements, rangés par famille et rattachés aux types
/// de biens auxquels ils s'appliquent.
///
/// Un appartement se décrit par ses salons et ses balcons, un terrain par
/// son titre et sa viabilisation : poser les mêmes questions à tous les
/// types laissait la moitié des champs vides et l'autre manquante.
library;

/// Une caractéristique à demander : son type dit comment la saisir.
class ChampCaracteristique {
  final String cle;
  final String libelle;

  /// « entier », « decimal », « texte », « booleen » ou « choix ».
  final String type;

  /// « m² », « MAD / mois »... affichée après la valeur.
  final String? unite;

  /// Les valeurs possibles, pour un champ « choix ».
  final List<String> options;
  final String? icone;

  const ChampCaracteristique({
    required this.cle,
    required this.libelle,
    required this.type,
    this.unite,
    this.options = const [],
    this.icone,
  });

  factory ChampCaracteristique.fromJson(Map<String, dynamic> json) =>
      ChampCaracteristique(
        cle: json['cle']?.toString() ?? '',
        libelle: json['libelle']?.toString() ?? '',
        type: json['type']?.toString() ?? 'texte',
        unite: json['unite']?.toString(),
        options: ((json['options'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        icone: json['icone']?.toString(),
      );

  bool get estNombre => type == 'entier' || type == 'decimal';
}

/// Un type de bien et les caractéristiques qu'on lui demande.
class TypeBienFormulaire {
  final String code;
  final String nom;

  /// Les champs du bien lui-meme qui ont un sens pour ce type :
  /// « chambres », « salles_bain », « etage », « etages »,
  /// « date_construction ». Un terrain n'en garde aucun.
  final List<String> communs;
  final List<ChampCaracteristique> caracteristiques;

  const TypeBienFormulaire({
    required this.code,
    required this.nom,
    required this.caracteristiques,
    this.communs = const [],
  });

  factory TypeBienFormulaire.fromJson(Map<String, dynamic> json) =>
      TypeBienFormulaire(
        code: json['code']?.toString() ?? '',
        nom: json['nom']?.toString() ?? '',
        communs: ((json['communs'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        caracteristiques: ((json['caracteristiques'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ChampCaracteristique.fromJson)
            .toList(),
      );
}

/// Une famille d'équipements : « Intérieur », « Sécurité »...
class GroupeEquipements {
  final String code;
  final String libelle;
  final String? icone;
  final int ordre;

  const GroupeEquipements({
    required this.code,
    required this.libelle,
    this.icone,
    this.ordre = 0,
  });

  factory GroupeEquipements.fromJson(Map<String, dynamic> json) =>
      GroupeEquipements(
        code: json['code']?.toString() ?? '',
        libelle: json['libelle']?.toString() ?? '',
        icone: json['icone']?.toString(),
        ordre: (json['ordre'] as num?)?.toInt() ?? 0,
      );
}

/// Un équipement du catalogue, avec les types de biens qu'il concerne.
class EquipementFormulaire {
  final int id;
  final String nom;
  final String? icone;
  final String groupe;

  /// Vide : l'équipement s'applique à tous les types de biens.
  final List<String> categories;

  const EquipementFormulaire({
    required this.id,
    required this.nom,
    required this.groupe,
    this.icone,
    this.categories = const [],
  });

  factory EquipementFormulaire.fromJson(Map<String, dynamic> json) =>
      EquipementFormulaire(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nom: json['nom']?.toString() ?? '',
        icone: json['icone']?.toString(),
        groupe: json['groupe']?.toString() ?? 'services',
        categories: ((json['categories'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  /// Un équipement sans type s'applique partout.
  bool concerne(String? categorie) =>
      categories.isEmpty || categorie == null || categories.contains(categorie);
}

class FormulaireBien {
  final List<TypeBienFormulaire> types;
  final List<GroupeEquipements> groupes;
  final List<EquipementFormulaire> equipements;

  const FormulaireBien({
    required this.types,
    required this.groupes,
    required this.equipements,
  });

  factory FormulaireBien.fromJson(Map<String, dynamic> reponse) {
    final data = (reponse['data'] as Map<String, dynamic>?) ?? reponse;
    return FormulaireBien(
      types: ((data['categories'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TypeBienFormulaire.fromJson)
          .toList(),
      groupes: ((data['groupes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GroupeEquipements.fromJson)
          .toList(),
      equipements: ((data['equipements'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EquipementFormulaire.fromJson)
          .toList(),
    );
  }

  /// Les caractéristiques d'un type ; vide si le type est inconnu.
  List<ChampCaracteristique> champsPour(String? codeType) {
    if (codeType == null) return const [];
    for (final t in types) {
      if (t.code == codeType) return t.caracteristiques;
    }
    return const [];
  }

  /// Les champs communs que ce type garde. Un type inconnu les garde
  /// tous : mieux vaut un champ de trop qu'un champ manquant.
  static const List<String> tousLesCommuns = [
    'chambres',
    'salles_bain',
    'etage',
    'etages',
    'date_construction',
  ];

  List<String> communsPour(String? codeType) {
    if (codeType == null) return tousLesCommuns;
    for (final t in types) {
      if (t.code == codeType) return t.communs;
    }
    return tousLesCommuns;
  }

  /// Les équipements qui concernent ce type, rangés par famille et dans
  /// l'ordre des familles.
  Map<GroupeEquipements, List<EquipementFormulaire>> parGroupePour(
      String? codeType) {
    final sortie = <GroupeEquipements, List<EquipementFormulaire>>{};
    final ordonnes = [...groupes]..sort((a, b) => a.ordre.compareTo(b.ordre));

    for (final groupe in ordonnes) {
      final liste = equipements
          .where((e) => e.groupe == groupe.code && e.concerne(codeType))
          .toList();
      if (liste.isNotEmpty) sortie[groupe] = liste;
    }

    // Ce qui ne rejoint aucune famille connue ne disparaît pas.
    final connus = ordonnes.map((g) => g.code).toSet();
    final orphelins = equipements
        .where((e) => !connus.contains(e.groupe) && e.concerne(codeType))
        .toList();
    if (orphelins.isNotEmpty) {
      sortie[const GroupeEquipements(
          code: 'autres', libelle: 'Autres équipements', ordre: 99)] = orphelins;
    }

    return sortie;
  }
}
