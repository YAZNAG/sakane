/// L'historique de tous les appartements nettoyés, jour par jour.
///
/// Vient de « GET /activite/nettoyages?du=&au=&bien=&agent=&recherche= ».

library;

int _entier(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('${v ?? ''}'.trim()) ?? 0;
}

int? _entierOuNul(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  final texte = '$v'.trim();
  if (texte.isEmpty) return null;
  return int.tryParse(texte);
}

bool _booleen(dynamic v) =>
    v == true || v == 1 || v == '1' || '$v'.toLowerCase() == 'true';

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  final texte = '$v'.trim();
  if (texte.isEmpty) return null;
  // Le serveur peut envoyer « 2026-09-23 10:15:00 » : un espace au lieu du T.
  return DateTime.tryParse(texte.replaceFirst(' ', 'T'));
}

/// Le bandeau de totaux du haut de l'écran.
class TotauxNettoyage {
  /// Le nombre de nettoyages de la période.
  final int nombre;

  /// Le nombre d'appartements concernés.
  final int biens;

  /// Le temps total passé, en minutes.
  final int minutes;

  /// La durée moyenne d'un nettoyage, en minutes.
  final int moyenne;

  const TotauxNettoyage({
    this.nombre = 0,
    this.biens = 0,
    this.minutes = 0,
    this.moyenne = 0,
  });

  factory TotauxNettoyage.fromJson(Map<String, dynamic> json) =>
      TotauxNettoyage(
        nombre: _entier(json['nombre']),
        biens: _entier(json['biens']),
        minutes: _entier(json['minutes']),
        moyenne: _entier(json['moyenne']),
      );
}

/// Le résumé d'une journée, tel que le serveur le calcule.
class JourNettoyage {
  final DateTime? jour;
  final int nombre;
  final int biens;
  final int minutes;

  const JourNettoyage({
    this.jour,
    this.nombre = 0,
    this.biens = 0,
    this.minutes = 0,
  });

  factory JourNettoyage.fromJson(Map<String, dynamic> json) => JourNettoyage(
        jour: _date(json['jour']),
        nombre: _entier(json['nombre']),
        biens: _entier(json['biens']),
        minutes: _entier(json['minutes']),
      );

  /// La clé qui rapproche un nettoyage de sa journée.
  String get cle => jour == null
      ? 'sans-date'
      : '${jour!.year}-${jour!.month}-${jour!.day}';
}

/// Un nettoyage : l'appartement, la personne, le début et la fin.
class Nettoyage {
  final int id;
  final int? bienId;
  final String bien;
  final int? parId;
  final String par;
  final DateTime? debut;
  final DateTime? fin;
  final int? minutes;

  /// Un nettoyage commencé qui n'est pas terminé.
  final bool enCours;

  const Nettoyage({
    required this.id,
    this.bienId,
    this.bien = '',
    this.parId,
    this.par = '',
    this.debut,
    this.fin,
    this.minutes,
    this.enCours = false,
  });

  factory Nettoyage.fromJson(Map<String, dynamic> json) => Nettoyage(
        id: _entier(json['id']),
        bienId: _entierOuNul(json['bienId']),
        bien: (json['bien'] ?? '').toString().trim(),
        parId: _entierOuNul(json['parId']),
        par: (json['par'] ?? '').toString().trim(),
        debut: _date(json['debut']),
        fin: _date(json['fin']),
        minutes: _entierOuNul(json['minutes']),
        enCours: _booleen(json['enCours']),
      );

  /// La journée du nettoyage, à minuit.
  DateTime? get jour {
    final d = debut;
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  String get cleJour =>
      jour == null ? 'sans-date' : '${jour!.year}-${jour!.month}-${jour!.day}';
}

/// Une personne qui nettoie, pour la liste déroulante.
class PersonneNettoyage {
  final int id;
  final String nom;

  const PersonneNettoyage({required this.id, required this.nom});

  factory PersonneNettoyage.fromJson(Map<String, dynamic> json) =>
      PersonneNettoyage(
        id: _entier(json['id']),
        nom: (json['nom'] ?? '').toString().trim(),
      );
}

/// Un appartement de la liste déroulante. Le serveur ne renvoie pas de
/// catalogue de biens : on prend ceux qui apparaissent dans la période.
class BienNettoyage {
  final int id;
  final String nom;

  const BienNettoyage({required this.id, required this.nom});
}

class JournalNettoyage {
  final DateTime? du;
  final DateTime? au;
  final TotauxNettoyage totaux;
  final List<JourNettoyage> parJour;
  final List<Nettoyage> nettoyages;
  final List<PersonneNettoyage> personnes;

  const JournalNettoyage({
    this.du,
    this.au,
    this.totaux = const TotauxNettoyage(),
    this.parJour = const [],
    this.nettoyages = const [],
    this.personnes = const [],
  });

  factory JournalNettoyage.fromJson(dynamic brut) {
    dynamic corps = brut;
    if (corps is Map && corps['data'] != null) corps = corps['data'];
    if (corps is! Map) return const JournalNettoyage();
    final json = Map<String, dynamic>.from(corps);

    List<T> liste<T>(dynamic v, T Function(Map<String, dynamic>) lire) =>
        v is List
            ? v
                .whereType<Map>()
                .map((e) => lire(Map<String, dynamic>.from(e)))
                .toList()
            : <T>[];

    final jours = liste(json['parJour'], JourNettoyage.fromJson);
    // Du plus récent au plus ancien ; les journées sans date à la fin.
    jours.sort((a, b) {
      if (a.jour == null && b.jour == null) return 0;
      if (a.jour == null) return 1;
      if (b.jour == null) return -1;
      return b.jour!.compareTo(a.jour!);
    });

    final totaux = json['totaux'];
    return JournalNettoyage(
      du: _date(json['du']),
      au: _date(json['au']),
      totaux: totaux is Map
          ? TotauxNettoyage.fromJson(Map<String, dynamic>.from(totaux))
          : const TotauxNettoyage(),
      parJour: jours,
      nettoyages: liste(json['nettoyages'], Nettoyage.fromJson),
      personnes: liste(json['personnes'], PersonneNettoyage.fromJson),
    );
  }

  /// Les appartements présents dans la période, par ordre alphabétique.
  List<BienNettoyage> get biens {
    final parId = <int, String>{};
    for (final n in nettoyages) {
      final id = n.bienId;
      if (id == null || n.bien.isEmpty) continue;
      parId.putIfAbsent(id, () => n.bien);
    }
    final liste = parId.entries
        .map((e) => BienNettoyage(id: e.key, nom: e.value))
        .toList();
    liste.sort(
        (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return liste;
  }

  /// Les nettoyages d'une journée, du plus récent au plus ancien.
  List<Nettoyage> duJour(JourNettoyage jour) {
    final lignes =
        nettoyages.where((n) => n.cleJour == jour.cle).toList();
    lignes.sort((a, b) {
      if (a.debut == null && b.debut == null) return 0;
      if (a.debut == null) return 1;
      if (b.debut == null) return -1;
      return b.debut!.compareTo(a.debut!);
    });
    return lignes;
  }
}
