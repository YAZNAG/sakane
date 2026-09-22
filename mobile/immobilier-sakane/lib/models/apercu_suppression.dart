/// Ce qu'implique la suppression d'une réservation, avant confirmation.
class ApercuSuppression {
  final int id;
  final String? bien;

  /// Montant total de la réservation.
  final double montant;

  /// Ce que la réservation a rapporté (après prolongations et remboursements).
  final double revenu;

  /// L'argent encaissé en caisse pour cette réservation.
  final double encaisse;

  /// La caisse de celui qui supprime : un remboursement en sortirait.
  final String? caisseNom;
  final double? caisseSolde;

  const ApercuSuppression({
    required this.id,
    this.bien,
    this.montant = 0,
    this.revenu = 0,
    this.encaisse = 0,
    this.caisseNom,
    this.caisseSolde,
  });

  factory ApercuSuppression.fromJson(Map<String, dynamic> json) {
    final caisse = json['caisse'] is Map ? Map<String, dynamic>.from(json['caisse'] as Map) : null;
    return ApercuSuppression(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bien: json['bien']?.toString(),
      montant: (json['montant'] as num?)?.toDouble() ?? 0,
      revenu: (json['revenu'] as num?)?.toDouble() ?? 0,
      encaisse: (json['encaisse'] as num?)?.toDouble() ?? 0,
      caisseNom: caisse?['nom']?.toString(),
      caisseSolde: (caisse?['solde'] as num?)?.toDouble(),
    );
  }
}
