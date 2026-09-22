/// Droits et permissions : ce que chaque rôle, puis chaque utilisateur,
/// a le droit de faire.
///
/// La liste des modules, des sous-modules et des droits vient entièrement
/// du serveur : l'application ne connaît aucun code par avance. Un droit
/// ajouté plus tard côté serveur apparaît donc tout seul dans l'écran,
/// au besoin dans un module « Autres ».
///
/// Tous les modèles tolèrent les champs absents : un serveur plus ancien
/// (modules sans sous-modules, sans icône, sans utilisateurs) reste lisible.
library;

String _texte(dynamic valeur) => valeur == null ? '' : valeur.toString().trim();

int _entier(dynamic valeur) {
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.toInt();
  return int.tryParse(_texte(valeur)) ?? 0;
}

bool _booleen(dynamic valeur, {bool defaut = false}) {
  if (valeur is bool) return valeur;
  if (valeur is num) return valeur != 0;
  final t = _texte(valeur).toLowerCase();
  if (t.isEmpty) return defaut;
  return t == '1' || t == 'true' || t == 'oui' || t == 'yes';
}

List<Map<String, dynamic>> _listeObjets(dynamic valeur) {
  if (valeur is! List) return const [];
  return valeur
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<String> _listeTextes(dynamic valeur) {
  if (valeur is! List) return const [];
  return valeur.map(_texte).where((c) => c.isNotEmpty).toList();
}

/// Le corps utile d'une réponse, qu'il soit à la racine ou sous « data ».
Map<String, dynamic>? _corps(dynamic data, String cleAttendue) {
  dynamic corps = data;
  if (corps is Map && corps[cleAttendue] == null && corps['data'] is Map) {
    corps = corps['data'];
  }
  if (corps is! Map) return null;
  return Map<String, dynamic>.from(corps);
}

/// Texte comparable pour la recherche : minuscules, sans accents.
String normaliserRecherche(String texte) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
    '’': "'",
  };
  final buffer = StringBuffer();
  for (final rune in texte.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    buffer.write(accents[c] ?? c);
  }
  return buffer.toString().trim();
}

/// La nature d'un droit, pour la pastille colorée de l'écran.
enum ActionDroit {
  voir('Voir'),
  ajouter('Ajouter'),
  modifier('Modifier'),
  supprimer('Supprimer'),
  action('Action');

  final String libelle;
  const ActionDroit(this.libelle);

  static ActionDroit depuis(dynamic valeur) {
    switch (normaliserRecherche(_texte(valeur))) {
      case 'voir':
      case 'view':
      case 'lire':
        return ActionDroit.voir;
      case 'ajouter':
      case 'create':
      case 'creer':
        return ActionDroit.ajouter;
      case 'modifier':
      case 'update':
      case 'edit':
        return ActionDroit.modifier;
      case 'supprimer':
      case 'delete':
        return ActionDroit.supprimer;
      default:
        return ActionDroit.action;
    }
  }
}

/// Un droit unitaire, tel que le serveur le nomme.
class PermissionDroit {
  final String code;
  final String libelle;
  final ActionDroit action;

  const PermissionDroit({
    required this.code,
    required this.libelle,
    this.action = ActionDroit.action,
  });

  factory PermissionDroit.fromJson(Map<String, dynamic> json) {
    final code = _texte(json['code']);
    final libelle = _texte(json['libelle']);
    return PermissionDroit(
      code: code,
      // Un droit sans libellé reste lisible : on affiche son code.
      libelle: libelle.isEmpty ? code : libelle,
      action: ActionDroit.depuis(json['action']),
    );
  }

  /// Vrai si le droit répond à une recherche déjà normalisée.
  bool correspond(String requete) =>
      requete.isEmpty ||
      normaliserRecherche(libelle).contains(requete) ||
      code.toLowerCase().contains(requete);
}

/// Un groupe de droits à l'intérieur d'un module (ex. « Biens »).
class SousModulePermissions {
  final String code;
  final String libelle;
  final List<PermissionDroit> permissions;

  const SousModulePermissions({
    required this.code,
    required this.libelle,
    this.permissions = const [],
  });

  factory SousModulePermissions.fromJson(Map<String, dynamic> json) {
    final code = _texte(json['code']);
    final libelle = _texte(json['libelle']);
    return SousModulePermissions(
      code: code.isEmpty ? libelle : code,
      libelle: libelle.isEmpty ? code : libelle,
      permissions: _droits(json['permissions']),
    );
  }

  List<String> get codes => permissions.map((p) => p.code).toList();
}

List<PermissionDroit> _droits(dynamic liste) => _listeObjets(liste)
    .map(PermissionDroit.fromJson)
    .where((p) => p.code.isNotEmpty)
    .toList();

/// Un module de l'application, ses sous-modules et ses droits.
class ModulePermissions {
  final String code;
  final String libelle;

  /// Nom d'icône donné par le serveur (ex. « building ») ; peut être vide.
  final String icone;
  final List<SousModulePermissions> sousModules;

  /// Tous les droits du module, à plat, dans l'ordre d'affichage.
  final List<PermissionDroit> permissions;

  const ModulePermissions({
    required this.code,
    required this.libelle,
    this.icone = '',
    this.sousModules = const [],
    this.permissions = const [],
  });

  factory ModulePermissions.fromJson(Map<String, dynamic> json) {
    final code0 = _texte(json['code']);
    final libelle0 = _texte(json['libelle']);
    final code = code0.isEmpty ? libelle0 : code0;
    final libelle = libelle0.isEmpty ? code0 : libelle0;

    var sousModules = _listeObjets(json['sousModules'] ?? json['sous_modules'])
        .map(SousModulePermissions.fromJson)
        .where((s) => s.permissions.isNotEmpty)
        .toList();
    var plat = _droits(json['permissions']);

    // Ancien format : pas de sous-modules, un seul groupe avec la liste plate.
    if (sousModules.isEmpty && plat.isNotEmpty) {
      sousModules = [
        SousModulePermissions(code: code, libelle: libelle, permissions: plat),
      ];
    }
    // Liste plate absente : on la reconstitue depuis les sous-modules.
    if (plat.isEmpty) {
      plat = sousModules.expand((s) => s.permissions).toList();
    }

    return ModulePermissions(
      code: code,
      libelle: libelle,
      icone: _texte(json['icone'] ?? json['icon']),
      sousModules: sousModules,
      permissions: plat,
    );
  }

  /// Les codes des droits du module, dans l'ordre d'affichage.
  List<String> get codes => permissions.map((p) => p.code).toList();

  /// Vrai si un seul sous-module porte le nom du module : on n'affiche
  /// alors pas d'en-tête de sous-module.
  bool get sansSousModules =>
      sousModules.length == 1 &&
      (sousModules.first.code == code ||
          sousModules.first.libelle == libelle);
}

/// Un rôle et les droits qui lui sont attribués aujourd'hui.
class RolePermissions {
  final String nom;
  final String libelle;
  final int utilisateurs;

  /// Faux pour « admin » : le serveur refuse toute modification.
  final bool modifiable;
  final Set<String> permissions;

  const RolePermissions({
    required this.nom,
    required this.libelle,
    this.utilisateurs = 0,
    this.modifiable = true,
    this.permissions = const {},
  });

  factory RolePermissions.fromJson(Map<String, dynamic> json) {
    final nom = _texte(json['nom']);
    final libelle = _texte(json['libelle']);
    return RolePermissions(
      nom: nom,
      libelle: libelle.isEmpty ? nom : libelle,
      utilisateurs: _entier(json['utilisateurs']),
      modifiable: _booleen(json['modifiable'], defaut: true),
      permissions: _listeTextes(json['permissions']).toSet(),
    );
  }

  /// Le rôle administrateur garde tous les droits, quoi qu'il arrive.
  bool get estAdministrateur => nom.toLowerCase() == 'admin';

  /// Vrai si le rôle peut être modifié dans l'écran.
  bool get modifiableIci => modifiable && !estAdministrateur;

  /// « 3 utilisateurs », « 1 utilisateur », « Aucun utilisateur ».
  String get utilisateursLisible {
    if (utilisateurs <= 0) return 'Aucun utilisateur';
    return '$utilisateurs utilisateur${utilisateurs > 1 ? 's' : ''}';
  }

  RolePermissions copyWith({Set<String>? permissions}) => RolePermissions(
        nom: nom,
        libelle: libelle,
        utilisateurs: utilisateurs,
        modifiable: modifiable,
        permissions: permissions ?? this.permissions,
      );
}

/// Un utilisateur dans la liste « Par utilisateur ».
class UtilisateurPermissions {
  final int id;
  final String nom;
  final List<String> roles;
  final List<String> rolesLibelles;
  final bool admin;
  final bool modifiable;

  /// Nombre de droits accordés en plus du rôle.
  final int accordes;

  /// Nombre de droits retirés malgré le rôle.
  final int retires;
  final bool personnalise;

  const UtilisateurPermissions({
    required this.id,
    required this.nom,
    this.roles = const [],
    this.rolesLibelles = const [],
    this.admin = false,
    this.modifiable = true,
    this.accordes = 0,
    this.retires = 0,
    this.personnalise = false,
  });

  factory UtilisateurPermissions.fromJson(Map<String, dynamic> json) {
    final id = _entier(json['id']);
    final roles = _listeTextes(json['roles']);
    final libelles = _listeTextes(json['rolesLibelles']);
    final admin = _booleen(json['admin']) || roles.contains('admin');
    final accordes = _compte(json['accordes'], json['listeAccordes']);
    final retires = _compte(json['retires'], json['listeRetires']);
    final nom = _texte(json['nom']);
    return UtilisateurPermissions(
      id: id,
      nom: nom.isEmpty ? 'Utilisateur #$id' : nom,
      roles: roles,
      rolesLibelles: libelles.isEmpty ? roles : libelles,
      admin: admin,
      modifiable: _booleen(json['modifiable'], defaut: !admin),
      accordes: accordes,
      retires: retires,
      personnalise: _booleen(json['personnalise'],
          defaut: !admin && accordes + retires > 0),
    );
  }

  /// « accordes » est un nombre dans la liste, parfois une liste ailleurs.
  static int _compte(dynamic valeur, dynamic liste) {
    if (valeur is List) return valeur.length;
    if (valeur != null) return _entier(valeur);
    if (liste is List) return liste.length;
    return 0;
  }

  /// Un administrateur garde tous les droits : rien ne se règle ici.
  bool get verrouille => admin || !modifiable;

  /// « Commercial, Comptable » ou « Aucun rôle ».
  String get rolesLisibles =>
      rolesLibelles.isEmpty ? 'Aucun rôle' : rolesLibelles.join(', ');

  /// Les initiales pour l'avatar.
  String get initiales {
    final mots = nom.split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
    if (mots.isEmpty) return '?';
    final premiere = mots.first.characters0;
    if (mots.length == 1) return premiere;
    return '$premiere${mots.last.characters0}';
  }

  UtilisateurPermissions copyWith({
    int? accordes,
    int? retires,
    bool? personnalise,
  }) =>
      UtilisateurPermissions(
        id: id,
        nom: nom,
        roles: roles,
        rolesLibelles: rolesLibelles,
        admin: admin,
        modifiable: modifiable,
        accordes: accordes ?? this.accordes,
        retires: retires ?? this.retires,
        personnalise: personnalise ?? this.personnalise,
      );
}

extension on String {
  String get characters0 => isEmpty ? '' : substring(0, 1).toUpperCase();
}

/// L'état d'un droit pour un utilisateur donné.
enum EtatDroitUtilisateur {
  /// Hérité du rôle : l'utilisateur l'a si son rôle le donne.
  role,

  /// Accordé en plus, quel que soit le rôle.
  accorde,

  /// Retiré, quel que soit le rôle.
  retire,
}

/// La réponse de « GET /permissions/utilisateurs/{id} ».
class DetailUtilisateurPermissions {
  final UtilisateurPermissions utilisateur;

  /// Les droits que donnent ses rôles.
  final Set<String> parRole;
  final Set<String> listeAccordes;
  final Set<String> listeRetires;

  /// Les droits effectifs calculés par le serveur.
  final Set<String> effectifs;

  const DetailUtilisateurPermissions({
    required this.utilisateur,
    this.parRole = const {},
    this.listeAccordes = const {},
    this.listeRetires = const {},
    this.effectifs = const {},
  });

  factory DetailUtilisateurPermissions.fromJson(dynamic data,
      {UtilisateurPermissions? repli}) {
    final json = _corps(data, 'id');
    if (json == null) {
      return DetailUtilisateurPermissions(
          utilisateur: repli ?? const UtilisateurPermissions(id: 0, nom: ''));
    }
    // Le résumé du serveur peut manquer de champs : on complète au besoin.
    final base = Map<String, dynamic>.from(json);
    if (repli != null) {
      base['id'] ??= repli.id;
      base['nom'] ??= repli.nom;
      base['roles'] ??= repli.roles;
      base['rolesLibelles'] ??= repli.rolesLibelles;
      base['admin'] ??= repli.admin;
    }
    final accordes = _listeTextes(json['listeAccordes']).toSet();
    // Un droit n'est jamais à la fois accordé et retiré.
    final retires = _listeTextes(json['listeRetires'])
        .where((c) => !accordes.contains(c))
        .toSet();
    base['accordes'] ??= accordes.length;
    base['retires'] ??= retires.length;
    return DetailUtilisateurPermissions(
      utilisateur: UtilisateurPermissions.fromJson(base),
      parRole: _listeTextes(json['parRole']).toSet(),
      listeAccordes: accordes,
      listeRetires: retires,
      effectifs: _listeTextes(json['effectifs']).toSet(),
    );
  }
}

/// La réponse complète de « GET /permissions ».
class DroitsEtPermissions {
  final List<ModulePermissions> modules;
  final List<RolePermissions> roles;
  final List<UtilisateurPermissions> utilisateurs;

  /// Nombre total de droits annoncé par le serveur (0 si absent).
  final int totalDroits;

  const DroitsEtPermissions({
    this.modules = const [],
    this.roles = const [],
    this.utilisateurs = const [],
    this.totalDroits = 0,
  });

  factory DroitsEtPermissions.fromJson(dynamic data) {
    final json = _corps(data, 'modules');
    if (json == null) return const DroitsEtPermissions();
    return DroitsEtPermissions(
      modules: _listeObjets(json['modules'])
          .map(ModulePermissions.fromJson)
          .where((m) => m.permissions.isNotEmpty)
          .toList(),
      roles: _listeObjets(json['roles'])
          .map(RolePermissions.fromJson)
          .where((r) => r.nom.isNotEmpty)
          .toList(),
      utilisateurs: _listeObjets(json['utilisateurs'])
          .map(UtilisateurPermissions.fromJson)
          .where((u) => u.id > 0)
          .toList(),
      totalDroits: _entier(json['totalDroits']),
    );
  }

  /// Tous les codes connus du serveur : sert à ignorer un droit obsolète
  /// resté attaché à un rôle.
  Set<String> get codesConnus => modules.expand((m) => m.codes).toSet();

  /// Le nombre total de droits proposés à l'écran.
  int get nombreDroits => modules.fold(0, (t, m) => t + m.permissions.length);

  /// Remplace un rôle par sa version renvoyée après enregistrement.
  DroitsEtPermissions avecRole(RolePermissions role) => DroitsEtPermissions(
        modules: modules,
        roles: roles.map((r) => r.nom == role.nom ? role : r).toList(),
        utilisateurs: utilisateurs,
        totalDroits: totalDroits,
      );

  /// Remplace la ligne d'un utilisateur après enregistrement de ses droits.
  DroitsEtPermissions avecUtilisateur(UtilisateurPermissions u) =>
      DroitsEtPermissions(
        modules: modules,
        roles: roles,
        utilisateurs:
            utilisateurs.map((x) => x.id == u.id ? u : x).toList(),
        totalDroits: totalDroits,
      );

  RolePermissions? role(String? nom) {
    if (nom == null) return null;
    for (final r in roles) {
      if (r.nom == nom) return r;
    }
    return null;
  }
}
