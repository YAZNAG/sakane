/// Les chiffres de la location longue duree, tels que le serveur les rend.
class StatistiquesBaux {
  final String du;
  final String au;
  final CompteBaux baux;
  final OccupationBaux occupation;
  final LoyersBaux loyers;
  final RetardBaux retard;
  final double depotsDetenus;
  final List<MoisBaux> parMois;
  final List<ModeBaux> parMode;
  final List<BienBaux> parBien;
  final List<RetardLocataire> retards;
  final List<EcheanceProche> prochainesEcheances;
  final List<FinProche> finsProches;

  const StatistiquesBaux({
    this.du = '',
    this.au = '',
    this.baux = const CompteBaux(),
    this.occupation = const OccupationBaux(),
    this.loyers = const LoyersBaux(),
    this.retard = const RetardBaux(),
    this.depotsDetenus = 0,
    this.parMois = const [],
    this.parMode = const [],
    this.parBien = const [],
    this.retards = const [],
    this.prochainesEcheances = const [],
    this.finsProches = const [],
  });

  factory StatistiquesBaux.fromJson(Map<String, dynamic> json) => StatistiquesBaux(
        du: _texte(json['du']) ?? '',
        au: _texte(json['au']) ?? '',
        baux: CompteBaux.fromJson(_objet(json['baux'])),
        occupation: OccupationBaux.fromJson(_objet(json['occupation'])),
        loyers: LoyersBaux.fromJson(_objet(json['loyers'])),
        retard: RetardBaux.fromJson(_objet(json['retard'])),
        depotsDetenus: _nombre(json['depotsDetenus']),
        parMois: _liste(json['parMois']).map(MoisBaux.fromJson).toList(),
        parMode: _liste(json['parMode']).map(ModeBaux.fromJson).toList(),
        parBien: _liste(json['parBien']).map(BienBaux.fromJson).toList(),
        retards: _liste(json['retards']).map(RetardLocataire.fromJson).toList(),
        prochainesEcheances:
            _liste(json['prochainesEcheances']).map(EcheanceProche.fromJson).toList(),
        finsProches: _liste(json['finsProches']).map(FinProche.fromJson).toList(),
      );

  /// Rien a montrer : ni bail, ni echeance sur la periode.
  bool get vide => baux.total == 0 && loyers.echeances == 0;
}

class CompteBaux {
  final int actifs;
  final int termines;
  final int total;
  final int nouveaux;
  final int finis;

  const CompteBaux({
    this.actifs = 0,
    this.termines = 0,
    this.total = 0,
    this.nouveaux = 0,
    this.finis = 0,
  });

  factory CompteBaux.fromJson(Map<String, dynamic> j) => CompteBaux(
        actifs: _entier(j['actifs']),
        termines: _entier(j['termines']),
        total: _entier(j['total']),
        nouveaux: _entier(j['nouveaux']),
        finis: _entier(j['finis']),
      );
}

class OccupationBaux {
  final int biens;
  final int loues;
  final int libres;
  final double taux;

  const OccupationBaux({this.biens = 0, this.loues = 0, this.libres = 0, this.taux = 0});

  factory OccupationBaux.fromJson(Map<String, dynamic> j) => OccupationBaux(
        biens: _entier(j['biens']),
        loues: _entier(j['loues']),
        libres: _entier(j['libres']),
        taux: _nombre(j['taux']),
      );
}

class LoyersBaux {
  final int echeances;
  final double appele;
  final double encaisse;
  final double impaye;
  final double recouvrement;
  final double mensuelAttendu;

  const LoyersBaux({
    this.echeances = 0,
    this.appele = 0,
    this.encaisse = 0,
    this.impaye = 0,
    this.recouvrement = 0,
    this.mensuelAttendu = 0,
  });

  factory LoyersBaux.fromJson(Map<String, dynamic> j) => LoyersBaux(
        echeances: _entier(j['echeances']),
        appele: _nombre(j['appele']),
        encaisse: _nombre(j['encaisse']),
        impaye: _nombre(j['impaye']),
        recouvrement: _nombre(j['recouvrement']),
        mensuelAttendu: _nombre(j['mensuelAttendu']),
      );
}

class RetardBaux {
  final int echeances;
  final double montant;

  const RetardBaux({this.echeances = 0, this.montant = 0});

  factory RetardBaux.fromJson(Map<String, dynamic> j) =>
      RetardBaux(echeances: _entier(j['echeances']), montant: _nombre(j['montant']));
}

class MoisBaux {
  final String mois;
  final int echeances;
  final double appele;
  final double encaisse;
  final double impaye;

  const MoisBaux({
    required this.mois,
    this.echeances = 0,
    this.appele = 0,
    this.encaisse = 0,
    this.impaye = 0,
  });

  factory MoisBaux.fromJson(Map<String, dynamic> j) => MoisBaux(
        mois: _texte(j['mois']) ?? '',
        echeances: _entier(j['echeances']),
        appele: _nombre(j['appele']),
        encaisse: _nombre(j['encaisse']),
        impaye: _nombre(j['impaye']),
      );

  /// « 2026-03 » devient « Mars ».
  String get libelle {
    final bouts = mois.split('-');
    if (bouts.length != 2) return mois;
    final n = int.tryParse(bouts[1]) ?? 0;
    const noms = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    return n >= 1 && n <= 12 ? noms[n - 1] : mois;
  }
}

class ModeBaux {
  final String mode;
  final int nombre;
  final double total;

  const ModeBaux({required this.mode, this.nombre = 0, this.total = 0});

  factory ModeBaux.fromJson(Map<String, dynamic> j) => ModeBaux(
        mode: _texte(j['mode']) ?? 'especes',
        nombre: _entier(j['nombre']),
        total: _nombre(j['total']),
      );

  String get libelle {
    switch (mode) {
      case 'especes':
        return 'Espèces';
      case 'virement':
        return 'Virement';
      case 'cheque':
        return 'Chèque';
      case 'carte':
        return 'Carte';
      default:
        return mode;
    }
  }
}

class BienBaux {
  final int id;
  final String bien;
  final int echeances;
  final double appele;
  final double encaisse;
  final double retard;

  const BienBaux({
    required this.id,
    required this.bien,
    this.echeances = 0,
    this.appele = 0,
    this.encaisse = 0,
    this.retard = 0,
  });

  factory BienBaux.fromJson(Map<String, dynamic> j) => BienBaux(
        id: _entier(j['id']),
        bien: _texte(j['bien']) ?? 'Bien',
        echeances: _entier(j['echeances']),
        appele: _nombre(j['appele']),
        encaisse: _nombre(j['encaisse']),
        retard: _nombre(j['retard']),
      );
}

class RetardLocataire {
  final int bailId;
  final String? bien;
  final String? locataire;
  final String? telephone;
  final int echeances;
  final double montant;
  final String? depuis;
  final int? jours;

  const RetardLocataire({
    required this.bailId,
    this.bien,
    this.locataire,
    this.telephone,
    this.echeances = 0,
    this.montant = 0,
    this.depuis,
    this.jours,
  });

  factory RetardLocataire.fromJson(Map<String, dynamic> j) => RetardLocataire(
        bailId: _entier(j['bailId']),
        bien: _texte(j['bien']),
        locataire: _texte(j['locataire']),
        telephone: _texte(j['telephone']),
        echeances: _entier(j['echeances']),
        montant: _nombre(j['montant']),
        depuis: _texte(j['depuis']),
        jours: j['jours'] == null ? null : _entier(j['jours']),
      );
}

class EcheanceProche {
  final int loyerId;
  final int bailId;
  final String? bien;
  final String? echeance;
  final double reste;

  const EcheanceProche({
    required this.loyerId,
    required this.bailId,
    this.bien,
    this.echeance,
    this.reste = 0,
  });

  factory EcheanceProche.fromJson(Map<String, dynamic> j) => EcheanceProche(
        loyerId: _entier(j['loyerId']),
        bailId: _entier(j['bailId']),
        bien: _texte(j['bien']),
        echeance: _texte(j['echeance']),
        reste: _nombre(j['reste']),
      );
}

class FinProche {
  final int bailId;
  final String? bien;
  final String? dateFin;
  final int jours;

  const FinProche({required this.bailId, this.bien, this.dateFin, this.jours = 0});

  factory FinProche.fromJson(Map<String, dynamic> j) => FinProche(
        bailId: _entier(j['bailId']),
        bien: _texte(j['bien']),
        dateFin: _texte(j['dateFin']),
        jours: _entier(j['jours']),
      );
}

// ── Lecture prudente du JSON ─────────────────────────────────────────
Map<String, dynamic> _objet(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _liste(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

String? _texte(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _entier(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('${v ?? ''}') ?? 0;
}

double _nombre(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
}
