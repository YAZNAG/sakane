// L'aperçu d'une famille de biens, tel que le serveur le rend :
// `GET /api/dashboard/immobilier/famille/{code}` (rent-short, rent-long,
// selle).
//
// Rien n'est compté ni déduit ici : le serveur seul sait combien de biens
// sont réservés, disponibles ou en nettoyage, et quelles arrivées et
// quels départs tombent aujourd'hui. Chaque champ tolère son absence —
// une réponse partielle laisse l'écran utilisable.

/// Les quatre compteurs de la famille, au-dessus des listes du jour.
class CompteursFamille {
  final int total;
  final int reserves;
  final int disponibles;
  final int nettoyage;

  const CompteursFamille({
    this.total = 0,
    this.reserves = 0,
    this.disponibles = 0,
    this.nettoyage = 0,
  });

  factory CompteursFamille.fromJson(Map<String, dynamic> json) {
    return CompteursFamille(
      total: _entier(json['total']) ?? 0,
      reserves: _entier(json['reserves']) ?? 0,
      disponibles: _entier(json['disponibles']) ?? 0,
      nettoyage: _entier(json['nettoyage']) ?? 0,
    );
  }
}

/// Une arrivée ou un départ du jour.
///
/// Les deux listes ont la même forme : c'est [heure] et la place dans la
/// réponse qui disent s'il s'agit d'une arrivée (« 15:00 ») ou d'un
/// départ (« 11:00 »).
class SejourDuJour {
  /// Identifiant de la réservation : c'est lui qui ouvre le détail.
  final int id;

  /// Le bien concerné, pour ouvrir sa fiche de gestion.
  final int? bienId;
  final String bien;

  /// Nom du client en caractères latins, et sa version arabe quand le
  /// serveur la connaît (affichée sous le premier, de droite à gauche).
  final String client;
  final String? clientAr;

  /// « 15:00 » ou « 11:00 » : l'heure prévue, telle quelle.
  final String heure;
  final int nuits;

  final double montant;
  final double reste;

  /// `paye`, `partiel` ou `non_paye`. Un code inconnu reste neutre.
  final String paiement;

  /// L'identifiant du séjour sur Airbnb, s'il vient de là : le client
  /// n'est alors pas connu, et le départ ne se confirme pas ici.
  final String? airbnb;

  final String? statut;
  final String? nettoyage;

  const SejourDuJour({
    this.id = 0,
    this.bienId,
    this.bien = '',
    this.client = '',
    this.clientAr,
    this.heure = '',
    this.nuits = 0,
    this.montant = 0,
    this.reste = 0,
    this.paiement = '',
    this.airbnb,
    this.statut,
    this.nettoyage,
  });

  bool get estAirbnb => (airbnb ?? '').isNotEmpty;

  bool get estPaye => paiement == 'paye';

  bool get estPartiel => paiement == 'partiel';

  factory SejourDuJour.fromJson(Map<String, dynamic> json) {
    return SejourDuJour(
      id: _entier(json['id']) ?? 0,
      bienId: _entier(json['bienId']),
      bien: _texte(json['bien']),
      client: _texte(json['client']),
      clientAr: _texteOuNul(json['clientAr']),
      heure: _texte(json['heure']),
      nuits: _entier(json['nuits']) ?? 0,
      montant: _reel(json['montant']) ?? 0,
      reste: _reel(json['reste']) ?? 0,
      paiement: _texte(json['paiement']),
      airbnb: _texteOuNul(json['airbnb']),
      statut: _texteOuNul(json['statut']),
      nettoyage: _texteOuNul(json['nettoyage']),
    );
  }

  static List<SejourDuJour> liste(dynamic brut) {
    if (brut is! List) return const [];
    return brut
        .whereType<Map>()
        .map((e) => SejourDuJour.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

/// L'aperçu complet d'une famille : son nom, ses compteurs, et ce qui se
/// passe aujourd'hui.
class ApercuFamille {
  final String famille;
  final CompteursFamille compteurs;
  final List<SejourDuJour> arrivees;
  final List<SejourDuJour> departs;

  const ApercuFamille({
    this.famille = '',
    this.compteurs = const CompteursFamille(),
    this.arrivees = const [],
    this.departs = const [],
  });

  /// Lit `{data: {...}}` ou directement le contenu.
  static ApercuFamille depuis(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] is Map) corps = corps['data'];
    if (corps is! Map) return const ApercuFamille();
    final json = Map<String, dynamic>.from(corps);

    return ApercuFamille(
      famille: _texte(json['famille']),
      compteurs: json['compteurs'] is Map
          ? CompteursFamille.fromJson(
              Map<String, dynamic>.from(json['compteurs'] as Map))
          : const CompteursFamille(),
      arrivees: SejourDuJour.liste(json['arrivees']),
      departs: SejourDuJour.liste(json['departs']),
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
