/// Une charge annulée.
///
/// Annuler n'efface pas : la dépense reste connue, avec ce qui en a été
/// rendu, par qui et quand. C'est ce que montre l'historique.
class ChargeAnnulee {
  final int id;
  final String? nom;
  final String? description;
  final double montant;

  /// Ce qui est revenu en caisse. Nul quand rien n'a été récupéré.
  final double? rembourse;

  final String? bien;
  final String? creeePar;
  final String? annuleePar;
  final DateTime? annuleeLe;
  final DateTime? creeeLe;
  final String? motif;

  const ChargeAnnulee({
    required this.id,
    this.nom,
    this.description,
    this.montant = 0,
    this.rembourse,
    this.bien,
    this.creeePar,
    this.annuleePar,
    this.annuleeLe,
    this.creeeLe,
    this.motif,
  });

  factory ChargeAnnulee.fromJson(Map<String, dynamic> json) {
    return ChargeAnnulee(
      id: json["id"] ?? 0,
      nom: json["nom"],
      description: json["description"],
      montant: (json["montant"] as num?)?.toDouble() ?? 0,
      rembourse: (json["rembourse"] as num?)?.toDouble(),
      bien: json["bien"],
      creeePar: json["creeePar"],
      annuleePar: json["annuleePar"],
      annuleeLe: DateTime.tryParse(json["annuleeLe"] ?? "")?.toLocal(),
      creeeLe: DateTime.tryParse(json["creeeLe"] ?? "")?.toLocal(),
      motif: json["motif"],
    );
  }
}
