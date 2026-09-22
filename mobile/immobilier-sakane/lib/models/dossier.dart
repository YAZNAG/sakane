/// Agent autorisé sur un dossier.
class AgentDuDossier {
  final int? id;
  final String? nom;

  AgentDuDossier({this.id, this.nom});

  factory AgentDuDossier.fromJson(Map<String, dynamic> json) =>
      AgentDuDossier(id: json['id'], nom: json['nom']);
}

/// Dossier de rangement des biens, créé et nommé par l'administrateur.
class Dossier {
  final int? id;
  final String? nom;
  final String? description;

  /// Famille de biens a laquelle le dossier appartient :
  /// rent-short, rent-long ou selle.
  final String? typeCode;
  final int ordre;

  /// Nombre total de biens rangés dans ce dossier, tous types confondus.
  final int nombreBiens;

  /// Agents autorisés sur ce dossier. Vide signifie « aucun agent
  /// dédié » : le dossier reste visible de tous.
  final List<AgentDuDossier> agents;

  Dossier({
    this.id,
    this.nom,
    this.description,
    this.typeCode,
    this.ordre = 0,
    this.nombreBiens = 0,
    List<AgentDuDossier>? agents,
  }) : agents = agents ?? const [];

  factory Dossier.fromJson(Map<String, dynamic> json) {
    return Dossier(
      id: json['id'],
      nom: json['nom'],
      description: json['description'],
      typeCode: json['type'],
      ordre: json['ordre'] ?? 0,
      nombreBiens: json['nombreBiens'] ?? 0,
      agents: (json['agents'] as List?)
              ?.map((e) => AgentDuDossier.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dossier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
