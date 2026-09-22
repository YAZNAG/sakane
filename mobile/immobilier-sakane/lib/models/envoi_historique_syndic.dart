/// Historique des envois du contrat aux syndics, groupe par mois puis
/// par jour, tel que le serveur le renvoie.
///
/// Tout est lu de facon defensive : un champ absent, un nombre envoye
/// sous forme de texte, un groupe rendu en objet plutot qu'en liste ou
/// une ligne illisible ne doivent jamais vider l'ecran.
class HistoriqueEnvoisSyndic {
  final String? du;
  final String? au;
  final int total;
  final int envoyes;
  final int echecs;
  final int ignores;
  final List<MoisEnvoisSyndic> mois;

  const HistoriqueEnvoisSyndic({
    this.du,
    this.au,
    this.total = 0,
    this.envoyes = 0,
    this.echecs = 0,
    this.ignores = 0,
    this.mois = const [],
  });

  factory HistoriqueEnvoisSyndic.fromJson(Map<String, dynamic> json) {
    final mois = _liste(json['mois'], MoisEnvoisSyndic.fromJson, cle: 'mois');
    final envois = [
      for (final m in mois)
        for (final j in m.jours) ...j.envois,
    ];
    int compte(String statut) => envois.where((e) => e.statut == statut).length;
    return HistoriqueEnvoisSyndic(
      du: _texte(json['du']),
      au: _texte(json['au']),
      total: _entierOuNull(json['total']) ?? envois.length,
      envoyes: _entierOuNull(json['envoyes']) ?? compte('envoye'),
      echecs: _entierOuNull(json['echecs']) ?? compte('echec'),
      ignores: _entierOuNull(json['ignores']) ?? compte('ignore'),
      mois: mois,
    );
  }

  /// Tous les envois de la periode, mois et jours confondus.
  List<EnvoiHistoriqueSyndic> get tousLesEnvois => [
        for (final m in mois)
          for (final j in m.jours) ...j.envois,
      ];

  /// Le nombre de lignes reellement recues. L'ecran ne se declare vide
  /// que lorsqu'il vaut zero : un compteur a zero alors que des lignes
  /// arrivent (ou l'inverse) ne doit pas masquer l'historique.
  int get nombreEnvois => tousLesEnvois.length;

  /// Les compteurs affiches : ceux du serveur, sauf s'il n'en renvoie
  /// aucun alors que des lignes existent.
  int get totalAffiche => total > 0 ? total : nombreEnvois;

  DateTime? get debut => _date(du);

  DateTime? get fin => _date(au);
}

class MoisEnvoisSyndic {
  final String mois;
  final String libelle;
  final int total;
  final int envoyes;
  final int echecs;
  final List<JourEnvoisSyndic> jours;

  const MoisEnvoisSyndic({
    required this.mois,
    required this.libelle,
    this.total = 0,
    this.envoyes = 0,
    this.echecs = 0,
    this.jours = const [],
  });

  factory MoisEnvoisSyndic.fromJson(Map<String, dynamic> json) {
    final cle = _texte(json['mois']) ?? '';
    final jours = _liste(json['jours'], JourEnvoisSyndic.fromJson, cle: 'jour');
    final envois = [for (final j in jours) ...j.envois];
    int compte(String statut) => envois.where((e) => e.statut == statut).length;
    return MoisEnvoisSyndic(
      mois: cle,
      libelle: _texte(json['libelle']) ?? _libelleMois(cle),
      total: _entierOuNull(json['total']) ?? envois.length,
      envoyes: _entierOuNull(json['envoyes']) ?? compte('envoye'),
      echecs: _entierOuNull(json['echecs']) ?? compte('echec'),
      jours: jours,
    );
  }

  int get nombreEnvois => [for (final j in jours) ...j.envois].length;
}

class JourEnvoisSyndic {
  final String jour;
  final String libelle;
  final int total;
  final List<EnvoiHistoriqueSyndic> envois;

  const JourEnvoisSyndic({
    required this.jour,
    required this.libelle,
    this.total = 0,
    this.envois = const [],
  });

  factory JourEnvoisSyndic.fromJson(Map<String, dynamic> json) {
    final cle = _texte(json['jour']) ?? '';
    final envois = _liste(json['envois'], EnvoiHistoriqueSyndic.fromJson);
    return JourEnvoisSyndic(
      jour: cle,
      libelle: _texte(json['libelle']) ?? _libelleJour(cle),
      total: _entierOuNull(json['total']) ?? envois.length,
      envois: envois,
    );
  }
}

/// Un envoi du contrat a un syndic, avec le message qui l'accompagnait.
class EnvoiHistoriqueSyndic {
  final int id;
  final DateTime? date;
  final int? syndicId;
  final String? syndicNom;
  final String? telephone;

  /// envoye, echec, ignore… (valeur libre : un statut inconnu de
  /// l'application s'affiche avec son statutLibelle).
  final String statut;
  final String? statutLibelle;
  final String? erreur;

  /// auto, manuel, renvoi, prolongation, raccourcissement… (valeur libre :
  /// une source inconnue s'affiche avec son sourceLibelle).
  final String source;
  final String? sourceLibelle;
  final String? envoyePar;
  final String? message;
  final ReservationEnvoiSyndic? reservation;
  final String? contratUrl;

  const EnvoiHistoriqueSyndic({
    required this.id,
    this.date,
    this.syndicId,
    this.syndicNom,
    this.telephone,
    required this.statut,
    this.statutLibelle,
    this.erreur,
    this.source = '',
    this.sourceLibelle,
    this.envoyePar,
    this.message,
    this.reservation,
    this.contratUrl,
  });

  factory EnvoiHistoriqueSyndic.fromJson(Map<String, dynamic> json) {
    final syndic = _carte(json['syndic']);
    final reservation = _carte(json['reservation']);
    return EnvoiHistoriqueSyndic(
      id: _entier(json['id']),
      date: _date(json['date'] ?? json['createdAt'] ?? json['created_at']),
      syndicId: syndic == null ? null : _entierOuNull(syndic['id']),
      syndicNom: syndic == null ? null : _texte(syndic['nom'] ?? syndic['name']),
      telephone: _texte(json['telephone'] ?? json['phone']),
      statut: _cle(json['statut']),
      statutLibelle: _texte(json['statutLibelle'] ?? json['statut_libelle']),
      erreur: _texte(json['erreur'] ?? json['error']),
      source: _cle(json['source']),
      sourceLibelle: _texte(json['sourceLibelle'] ?? json['source_libelle']),
      envoyePar: _personne(json['envoyePar'] ?? json['envoye_par']),
      message: _texte(json['message']),
      reservation:
          reservation == null ? null : ReservationEnvoiSyndic.fromJson(reservation),
      contratUrl: _texte(json['contratUrl'] ?? json['contrat_url']),
    );
  }

  /// Le contrat n'est consultable que si le serveur en donne l'adresse :
  /// une reservation supprimee, par exemple, n'en a plus.
  bool get aUnContrat => (contratUrl ?? '').isNotEmpty;
}

class ReservationEnvoiSyndic {
  final int? id;
  final String? checkin;
  final String? checkout;
  final String? client;
  final String? bien;
  final bool supprimee;

  const ReservationEnvoiSyndic({
    this.id,
    this.checkin,
    this.checkout,
    this.client,
    this.bien,
    this.supprimee = false,
  });

  factory ReservationEnvoiSyndic.fromJson(Map<String, dynamic> json) {
    return ReservationEnvoiSyndic(
      id: _entierOuNull(json['id']),
      checkin: _texte(json['checkin'] ?? json['check_in']),
      checkout: _texte(json['checkout'] ?? json['check_out']),
      client: _personne(json['client']),
      bien: _personne(json['bien']),
      supprimee: _vrai(json['supprimee'] ?? json['supprime'] ?? json['deleted']),
    );
  }
}

// ── Lecture defensive ────────────────────────────────────────────────

int _entier(dynamic v) => _entierOuNull(v) ?? 0;

/// Accepte 12, 12.0, « 12 », « 12,5 » ; rend null pour le reste.
int? _entierOuNull(dynamic v) {
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  final texte = _texte(v);
  if (texte == null) return null;
  return int.tryParse(texte) ?? double.tryParse(texte.replaceAll(',', '.'))?.toInt();
}

String? _texte(dynamic v) {
  if (v == null || v is Map || v is List) return null;
  final t = v.toString().trim();
  return t.isEmpty || t == 'null' ? null : t;
}

/// Une cle technique (statut, source) : toujours comparee en minuscules.
String _cle(dynamic v) => (_texte(v) ?? '').toLowerCase();

bool _vrai(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final t = _texte(v)?.toLowerCase();
  return t == 'true' || t == '1' || t == 'oui' || t == 'yes';
}

Map<String, dynamic>? _carte(dynamic v) {
  if (v is! Map) return null;
  try {
    return Map<String, dynamic>.from(v);
  } catch (_) {
    return null;
  }
}

/// Un nom qui peut arriver en texte ou en objet ({nom}, {name}, {titre}…).
String? _personne(dynamic v) {
  if (v is Map) {
    final carte = _carte(v);
    if (carte == null) return null;
    return _texte(carte['nom'] ??
        carte['name'] ??
        carte['titre'] ??
        carte['title'] ??
        carte['libelle']);
  }
  return _texte(v);
}

DateTime? _date(dynamic v) {
  final texte = _texte(v);
  if (texte == null) return null;
  final d = DateTime.tryParse(texte);
  if (d != null) return d.isUtc ? d.toLocal() : d;
  // « 19/09/2026 » ou « 19-09-2026 »
  final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(texte);
  if (m == null) return null;
  return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
}

/// Les groupes arrivent normalement en liste. Un serveur qui rend un
/// objet (« 2026-09 » : {…}) est accepte aussi : la cle sert alors de
/// valeur au champ [cle] quand il manque.
List<T> _liste<T>(
  dynamic brut,
  T Function(Map<String, dynamic>) lire, {
  String? cle,
}) {
  final cartes = <Map<String, dynamic>>[];
  if (brut is List) {
    for (final e in brut) {
      final carte = _carte(e);
      if (carte != null) cartes.add(carte);
    }
  } else if (brut is Map) {
    for (final entree in brut.entries) {
      final carte = _carte(entree.value);
      if (carte == null) continue;
      if (cle != null && _texte(carte[cle]) == null) carte[cle] = entree.key;
      cartes.add(carte);
    }
  } else {
    return const [];
  }

  final resultat = <T>[];
  for (final carte in cartes) {
    try {
      resultat.add(lire(carte));
    } catch (_) {
      // Une ligne illisible ne doit pas faire disparaitre les autres
    }
  }
  return resultat;
}

const _nomsMois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

const _nomsJours = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// « 2026-09 » → « Septembre 2026 », quand le serveur n'a pas envoye
/// de libelle.
String _libelleMois(String iso) {
  final d = DateTime.tryParse(iso.length == 7 ? '$iso-01' : iso);
  if (d == null) return iso;
  final nom = _nomsMois[d.month - 1];
  return '${nom[0].toUpperCase()}${nom.substring(1)} ${d.year}';
}

/// « 2026-09-19 » → « Samedi 19 septembre ».
String _libelleJour(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_nomsJours[d.weekday - 1]} ${d.day} ${_nomsMois[d.month - 1]}';
}
