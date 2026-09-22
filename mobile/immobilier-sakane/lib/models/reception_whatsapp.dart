/// Groupe des types sans groupe connu.
const String groupeReceptionAutres = 'autres';

/// Un groupe de types de messages (réservations, nettoyage…).
class GroupeReceptionWhatsapp {
  final String code;
  final String libelle;

  const GroupeReceptionWhatsapp({required this.code, required this.libelle});

  factory GroupeReceptionWhatsapp.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? '').toString().trim();
    final libelle = (json['libelle'] ?? '').toString().trim();
    return GroupeReceptionWhatsapp(
      code: code,
      libelle: libelle.isEmpty ? code : libelle,
    );
  }
}

/// Un type de message WhatsApp que l'utilisateur peut recevoir ou couper.
/// Libelle et description viennent du serveur.
class TypeReceptionWhatsapp {
  final String code;
  final String libelle;
  final String description;
  final bool actif;

  /// Code du groupe ([groupeReceptionAutres] s'il manque).
  final String groupe;
  final String? groupeLibelle;

  const TypeReceptionWhatsapp({
    required this.code,
    required this.libelle,
    this.description = '',
    this.actif = true,
    this.groupe = groupeReceptionAutres,
    this.groupeLibelle,
  });

  factory TypeReceptionWhatsapp.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? '').toString();
    final groupe = (json['groupe'] ?? '').toString().trim();
    final groupeLibelle = (json['groupeLibelle'] ?? '').toString().trim();
    return TypeReceptionWhatsapp(
      code: code,
      libelle: (json['libelle'] ?? code).toString(),
      description: (json['description'] ?? '').toString(),
      actif: json['actif'] != false,
      groupe: groupe.isEmpty ? groupeReceptionAutres : groupe,
      groupeLibelle: groupeLibelle.isEmpty ? null : groupeLibelle,
    );
  }

  TypeReceptionWhatsapp copyWith({bool? actif}) {
    return TypeReceptionWhatsapp(
      code: code,
      libelle: libelle,
      description: description,
      actif: actif ?? this.actif,
      groupe: groupe,
      groupeLibelle: groupeLibelle,
    );
  }
}

/// Une section de la page : un groupe et ses types, dans l'ordre du serveur.
class SectionReceptionWhatsapp {
  final String code;
  final String libelle;
  final List<TypeReceptionWhatsapp> types;

  const SectionReceptionWhatsapp({
    required this.code,
    required this.libelle,
    required this.types,
  });

  int get nombreRecus => types.where((t) => t.actif).length;
  bool get toutRecu => types.every((t) => t.actif);
}

/// Ce qu'un utilisateur recoit comme notifications WhatsApp.
/// Les messages envoyes aux clients ne sont pas concernes.
class ReceptionWhatsapp {
  final int? managerId;
  final String? nom;
  final String? telephone;
  final bool actif;
  final List<GroupeReceptionWhatsapp> groupes;
  final List<TypeReceptionWhatsapp> types;

  const ReceptionWhatsapp({
    this.managerId,
    this.nom,
    this.telephone,
    this.actif = true,
    this.groupes = const [],
    this.types = const [],
  });

  factory ReceptionWhatsapp.fromJson(Map<String, dynamic> json) {
    final id = json['managerId'];
    return ReceptionWhatsapp(
      managerId: id is int ? id : int.tryParse('${id ?? ''}'),
      nom: json['nom']?.toString(),
      telephone: json['telephone']?.toString(),
      actif: json['actif'] != false,
      groupes: (json['groupes'] is List ? json['groupes'] as List : const [])
          .whereType<Map>()
          .map((e) => GroupeReceptionWhatsapp.fromJson(Map<String, dynamic>.from(e)))
          .where((g) => g.code.isNotEmpty)
          .toList(),
      types: (json['types'] is List ? json['types'] as List : const [])
          .whereType<Map>()
          .map((e) => TypeReceptionWhatsapp.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.code.isNotEmpty)
          .toList(),
    );
  }

  ReceptionWhatsapp copyWith({
    bool? actif,
    List<TypeReceptionWhatsapp>? types,
  }) {
    return ReceptionWhatsapp(
      managerId: managerId,
      nom: nom,
      telephone: telephone,
      actif: actif ?? this.actif,
      groupes: groupes,
      types: types ?? this.types,
    );
  }

  /// Types regroupés par groupe : d'abord l'ordre des [groupes] du serveur,
  /// puis les groupes rencontrés dans les types, « Autres » en dernier.
  List<SectionReceptionWhatsapp> get sections {
    final parGroupe = <String, List<TypeReceptionWhatsapp>>{};
    for (final t in types) {
      parGroupe.putIfAbsent(t.groupe, () => []).add(t);
    }
    final libelles = <String, String>{
      for (final g in groupes) g.code: g.libelle,
    };
    for (final t in types) {
      if (t.groupeLibelle != null) libelles.putIfAbsent(t.groupe, () => t.groupeLibelle!);
    }
    final ordre = <String>[
      ...groupes.map((g) => g.code).where(parGroupe.containsKey),
      ...parGroupe.keys.where(
        (c) => c != groupeReceptionAutres && !groupes.any((g) => g.code == c),
      ),
    ];
    if (parGroupe.containsKey(groupeReceptionAutres) &&
        !ordre.contains(groupeReceptionAutres)) {
      ordre.add(groupeReceptionAutres);
    }
    return [
      for (final code in ordre)
        SectionReceptionWhatsapp(
          code: code,
          libelle: libelles[code] ??
              (code == groupeReceptionAutres ? 'Autres' : code),
          types: parGroupe[code]!,
        ),
    ];
  }

  bool get sansNumero => (telephone ?? '').trim().isEmpty;

  /// Codes des types coupes : c'est la liste complete qu'attend le serveur.
  List<String> get typesCoupes =>
      types.where((t) => !t.actif).map((t) => t.code).toList();

  int get nombreRecus => types.where((t) => t.actif).length;

  /// Resume court pour une liste : tout, rien, ou le nombre de types recus.
  String get resume {
    if (!actif || (types.isNotEmpty && nombreRecus == 0)) return 'Rien';
    if (nombreRecus == types.length) return 'Tout reçu';
    return '$nombreRecus type${nombreRecus > 1 ? 's' : ''} sur ${types.length}';
  }
}
