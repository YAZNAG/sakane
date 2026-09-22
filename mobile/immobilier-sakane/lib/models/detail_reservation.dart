/// Le detail complet d'une reservation, tel que le rend
/// GET /bookings/{id}/detail (et POST /bookings/{id}/modifier-prix).
///
/// Les nombres arrivent tantot entiers, tantot decimaux, parfois en
/// texte : tout passe par [lireNombre].
library;

double lireNombre(dynamic v, [double defaut = 0]) {
  if (v == null) return defaut;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(' ', '').replaceAll(',', '.')) ?? defaut;
}

double? lireNombreOuNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(' ', '').replaceAll(',', '.'));
}

int lireEntier(dynamic v, [int defaut = 0]) => lireNombreOuNull(v)?.round() ?? defaut;

String? lireTexte(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

bool lireBooleen(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final t = v?.toString().toLowerCase().trim();
  return t == 'true' || t == '1' || t == 'oui';
}

DateTime? lireDate(dynamic v) {
  final t = lireTexte(v);
  return t == null ? null : DateTime.tryParse(t);
}

Map<String, dynamic>? _objet(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> _liste(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

class ClientReservation {
  final int? id;
  final String nom;
  final String? tel;
  final String? cin;
  final bool listeNoire;

  const ClientReservation({this.id, this.nom = '', this.tel, this.cin, this.listeNoire = false});

  factory ClientReservation.fromJson(Map<String, dynamic> j) => ClientReservation(
        id: lireNombreOuNull(j['id'])?.round(),
        nom: lireTexte(j['nom']) ?? '',
        tel: lireTexte(j['tel']),
        cin: lireTexte(j['cin']),
        listeNoire: lireBooleen(j['listeNoire']),
      );
}

class BienReservation {
  final int? id;
  final String titre;
  final String? adresse;

  const BienReservation({this.id, this.titre = '', this.adresse});

  factory BienReservation.fromJson(Map<String, dynamic> j) => BienReservation(
        id: lireNombreOuNull(j['id'])?.round(),
        titre: lireTexte(j['titre']) ?? '',
        adresse: lireTexte(j['adresse']),
      );
}

/// Une ligne de l'historique : prolongation, raccourcissement ou prix.
class ModificationReservation {
  final int? id;
  final String type;
  final String? typeLibelle;
  final DateTime? date;
  final DateTime? ancienCheckout;
  final DateTime? nouveauCheckout;
  final int nuitsDelta;
  final double? ancienPrixNuit;
  final double? nouveauPrixNuit;
  final double? ancienTotal;
  final double? nouveauTotal;
  final double ecart;
  final double encaisse;
  final double rembourse;
  final String? par;

  const ModificationReservation({
    this.id,
    required this.type,
    this.typeLibelle,
    this.date,
    this.ancienCheckout,
    this.nouveauCheckout,
    this.nuitsDelta = 0,
    this.ancienPrixNuit,
    this.nouveauPrixNuit,
    this.ancienTotal,
    this.nouveauTotal,
    this.ecart = 0,
    this.encaisse = 0,
    this.rembourse = 0,
    this.par,
  });

  bool get estPrix => type == 'prix';
  bool get estProlongation => type == 'prolongation';
  bool get estRaccourcissement => type == 'raccourcissement';

  factory ModificationReservation.fromJson(Map<String, dynamic> j) => ModificationReservation(
        id: lireNombreOuNull(j['id'])?.round(),
        type: lireTexte(j['type']) ?? '',
        typeLibelle: lireTexte(j['typeLibelle']),
        date: lireDate(j['date']),
        ancienCheckout: lireDate(j['ancienCheckout']),
        nouveauCheckout: lireDate(j['nouveauCheckout']),
        nuitsDelta: lireEntier(j['nuitsDelta']),
        ancienPrixNuit: lireNombreOuNull(j['ancienPrixNuit']),
        nouveauPrixNuit: lireNombreOuNull(j['nouveauPrixNuit']),
        ancienTotal: lireNombreOuNull(j['ancienTotal']),
        nouveauTotal: lireNombreOuNull(j['nouveauTotal']),
        ecart: lireNombre(j['ecart']),
        encaisse: lireNombre(j['encaisse']),
        rembourse: lireNombre(j['rembourse']),
        par: lireTexte(j['par']),
      );
}

/// Un mouvement de caisse lie a la reservation.
class PaiementReservation {
  final int? id;
  final DateTime? date;
  final String sens;
  final double montant;
  final String? libelle;
  final String? par;

  const PaiementReservation({this.id, this.date, this.sens = 'entree', this.montant = 0, this.libelle, this.par});

  bool get estSortie => sens == 'sortie';

  factory PaiementReservation.fromJson(Map<String, dynamic> j) => PaiementReservation(
        id: lireNombreOuNull(j['id'])?.round(),
        date: lireDate(j['date']),
        sens: lireTexte(j['sens']) ?? 'entree',
        montant: lireNombre(j['montant']),
        libelle: lireTexte(j['libelle']),
        par: lireTexte(j['par']),
      );
}

/// Le resume de la facture d'une reservation
/// (GET /bookings/{id}/facture/resume).
///
/// Le total de la reservation est le montant H.T ; la TVA s'y ajoute.
/// Appliquer la facture est definitif : la TVA entre dans la caisse de
/// l'utilisateur connecte, et la facture ne peut plus que se consulter.
class ResumeFacture {
  final bool appliquee;
  final String? numero;
  final DateTime? appliqueeLe;
  final String? appliqueePar;
  final double ht;
  final double taux;
  final double tva;
  final double ttc;
  final double tvaEncaissee;

  /// Facture appliquee des la creation de la reservation : la TVA est
  /// comprise dans le total, rien de plus n'est entre en caisse.
  final bool tvaIncluse;
  final String clientNom;
  final String? clientIce;
  final String? clientAdresse;

  const ResumeFacture({
    this.appliquee = false,
    this.numero,
    this.appliqueeLe,
    this.appliqueePar,
    this.ht = 0,
    this.taux = 20,
    this.tva = 0,
    this.ttc = 0,
    this.tvaEncaissee = 0,
    this.tvaIncluse = false,
    this.clientNom = '',
    this.clientIce,
    this.clientAdresse,
  });

  factory ResumeFacture.fromJson(Map<String, dynamic> j) {
    final ht = lireNombre(j['ht']);
    final taux = lireNombre(j['taux'], 20);
    final tva = lireNombreOuNull(j['tva']) ?? ht * taux / 100;
    return ResumeFacture(
      appliquee: lireBooleen(j['appliquee']),
      numero: lireTexte(j['numero']),
      appliqueeLe: lireDate(j['appliqueeLe']),
      appliqueePar: lireTexte(j['appliqueePar']),
      ht: ht,
      taux: taux,
      tva: tva,
      ttc: lireNombreOuNull(j['ttc']) ?? ht + tva,
      tvaEncaissee: lireNombre(j['tvaEncaissee']),
      tvaIncluse: lireBooleen(j['tvaIncluse']),
      clientNom: lireTexte(j['clientNom']) ?? '',
      clientIce: lireTexte(j['clientIce']),
      clientAdresse: lireTexte(j['clientAdresse']),
    );
  }
}

class DetailReservation {
  final int id;
  final String? statutCode;
  final String? statutNom;
  final bool supprimee;
  final ClientReservation? client;
  final BienReservation? bien;
  final DateTime? checkin;
  final DateTime? checkout;
  final String? heureArrivee;
  final String? heureDepart;
  final int nuits;
  final int personnes;
  final String? typeInvite;
  final double prixNuit;
  final double montant;
  final double avance;
  final double caution;
  final double encaisse;
  final double reste;
  final String? remarques;
  final String? creePar;
  final DateTime? creeLe;
  final String? contratPublic;
  final String? contratPrive;
  final bool modifiee;
  final List<ModificationReservation> modifications;
  final List<PaiementReservation> paiements;
  final ResumeFacture? facture;

  /// Contrat cree depuis une reservation Airbnb.
  final bool airbnb;

  const DetailReservation({
    required this.id,
    this.statutCode,
    this.statutNom,
    this.supprimee = false,
    this.client,
    this.bien,
    this.checkin,
    this.checkout,
    this.heureArrivee,
    this.heureDepart,
    this.nuits = 0,
    this.personnes = 0,
    this.typeInvite,
    this.prixNuit = 0,
    this.montant = 0,
    this.avance = 0,
    this.caution = 0,
    this.encaisse = 0,
    this.reste = 0,
    this.remarques,
    this.creePar,
    this.creeLe,
    this.contratPublic,
    this.contratPrive,
    this.modifiee = false,
    this.modifications = const [],
    this.paiements = const [],
    this.facture,
    this.airbnb = false,
  });

  /// Nuits du sejour : celles du serveur, sinon l'ecart des dates.
  int get nombreNuits {
    if (nuits > 0) return nuits;
    if (checkin != null && checkout != null) {
      final n = DateTime.utc(checkout!.year, checkout!.month, checkout!.day)
          .difference(DateTime.utc(checkin!.year, checkin!.month, checkin!.day))
          .inDays;
      return n > 0 ? n : 0;
    }
    return 0;
  }

  factory DetailReservation.fromJson(Map<String, dynamic> j) {
    final statut = j['statut'];
    final client = _objet(j['client']);
    final bien = _objet(j['bien']);
    final facture = _objet(j['facture']);
    return DetailReservation(
      id: lireEntier(j['id']),
      statutCode: statut is Map ? lireTexte(statut['code']) : lireTexte(statut),
      statutNom: statut is Map ? lireTexte(statut['nom']) : null,
      supprimee: lireBooleen(j['supprimee']),
      client: client == null ? null : ClientReservation.fromJson(client),
      bien: bien == null ? null : BienReservation.fromJson(bien),
      checkin: lireDate(j['checkin']),
      checkout: lireDate(j['checkout']),
      heureArrivee: lireTexte(j['heureArrivee']),
      heureDepart: lireTexte(j['heureDepart']),
      nuits: lireEntier(j['nuits']),
      personnes: lireEntier(j['personnes']),
      typeInvite: lireTexte(j['typeInvite']),
      prixNuit: lireNombre(j['prixNuit']),
      montant: lireNombre(j['montant']),
      avance: lireNombre(j['avance']),
      caution: lireNombre(j['caution']),
      encaisse: lireNombre(j['encaisse']),
      reste: lireNombre(j['reste']),
      remarques: lireTexte(j['remarques']),
      creePar: lireTexte(j['creePar']),
      creeLe: lireDate(j['creeLe']),
      contratPublic: lireTexte(j['contratPublic']),
      contratPrive: lireTexte(j['contratPrive']),
      modifiee: lireBooleen(j['modifiee']),
      modifications: _liste(j['modifications']).map(ModificationReservation.fromJson).toList(),
      paiements: _liste(j['paiements']).map(PaiementReservation.fromJson).toList(),
      facture: facture == null ? null : ResumeFacture.fromJson(facture),
      airbnb: lireBooleen(j['airbnb']),
    );
  }
}

/// Heures d'arrivee et de depart appliquees par defaut (« HH:mm »).
class HeuresParDefaut {
  final String arrivee;
  final String depart;

  const HeuresParDefaut({this.arrivee = '14:00', this.depart = '12:00'});

  factory HeuresParDefaut.fromJson(Map<String, dynamic> j) => HeuresParDefaut(
        arrivee: _heure(j['arrivee']) ?? '14:00',
        depart: _heure(j['depart']) ?? '12:00',
      );

  static String? _heure(dynamic v) {
    final t = lireTexte(v);
    if (t == null) return null;
    return t.length >= 5 ? t.substring(0, 5) : t;
  }
}
