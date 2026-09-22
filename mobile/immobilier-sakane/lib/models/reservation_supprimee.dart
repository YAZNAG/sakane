/// Une réservation qui se trouve dans la corbeille.
///
/// Elle y reste une semaine : au-delà, elle n'y figure plus.
class ReservationSupprimee {
  final int id;
  final String client;
  final String? telephone;
  final String? bien;
  final String? checkin;
  final String? checkout;
  final int nuits;
  final double montant;
  final DateTime? supprimeeLe;

  /// Ce qu'il lui reste à passer dans la corbeille.
  final int joursRestants;

  /// Qui l'a supprimée, et si le client a été remboursé (null : version
  /// de l'application qui ne posait pas la question).
  final String? supprimeePar;
  final bool? rembourse;
  final double? montantRembourse;

  const ReservationSupprimee({
    required this.id,
    required this.client,
    this.telephone,
    this.bien,
    this.checkin,
    this.checkout,
    this.nuits = 0,
    this.montant = 0,
    this.supprimeeLe,
    this.joursRestants = 0,
    this.supprimeePar,
    this.rembourse,
    this.montantRembourse,
  });

  factory ReservationSupprimee.fromJson(Map<String, dynamic> json) {
    return ReservationSupprimee(
      id: json["id"] ?? 0,
      client: (json["client"] ?? "").toString().trim(),
      telephone: json["telephone"],
      bien: json["bien"],
      checkin: json["checkin"]?.toString(),
      checkout: json["checkout"]?.toString(),
      nuits: (json["nuits"] as num?)?.toInt() ?? 0,
      montant: (json["montant"] as num?)?.toDouble() ?? 0,
      supprimeeLe: DateTime.tryParse(json["supprimeeLe"] ?? "")?.toLocal(),
      joursRestants: (json["joursRestants"] as num?)?.toInt() ?? 0,
      supprimeePar: json["supprimeePar"]?.toString(),
      rembourse: json["rembourse"] is bool ? json["rembourse"] as bool : null,
      montantRembourse: (json["montantRembourse"] as num?)?.toDouble(),
    );
  }
}
