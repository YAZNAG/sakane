/// Un syndic d'immeuble : il reçoit le contrat public de chaque nouvelle
/// réservation, prolongation ou raccourcissement dans l'un de ses biens.
/// Un bien peut avoir plusieurs syndics.
class Syndic {
  final int id;
  final String nom;
  final String telephone;
  final bool actif;
  final String? notes;
  final int nombreBiens;
  final List<BienDuSyndic> biens;
  final EnvoiSyndic? dernierEnvoi;
  final List<EnvoiSyndic> envois;

  const Syndic({
    required this.id,
    required this.nom,
    required this.telephone,
    this.actif = true,
    this.notes,
    this.nombreBiens = 0,
    this.biens = const [],
    this.dernierEnvoi,
    this.envois = const [],
  });

  factory Syndic.fromJson(Map<String, dynamic> json) {
    return Syndic(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: (json['nom'] ?? '').toString(),
      telephone: (json['telephone'] ?? '').toString(),
      actif: json['actif'] != false,
      notes: json['notes']?.toString(),
      nombreBiens: (json['nombreBiens'] as num?)?.toInt() ?? 0,
      biens: ((json['biens'] as List?) ?? const [])
          .map((e) => BienDuSyndic.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      dernierEnvoi: json['dernierEnvoi'] is Map
          ? EnvoiSyndic.fromJson(Map<String, dynamic>.from(json['dernierEnvoi'] as Map))
          : null,
      envois: ((json['envois'] as List?) ?? const [])
          .map((e) => EnvoiSyndic.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class BienDuSyndic {
  final int id;
  final String titre;

  /// Premier syndic du bien (liste de choix des biens).
  final int? syndicId;

  /// Noms des syndics du bien, séparés par des virgules (« Nom A, Nom B »).
  final String? syndic;

  /// Tous les syndics du bien : un bien peut en avoir plusieurs.
  final List<SyndicDuBien> syndics;

  const BienDuSyndic({
    required this.id,
    required this.titre,
    this.syndicId,
    this.syndic,
    this.syndics = const [],
  });

  factory BienDuSyndic.fromJson(Map<String, dynamic> json) {
    final syndicId = (json['syndicId'] as num?)?.toInt();
    final syndic = json['syndic']?.toString();
    var syndics = <SyndicDuBien>[];
    if (json['syndics'] is List) {
      for (final e in json['syndics'] as List) {
        if (e is Map) {
          final s = SyndicDuBien.fromJson(Map<String, dynamic>.from(e));
          if (s.id != 0 || s.nom.isNotEmpty) syndics.add(s);
        }
      }
    } else if (syndicId != null) {
      // Ancien format : un seul syndic, déduit de syndicId / syndic.
      syndics = [SyndicDuBien(id: syndicId, nom: (syndic ?? '').trim())];
    }
    return BienDuSyndic(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: (json['titre'] ?? '').toString(),
      syndicId: syndicId,
      syndic: syndic,
      syndics: syndics,
    );
  }
}

/// Un syndic auquel un bien est rattaché.
class SyndicDuBien {
  final int id;
  final String nom;

  const SyndicDuBien({required this.id, required this.nom});

  factory SyndicDuBien.fromJson(Map<String, dynamic> json) {
    return SyndicDuBien(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: (json['nom'] ?? '').toString().trim(),
    );
  }
}

/// Un envoi du contrat public au syndic : envoye, echec ou ignore.
class EnvoiSyndic {
  final int? bookingId;
  final String? bien;
  final String? checkin;
  final String? checkout;
  final String statut;
  final String? erreur;
  final DateTime? le;

  const EnvoiSyndic({
    this.bookingId,
    this.bien,
    this.checkin,
    this.checkout,
    required this.statut,
    this.erreur,
    this.le,
  });

  factory EnvoiSyndic.fromJson(Map<String, dynamic> json) {
    return EnvoiSyndic(
      bookingId: (json['bookingId'] as num?)?.toInt(),
      bien: json['bien']?.toString(),
      checkin: json['checkin']?.toString(),
      checkout: json['checkout']?.toString(),
      statut: (json['statut'] ?? '').toString(),
      erreur: json['erreur']?.toString(),
      le: DateTime.tryParse((json['le'] ?? '').toString())?.toLocal(),
    );
  }
}
