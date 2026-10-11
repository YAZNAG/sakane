import 'package:immobilier/models/charge.dart';

/// Les charges fixes, telles que le serveur les range : par famille, avec
/// leurs totaux, et les échéances qui les ramènent chaque mois.

/// Une famille du catalogue : « Salaires et primes », « Abonnements »...
class CategorieCharge {
  final String code;
  final String libelle;
  final String? icone;
  final String? couleur;

  /// Vrai pour « Autre » : cette famille porte le nom que l'on lui donne.
  final bool libre;

  const CategorieCharge({
    required this.code,
    required this.libelle,
    this.icone,
    this.couleur,
    this.libre = false,
  });

  factory CategorieCharge.fromJson(Map<String, dynamic> json) =>
      CategorieCharge(
        code: json['code']?.toString() ?? '',
        libelle: json['libelle']?.toString() ?? '',
        icone: json['icone']?.toString(),
        couleur: json['couleur']?.toString(),
        libre: json['libre'] == true,
      );
}

/// Une famille et ce qu'elle a coûté sur la période.
class FamilleCharges {
  final String code;
  final String libelle;
  final String? icone;
  final String? couleur;
  final int nombre;
  final double total;

  /// La part qui n'est pas encore réglée.
  final double attente;
  final List<Charge> charges;

  const FamilleCharges({
    required this.code,
    required this.libelle,
    required this.nombre,
    required this.total,
    required this.attente,
    required this.charges,
    this.icone,
    this.couleur,
  });

  factory FamilleCharges.fromJson(Map<String, dynamic> json) => FamilleCharges(
        code: json['code']?.toString() ?? '',
        libelle: json['libelle']?.toString() ?? '',
        icone: json['icone']?.toString(),
        couleur: json['couleur']?.toString(),
        nombre: (json['nombre'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        attente: (json['attente'] as num?)?.toDouble() ?? 0,
        charges: ((json['charges'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Charge.fromJson)
            .toList(),
      );
}

/// Une échéance mensuelle : ce qui revient le même jour chaque mois.
class RecurrenceCharge {
  final int id;
  final String nom;
  final String? description;
  final double montant;
  final int jour;
  final String categorie;
  final String categorieLibelle;
  final int? bienId;
  final String? bien;

  const RecurrenceCharge({
    required this.id,
    required this.nom,
    required this.montant,
    required this.jour,
    required this.categorie,
    required this.categorieLibelle,
    this.description,
    this.bienId,
    this.bien,
  });

  factory RecurrenceCharge.fromJson(Map<String, dynamic> json) {
    final bien = json['bien'] as Map<String, dynamic>?;
    return RecurrenceCharge(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString(),
      montant: (json['montant'] as num?)?.toDouble() ?? 0,
      jour: (json['jour'] as num?)?.toInt() ?? 1,
      categorie: json['categorie']?.toString() ?? 'autre',
      categorieLibelle: json['categorieLibelle']?.toString() ?? 'Autre',
      bienId: (bien?['id'] as num?)?.toInt(),
      bien: bien?['title']?.toString(),
    );
  }
}

/// Le mois des charges fixes : ses totaux, ses familles, ses échéances.
class ChargesFixes {
  final DateTime? du;
  final DateTime? au;
  final int nombre;
  final double total;
  final double payees;
  final double attente;
  final List<FamilleCharges> familles;
  final List<RecurrenceCharge> recurrences;

  /// Ce que les échéances mensuelles représentent, chaque mois.
  final double totalRecurrent;
  final List<CategorieCharge> catalogue;

  const ChargesFixes({
    required this.nombre,
    required this.total,
    required this.payees,
    required this.attente,
    required this.familles,
    required this.recurrences,
    required this.totalRecurrent,
    required this.catalogue,
    this.du,
    this.au,
  });

  factory ChargesFixes.fromJson(Map<String, dynamic> reponse) {
    final data = (reponse['data'] as Map<String, dynamic>?) ?? reponse;
    final totaux = (data['totaux'] as Map<String, dynamic>?) ?? const {};

    return ChargesFixes(
      du: DateTime.tryParse(data['du']?.toString() ?? ''),
      au: DateTime.tryParse(data['au']?.toString() ?? ''),
      nombre: (totaux['nombre'] as num?)?.toInt() ?? 0,
      total: (totaux['total'] as num?)?.toDouble() ?? 0,
      payees: (totaux['payees'] as num?)?.toDouble() ?? 0,
      attente: (totaux['attente'] as num?)?.toDouble() ?? 0,
      familles: ((data['familles'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FamilleCharges.fromJson)
          .toList(),
      recurrences: ((data['recurrences'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RecurrenceCharge.fromJson)
          .toList(),
      totalRecurrent: (data['totalRecurrent'] as num?)?.toDouble() ?? 0,
      catalogue: ((data['catalogue'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CategorieCharge.fromJson)
          .toList(),
    );
  }

  /// Le catalogue par code, pour retrouver une famille en un coup.
  Map<String, CategorieCharge> get parCode =>
      {for (final c in catalogue) c.code: c};
}

/// Ce que le formulaire envoie : une charge fixe, réglée ou non, et son
/// éventuelle répétition mensuelle.
class SaisieChargeFixe {
  final String nom;
  final String? description;
  final double montant;
  final String categorie;

  /// Le nom donné à la famille « Autre ».
  final String? categorieLibelle;
  final int? bienId;
  final bool payee;
  final bool mensuelle;
  final int? jour;

  const SaisieChargeFixe({
    required this.nom,
    required this.montant,
    required this.categorie,
    this.description,
    this.categorieLibelle,
    this.bienId,
    this.payee = true,
    this.mensuelle = false,
    this.jour,
  });

  Map<String, dynamic> enCorps({bool avecRepetition = true}) => {
        'nom': nom,
        if ((description ?? '').trim().isNotEmpty) 'description': description,
        'amount': montant,
        'categorie': categorie,
        if ((categorieLibelle ?? '').trim().isNotEmpty)
          'categorieLibelle': categorieLibelle,
        if (bienId != null) 'realestate': bienId,
        'status': payee ? 'payed' : 'pending',
        if (avecRepetition) 'mensuelle': mensuelle ? 1 : 0,
        if (avecRepetition && mensuelle && jour != null) 'jour': jour,
      };
}
