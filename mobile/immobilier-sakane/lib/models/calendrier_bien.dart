import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/statut_jour.dart';

/// Le calendrier de gestion d'un bien : prix des nuits, blocages,
/// reservations (passees comprises), baux de longue duree et sejours
/// lus sur Airbnb.
///
/// Les dates sont des nuits : un sejour du 10 au 13 occupe les nuits du 10,
/// 11 et 12 ; un blocage du 10 au 13 bloque les nuits du 10 au 13 inclus.
class CalendrierBien {
  final int bienId;
  final String? titre;
  final double prixBase;

  /// Statut du bien aujourd'hui (bien.statutJour), s'il est fourni.
  final StatutJour? statutJour;
  final DateTime du;
  final DateTime au;

  /// Prix fixes pour certaines nuits, cle = date sans heure.
  final Map<DateTime, double> prix;
  final List<BlocageCalendrier> blocages;
  final List<ReservationCalendrier> reservations;
  final List<BailCalendrier> baux;

  /// Sejours lus sur Airbnb : du..au, depart exclu.
  final List<SejourAirbnb> airbnb;

  const CalendrierBien({
    required this.bienId,
    this.titre,
    this.prixBase = 0,
    this.statutJour,
    required this.du,
    required this.au,
    this.prix = const {},
    this.blocages = const [],
    this.reservations = const [],
    this.baux = const [],
    this.airbnb = const [],
  });

  static DateTime jour(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _date(dynamic v) => jour(DateTime.parse(v.toString()));

  factory CalendrierBien.fromJson(Map<String, dynamic> json) {
    final bien = Map<String, dynamic>.from((json['bien'] ?? {}) as Map);
    return CalendrierBien(
      bienId: (bien['id'] as num?)?.toInt() ?? 0,
      titre: bien['titre']?.toString(),
      prixBase: (bien['prixBase'] as num?)?.toDouble() ?? 0,
      statutJour: StatutJour.depuis(bien['statutJour']),
      du: _date(json['du']),
      au: _date(json['au']),
      prix: {
        for (final p in (json['prix'] as List? ?? const []))
          _date((p as Map)['date']): (p['prix'] as num).toDouble(),
      },
      blocages: (json['blocages'] as List? ?? const [])
          .map((e) => BlocageCalendrier.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      reservations: (json['reservations'] as List? ?? const [])
          .map((e) => ReservationCalendrier.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      baux: (json['baux'] as List? ?? const [])
          .map((e) => BailCalendrier.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      airbnb: (json['airbnb'] as List? ?? const [])
          .map((e) => SejourAirbnb.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// Prix de la nuit : prix fixe s'il existe, sinon prix habituel.
  double prixDe(DateTime nuit) => prix[jour(nuit)] ?? prixBase;

  bool aPrixSpecial(DateTime nuit) => prix.containsKey(jour(nuit));

  /// Le blocage qui couvre cette nuit, s'il y en a un.
  BlocageCalendrier? blocageDe(DateTime nuit) {
    final j = jour(nuit);
    for (final b in blocages) {
      if (!j.isBefore(b.du) && !j.isAfter(b.au)) return b;
    }
    return null;
  }

  /// La reservation qui occupe cette nuit, s'il y en a une.
  ReservationCalendrier? reservationDe(DateTime nuit) {
    final j = jour(nuit);
    for (final r in reservations) {
      if (!j.isBefore(r.checkin) && j.isBefore(r.checkout)) return r;
    }
    return null;
  }

  /// Le bail de longue duree qui occupe ce jour, s'il y en a un.
  BailCalendrier? bailDe(DateTime nuit) {
    final j = jour(nuit);
    for (final b in baux) {
      if (!j.isBefore(b.du) && !j.isAfter(b.au)) return b;
    }
    return null;
  }

  /// Le sejour Airbnb qui occupe cette nuit, s'il y en a un.
  SejourAirbnb? sejourAirbnbDe(DateTime nuit) {
    final j = jour(nuit);
    for (final s in airbnb) {
      if (!j.isBefore(s.du) && j.isBefore(s.au)) return s;
    }
    return null;
  }

  /// La reservation Airbnb (pas un simple blocage) qui occupe cette
  /// nuit, s'il y en a une.
  SejourAirbnb? reservationAirbnbDe(DateTime nuit) {
    final s = sejourAirbnbDe(nuit);
    return s != null && s.estReservation ? s : null;
  }

  /// Reservation, bail ou reservation Airbnb : le jour n'est pas libre.
  /// Un jour seulement bloque sur Airbnb reste reservable ici.
  bool estOccupe(DateTime nuit) =>
      reservationDe(nuit) != null || bailDe(nuit) != null || reservationAirbnbDe(nuit) != null;
}

/// Un bail de longue duree : du..au inclus.
class BailCalendrier {
  final int id;
  final DateTime du;
  final DateTime au;
  final String statut;
  final String? locataire;
  final String? tel;
  final double loyer;

  const BailCalendrier({
    required this.id,
    required this.du,
    required this.au,
    this.statut = 'actif',
    this.locataire,
    this.tel,
    this.loyer = 0,
  });

  bool get actif => statut == 'actif';

  /// Le lendemain du dernier jour, comme le depart d'une reservation.
  DateTime get finExclue => DateTime(au.year, au.month, au.day + 1);

  factory BailCalendrier.fromJson(Map<String, dynamic> json) {
    final loc = json['locataire'];
    return BailCalendrier(
      id: (json['id'] as num?)?.toInt() ?? 0,
      du: CalendrierBien._date(json['du']),
      au: CalendrierBien._date(json['au']),
      statut: (json['statut'] ?? 'actif').toString(),
      locataire: loc is Map ? loc['nom']?.toString() : loc?.toString(),
      tel: json['tel']?.toString() ?? (loc is Map ? loc['tel']?.toString() : null),
      loyer: (json['loyer'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BlocageCalendrier {
  final int id;
  final DateTime du;
  final DateTime au;
  final int nuits;
  final String? motif;
  final String? par;

  const BlocageCalendrier({
    required this.id,
    required this.du,
    required this.au,
    this.nuits = 0,
    this.motif,
    this.par,
  });

  factory BlocageCalendrier.fromJson(Map<String, dynamic> json) {
    return BlocageCalendrier(
      id: (json['id'] as num?)?.toInt() ?? 0,
      du: CalendrierBien._date(json['du']),
      au: CalendrierBien._date(json['au']),
      nuits: (json['nuits'] as num?)?.toInt() ?? 0,
      motif: json['motif']?.toString(),
      par: json['par']?.toString(),
    );
  }
}

/// Une reservation du calendrier. Hors charges, toute operation est
/// consideree payee : le paiement vaut toujours 'paye'.
class ReservationCalendrier {
  final int id;
  final DateTime checkin;
  final DateTime checkout;
  final String? heureArrivee;
  final String? heureDepart;
  final int nuits;
  final int? clientId;
  final String? clientNom;
  final String? clientTel;
  final String? clientCin;
  final double montant;
  final double? prixNuit;
  final double avance;
  final double caution;
  final String? remarques;
  final String? statutCode;
  final String? statutNom;
  final double encaisse;
  final double reste;
  final String paiement;
  final String? creePar;
  final String? contratPublic;
  final String? contratPrive;
  final bool passee;

  const ReservationCalendrier({
    required this.id,
    required this.checkin,
    required this.checkout,
    this.heureArrivee,
    this.heureDepart,
    this.nuits = 0,
    this.clientId,
    this.clientNom,
    this.clientTel,
    this.clientCin,
    this.montant = 0,
    this.prixNuit,
    this.avance = 0,
    this.caution = 0,
    this.remarques,
    this.statutCode,
    this.statutNom,
    this.encaisse = 0,
    this.reste = 0,
    this.paiement = 'paye',
    this.creePar,
    this.contratPublic,
    this.contratPrive,
    this.passee = false,
  });

  String get libellePaiement => 'Payé';

  factory ReservationCalendrier.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map ? Map<String, dynamic>.from(json['client'] as Map) : null;
    final statut = json['statut'] is Map ? Map<String, dynamic>.from(json['statut'] as Map) : null;
    return ReservationCalendrier(
      id: (json['id'] as num?)?.toInt() ?? 0,
      checkin: CalendrierBien._date(json['checkin']),
      checkout: CalendrierBien._date(json['checkout']),
      heureArrivee: json['heureArrivee']?.toString(),
      heureDepart: json['heureDepart']?.toString(),
      nuits: (json['nuits'] as num?)?.toInt() ?? 0,
      clientId: (client?['id'] as num?)?.toInt(),
      clientNom: client?['nom']?.toString(),
      clientTel: client?['tel']?.toString(),
      clientCin: client?['cin']?.toString(),
      montant: (json['montant'] as num?)?.toDouble() ?? 0,
      prixNuit: (json['prixNuit'] as num?)?.toDouble(),
      avance: (json['avance'] as num?)?.toDouble() ?? 0,
      caution: (json['caution'] as num?)?.toDouble() ?? 0,
      remarques: json['remarques']?.toString(),
      statutCode: statut?['code']?.toString(),
      statutNom: statut?['nom']?.toString(),
      encaisse: (json['encaisse'] as num?)?.toDouble() ?? 0,
      reste: (json['reste'] as num?)?.toDouble() ?? 0,
      paiement: (json['paiement'] ?? 'paye').toString(),
      creePar: json['creePar']?.toString(),
      contratPublic: json['contratPublic']?.toString(),
      contratPrive: json['contratPrive']?.toString(),
      passee: json['passee'] == true,
    );
  }
}

/// Prix d'un sejour, nuit par nuit.
class TarifSejour {
  final int nuits;
  final double total;
  final double prixMoyen;
  final double prixBase;
  final bool contientPrixSpecial;

  const TarifSejour({
    this.nuits = 0,
    this.total = 0,
    this.prixMoyen = 0,
    this.prixBase = 0,
    this.contientPrixSpecial = false,
  });

  factory TarifSejour.fromJson(Map<String, dynamic> json) {
    return TarifSejour(
      nuits: (json['nuits'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      prixMoyen: (json['prixMoyen'] as num?)?.toDouble() ?? 0,
      prixBase: (json['prixBase'] as num?)?.toDouble() ?? 0,
      contientPrixSpecial: (json['detail'] as List? ?? const [])
          .any((d) => (d as Map)['special'] == true),
    );
  }
}
