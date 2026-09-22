/// Réglage d'un module de l'accueil pour l'utilisateur connecté : masqué
/// ou non, et nom choisi à la place du libellé d'origine.
///
/// [code] est le chemin de la route du module (ex. « /reservation »), le
/// même qui identifie les modules dans la disposition de l'accueil.
class ModuleAccueil {
  final String code;
  final bool visible;

  /// Nom choisi par l'utilisateur ; nul : le libellé d'origine.
  final String? nom;

  const ModuleAccueil({required this.code, this.visible = true, this.nom});

  /// Longueur maximale d'un nom, fixée par le serveur.
  static const int longueurMaxNom = 40;

  factory ModuleAccueil.fromJson(Map<String, dynamic> json) {
    final nom = (json['nom'] ?? '').toString().trim();
    final visible = json['visible'];
    return ModuleAccueil(
      code: (json['code'] ?? '').toString(),
      visible: !(visible == false || visible == 0 || visible == '0'),
      nom: nom.isEmpty ? null : nom,
    );
  }

  Map<String, dynamic> toJson() => {'code': code, 'visible': visible, 'nom': nom};

  /// Un réglage sans effet (visible, nom d'origine) n'a pas à être gardé.
  bool get parDefaut => visible && nom == null;

  ModuleAccueil copyWith({bool? visible, String? nom, bool effacerNom = false}) {
    return ModuleAccueil(
      code: code,
      visible: visible ?? this.visible,
      nom: effacerNom ? null : (nom ?? this.nom),
    );
  }

  /// Lit la réponse du serveur : `{modules: [...]}`, éventuellement sous `data`.
  static List<ModuleAccueil> listeDepuis(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] != null) corps = corps['data'];
    final liste = corps is Map ? corps['modules'] : corps;
    if (liste is! List) return const [];
    return liste
        .whereType<Map>()
        .map((e) => ModuleAccueil.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.code.isNotEmpty)
        .toList();
  }
}
