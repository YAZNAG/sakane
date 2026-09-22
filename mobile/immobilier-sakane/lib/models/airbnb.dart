/// Liaison d'un bien avec son annonce Airbnb, par liens de calendrier (iCal).
///
/// Airbnb -> application : le serveur lit [urlImport] toutes les 15 minutes.
/// Application -> Airbnb : [lienExport] est a coller dans « Importer un
/// calendrier » sur Airbnb.
class LienAirbnb {
  final String? urlImport;
  final String lienExport;
  final DateTime? derniereSyncA;

  /// 'ok', 'erreur' ou null (jamais synchronise).
  final String? statut;
  final String? erreur;

  /// Derniere lecture du lien d'export par Airbnb.
  final DateTime? derniereLectureAirbnbA;
  final List<SejourAirbnb> sejoursAVenir;

  const LienAirbnb({
    this.urlImport,
    this.lienExport = '',
    this.derniereSyncA,
    this.statut,
    this.erreur,
    this.derniereLectureAirbnbA,
    this.sejoursAVenir = const [],
  });

  bool get relie => (urlImport ?? '').trim().isNotEmpty;

  bool get enErreur => statut == 'erreur';

  factory LienAirbnb.fromJson(Map<String, dynamic> json) {
    return LienAirbnb(
      urlImport: _texte(json['urlImport']),
      lienExport: (json['lienExport'] ?? '').toString(),
      derniereSyncA: lireInstant(json['derniereSyncA']),
      statut: _texte(json['statut']),
      erreur: _texte(json['erreur']),
      derniereLectureAirbnbA: lireInstant(json['derniereLectureAirbnbA']),
      sejoursAVenir: (json['sejoursAVenir'] as List? ?? const [])
          .map((e) => SejourAirbnb.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// Un sejour lu sur Airbnb : du..au, [au] etant le jour du depart (exclu).
class SejourAirbnb {
  /// Identifiant du sejour sur le serveur (a joindre au contrat).
  final int? id;
  final int? bienId;
  final String? bienTitre;
  final DateTime du;
  final DateTime au;

  /// 'reservation' ou 'bloque'.
  final String type;
  final String? resume;

  /// Lien de la reservation sur Airbnb.
  final String? lien;

  /// Code de confirmation Airbnb (« HM… »).
  final String? code;

  /// Quatre derniers chiffres du telephone du voyageur.
  final String? telephone4;

  /// Reservation (contrat) deja creee dans l'application pour ce sejour.
  final int? bookingId;

  /// Prix habituel du bien, par nuit.
  final double? prixNuit;

  final int? _nuitsServeur;

  const SejourAirbnb({
    this.id,
    this.bienId,
    this.bienTitre,
    required this.du,
    required this.au,
    this.type = 'reservation',
    this.resume,
    this.lien,
    this.code,
    this.telephone4,
    this.bookingId,
    this.prixNuit,
    int? nuitsServeur,
  }) : _nuitsServeur = nuitsServeur;

  bool get estReservation => type != 'bloque';

  /// Un contrat a deja ete cree pour ce sejour.
  bool get contratCree => bookingId != null;

  String get libelleType => estReservation ? 'Réservation Airbnb' : 'Bloqué sur Airbnb';

  int get nuits {
    final calcul = DateTime.utc(au.year, au.month, au.day)
        .difference(DateTime.utc(du.year, du.month, du.day))
        .inDays;
    if (calcul > 0) return calcul;
    return _nuitsServeur ?? calcul;
  }

  /// Cle stable, pour fusionner deux morceaux de calendrier.
  String get cle => '${du.toIso8601String()}|${au.toIso8601String()}|$type';

  factory SejourAirbnb.fromJson(Map<String, dynamic> json) {
    return SejourAirbnb(
      id: _entier(json['id']),
      bienId: _entier(json['bienId']),
      bienTitre: _texte(json['bienTitre']),
      du: _jour(json['du']),
      au: _jour(json['au']),
      type: (json['type'] ?? 'reservation').toString(),
      resume: _texte(json['resume']),
      lien: _texte(json['lien']),
      code: _texte(json['code']),
      telephone4: _texte(json['telephone4']),
      bookingId: _entier(json['bookingId']),
      prixNuit: _nombre(json['prixNuit']),
      nuitsServeur: _entier(json['nuits']),
    );
  }
}

/// Un bien dans la vue d'ensemble Airbnb.
class BienAirbnb {
  final int bienId;
  final String titre;
  final bool relie;
  final DateTime? derniereSyncA;
  final String? statut;
  final String? erreur;
  final DateTime? derniereLectureAirbnbA;

  const BienAirbnb({
    required this.bienId,
    this.titre = '',
    this.relie = false,
    this.derniereSyncA,
    this.statut,
    this.erreur,
    this.derniereLectureAirbnbA,
  });

  bool get enErreur => statut == 'erreur';

  factory BienAirbnb.fromJson(Map<String, dynamic> json) {
    return BienAirbnb(
      bienId: (json['bienId'] as num?)?.toInt() ?? 0,
      titre: (json['titre'] ?? '').toString(),
      relie: json['relie'] == true,
      derniereSyncA: lireInstant(json['derniereSyncA']),
      statut: _texte(json['statut']),
      erreur: _texte(json['erreur']),
      derniereLectureAirbnbA: lireInstant(json['derniereLectureAirbnbA']),
    );
  }
}

String? _texte(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t.isEmpty ? null : t;
}

int? _entier(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString().trim() ?? '');
}

double? _nombre(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse((v?.toString().trim() ?? '').replaceAll(',', '.'));
}

DateTime _jour(dynamic v) {
  final d = DateTime.parse(v.toString());
  return DateTime(d.year, d.month, d.day);
}

/// Instant ISO du serveur, en heure locale.
DateTime? lireInstant(dynamic v) {
  final t = _texte(v);
  return t == null ? null : DateTime.tryParse(t)?.toLocal();
}
