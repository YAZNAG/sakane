import 'package:immobilier/models/statut_jour.dart';

// L'aperçu d'un bien, tel que le serveur le rend :
// `GET /api/dashboard/immobilier/bien/{id}/apercu`.
//
// Cet aperçu ne remplace pas la fiche complète du bien : il donne ce que
// la page de gestion montre d'un coup d'œil (référence, état du jour,
// séjour en cours, liaison Airbnb). Le reste — photos, équipements —
// continue de venir de l'appel existant. Chaque champ tolère son absence.

/// Le séjour en cours, quand le bien est occupé aujourd'hui.
class SejourEnCours {
  final int id;
  final String client;

  /// Date de départ, telle que le serveur l'écrit (« 24/09/2026 »…) : elle
  /// est affichée sans retouche.
  final String? departLe;
  final String? heure;

  /// Séjour lu sur Airbnb : le client n'est pas forcément connu.
  final bool airbnb;

  const SejourEnCours({
    this.id = 0,
    this.client = '',
    this.departLe,
    this.heure,
    this.airbnb = false,
  });

  static SejourEnCours? depuis(dynamic brut) {
    if (brut is! Map) return null;
    final json = Map<String, dynamic>.from(brut);
    final airbnb = json['airbnb'];
    return SejourEnCours(
      id: _entier(json['id']) ?? 0,
      client: _texte(json['client']),
      departLe: _texteOuNul(json['departLe']),
      heure: _texteOuNul(json['heure']),
      airbnb: airbnb == true || (airbnb != null && airbnb != false && _texte(airbnb).isNotEmpty),
    );
  }
}

/// L'état de la liaison Airbnb du bien, pour la tuile « Airbnb ».
class ApercuAirbnb {
  final bool relie;

  /// Dernière synchronisation ; null si le bien n'a jamais été lu.
  final DateTime? synchroniseLe;
  final String? statut;
  final int sejours;

  const ApercuAirbnb({
    this.relie = false,
    this.synchroniseLe,
    this.statut,
    this.sejours = 0,
  });

  bool get enErreur => (statut ?? '').toLowerCase().contains('erreur') ||
      (statut ?? '').toLowerCase() == 'error';

  static ApercuAirbnb? depuis(dynamic brut) {
    if (brut is! Map) return null;
    final json = Map<String, dynamic>.from(brut);
    return ApercuAirbnb(
      relie: json['relie'] == true,
      synchroniseLe: _date(json['synchroniseLe']),
      statut: _texteOuNul(json['statut']),
      sejours: _entier(json['sejours']) ?? 0,
    );
  }
}

/// L'aperçu du bien : son identité, son état du jour, son séjour en cours.
class ApercuBien {
  final int id;

  /// « AG-0001 » : la référence lisible du bien, écrite par le serveur.
  final String reference;
  final String titre;

  /// L'étage, tel que le serveur l'écrit (« 3e », « RDC »…).
  final String? etage;
  final String? ville;
  final String? adresse;

  /// Prix d'une nuit (ou d'un mois en longue durée) : le serveur donne le
  /// prix qui convient à la famille du bien.
  final double? prixNuit;

  final String? photo;
  final int nbPhotos;

  /// L'état du bien aujourd'hui, avec son libellé et sa précision.
  final StatutJour? etat;

  final SejourEnCours? sejour;
  final int sejoursAVenir;
  final ApercuAirbnb? airbnb;

  const ApercuBien({
    this.id = 0,
    this.reference = '',
    this.titre = '',
    this.etage,
    this.ville,
    this.adresse,
    this.prixNuit,
    this.photo,
    this.nbPhotos = 0,
    this.etat,
    this.sejour,
    this.sejoursAVenir = 0,
    this.airbnb,
  });

  /// Lit `{data: {...}}` ou directement le contenu.
  static ApercuBien depuis(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] is Map) corps = corps['data'];
    if (corps is! Map) return const ApercuBien();
    final json = Map<String, dynamic>.from(corps);

    return ApercuBien(
      id: _entier(json['id']) ?? 0,
      reference: _texte(json['reference']),
      titre: _texte(json['titre']),
      etage: _texteOuNul(json['etage']),
      ville: _texteOuNul(json['ville']),
      adresse: _texteOuNul(json['adresse']),
      prixNuit: _reel(json['prixNuit']),
      photo: _texteOuNul(json['photo']),
      nbPhotos: _entier(json['nbPhotos']) ?? 0,
      etat: StatutJour.depuis(json['etat']),
      sejour: SejourEnCours.depuis(json['sejour']),
      sejoursAVenir: _entier(json['sejoursAVenir']) ?? 0,
      airbnb: ApercuAirbnb.depuis(json['airbnb']),
    );
  }
}

String _texte(dynamic valeur, {String defaut = ''}) {
  if (valeur == null) return defaut;
  final texte = valeur.toString().trim();
  return texte.isEmpty ? defaut : texte;
}

String? _texteOuNul(dynamic valeur) {
  final texte = _texte(valeur);
  return texte.isEmpty ? null : texte;
}

int? _entier(dynamic valeur) {
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.round();
  if (valeur is String) return int.tryParse(valeur.trim());
  return null;
}

double? _reel(dynamic valeur) {
  if (valeur is num) return valeur.toDouble();
  if (valeur is String) return double.tryParse(valeur.trim().replaceAll(',', '.'));
  return null;
}

DateTime? _date(dynamic valeur) {
  if (valeur is DateTime) return valeur;
  final texte = _texte(valeur);
  if (texte.isEmpty) return null;
  return DateTime.tryParse(texte);
}
