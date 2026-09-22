// Location longue duree : bail, echeancier mensuel et paiements.
//
// Les montants sont en MAD, les dates du serveur au format AAAA-MM-JJ.

double _montant(dynamic v) => (v as num?)?.toDouble() ?? 0;

double? _montantOuNull(dynamic v) => (v as num?)?.toDouble();

int? _entier(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

DateTime? _date(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String? _texte(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty) ? null : t;
}

Map<String, dynamic>? _objet(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> _liste(dynamic v) =>
    (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// Liste d'adresses d'images : chaines, ou objets avec une url.
List<String> _urls(dynamic v) => (v as List? ?? const [])
    .map((e) => e is Map ? _texte(e['url']) : _texte(e))
    .whereType<String>()
    .toList();

/// Une personne qui habite le logement avec le locataire.
class Colocataire {
  final String nom;
  final String? cin;
  final String? tel;
  final String? lien;

  const Colocataire({required this.nom, this.cin, this.tel, this.lien});

  factory Colocataire.fromJson(Map<String, dynamic> json) => Colocataire(
        nom: _texte(json['nom']) ?? '',
        cin: _texte(json['cin']),
        tel: _texte(json['tel']),
        lien: _texte(json['lien']),
      );

  Map<String, String> toJson() => {
        'nom': nom.trim(),
        if ((cin ?? '').trim().isNotEmpty) 'cin': cin!.trim(),
        if ((tel ?? '').trim().isNotEmpty) 'tel': tel!.trim(),
        if ((lien ?? '').trim().isNotEmpty) 'lien': lien!.trim(),
      };
}

class BienBail {
  final int id;
  final String titre;
  final String? adresse;
  final String? photo;

  const BienBail({required this.id, this.titre = '', this.adresse, this.photo});

  factory BienBail.fromJson(Map<String, dynamic> json) => BienBail(
        id: _entier(json['id']) ?? 0,
        titre: _texte(json['titre']) ?? 'Bien',
        adresse: _texte(json['adresse']),
        photo: _texte(json['photo']),
      );
}

class PersonneBail {
  final int id;
  final String nom;
  final String? tel;
  final String? cin;

  /// Vrai si le locataire est sur liste noire.
  final bool listeNoire;
  final String? motifListeNoire;

  const PersonneBail({
    required this.id,
    this.nom = '',
    this.tel,
    this.cin,
    this.listeNoire = false,
    this.motifListeNoire,
  });

  factory PersonneBail.fromJson(Map<String, dynamic> json) {
    final ln = json['listeNoire'];
    return PersonneBail(
      id: _entier(json['id']) ?? 0,
      nom: _texte(json['nom']) ?? '',
      tel: _texte(json['tel']),
      cin: _texte(json['cin']),
      listeNoire: ln != null && ln != false && ln != 0,
      motifListeNoire: ln is Map ? _texte(ln['motif']) : (ln is String ? _texte(ln) : null),
    );
  }
}

class PaiementLoyer {
  final int id;
  final double montant;
  final DateTime? payeLe;
  final String mode;
  final String? modeLibelle;
  final String? reference;
  final String? remarque;
  final String? par;
  final String? quittanceUrl;
  final String? quittanceEnvoyeeLe;
  final bool annule;
  final String? annuleLe;
  final String? motifAnnulation;

  const PaiementLoyer({
    required this.id,
    this.montant = 0,
    this.payeLe,
    this.mode = 'especes',
    this.modeLibelle,
    this.reference,
    this.remarque,
    this.par,
    this.quittanceUrl,
    this.quittanceEnvoyeeLe,
    this.annule = false,
    this.annuleLe,
    this.motifAnnulation,
  });

  String get libelleMode => modeLibelle ?? libelleModePaiement(mode);

  factory PaiementLoyer.fromJson(Map<String, dynamic> json) => PaiementLoyer(
        id: _entier(json['id']) ?? 0,
        montant: _montant(json['montant']),
        payeLe: _date(json['payeLe']),
        mode: _texte(json['mode']) ?? 'especes',
        modeLibelle: _texte(json['modeLibelle']),
        reference: _texte(json['reference']),
        remarque: _texte(json['remarque']),
        par: _texte(json['par']),
        quittanceUrl: _texte(json['quittanceUrl']),
        quittanceEnvoyeeLe: _texte(json['quittanceEnvoyeeLe']),
        annule: json['annule'] == true || json['annule'] == 1,
        annuleLe: _texte(json['annuleLe']),
        motifAnnulation: _texte(json['motifAnnulation']),
      );
}

String libelleModePaiement(String mode) {
  switch (mode) {
    case 'virement':
      return 'Virement';
    case 'cheque':
      return 'Chèque';
    default:
      return 'Espèces';
  }
}

/// Une echeance mensuelle. Statut : paye, partiel, en_retard, a_payer, a_venir.
class Loyer {
  final int id;
  final int bailId;
  final String libelle;
  final DateTime? periodeDebut;
  final DateTime? periodeFin;
  final DateTime? echeance;
  final double montant;
  final double paye;
  final double reste;
  final String statut;
  final List<PaiementLoyer> paiements;

  /// Presents dans les « prochaines echeances » du tableau de bord.
  final String? locataire;
  final String? bien;
  final String? tel;

  const Loyer({
    required this.id,
    this.bailId = 0,
    this.libelle = '',
    this.periodeDebut,
    this.periodeFin,
    this.echeance,
    this.montant = 0,
    this.paye = 0,
    this.reste = 0,
    this.statut = 'a_venir',
    this.paiements = const [],
    this.locataire,
    this.bien,
    this.tel,
  });

  bool get solde => statut == 'paye' || reste <= 0.004;

  factory Loyer.fromJson(Map<String, dynamic> json) {
    final loc = json['locataire'];
    final bien = json['bien'];
    return Loyer(
      id: _entier(json['id']) ?? 0,
      bailId: _entier(json['bailId']) ?? 0,
      libelle: _texte(json['libelle']) ?? '',
      periodeDebut: _date(json['periodeDebut']),
      periodeFin: _date(json['periodeFin']),
      echeance: _date(json['echeance']),
      montant: _montant(json['montant']),
      paye: _montant(json['paye']),
      reste: _montant(json['reste']),
      statut: _texte(json['statut']) ?? 'a_venir',
      paiements: _liste(json['paiements']).map(PaiementLoyer.fromJson).toList(),
      locataire: loc is Map ? _texte(loc['nom']) : _texte(loc),
      tel: loc is Map ? _texte(loc['tel']) : _texte(json['tel']),
      bien: bien is Map ? _texte(bien['titre']) : _texte(bien),
    );
  }
}

class ResumeBail {
  final double totalDu;
  final double totalPaye;
  final double resteDu;
  final double enRetard;
  final int echeances;
  final Loyer? prochainLoyer;

  const ResumeBail({
    this.totalDu = 0,
    this.totalPaye = 0,
    this.resteDu = 0,
    this.enRetard = 0,
    this.echeances = 0,
    this.prochainLoyer,
  });

  factory ResumeBail.fromJson(Map<String, dynamic> json) {
    final prochain = _objet(json['prochainLoyer']);
    return ResumeBail(
      totalDu: _montant(json['totalDu']),
      totalPaye: _montant(json['totalPaye']),
      resteDu: _montant(json['resteDu']),
      enRetard: _montant(json['enRetard']),
      echeances: _entier(json['echeances']) ?? 0,
      prochainLoyer: prochain == null ? null : Loyer.fromJson(prochain),
    );
  }
}

/// depotStatut : non_recu, recu, restitue.
class Bail {
  final int id;
  final String statut;
  final BienBail bien;
  final PersonneBail locataire;
  final PersonneBail? proprietaire;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final int dureeMois;
  final double loyer;
  final double charges;
  final double montantMensuel;
  final double depot;
  final String depotStatut;
  final double? depotRendu;
  final bool relancesActives;
  final DateTime? termineLe;
  final String? motifFin;
  final int? joursRestants;
  final ResumeBail resume;

  // Fiche complete uniquement.
  final String? compteurEauEntree;
  final String? compteurElecEntree;
  final String? compteurEauSortie;
  final String? compteurElecSortie;
  final String? remarques;
  final String? contratUrl;
  final String? creePar;
  final String? creeLe;
  final List<Loyer>? loyers;
  final List<Colocataire> colocataires;
  final List<String> cinPhotos;
  final List<String> etatLieuxPhotos;

  const Bail({
    required this.id,
    this.statut = 'actif',
    required this.bien,
    required this.locataire,
    this.proprietaire,
    this.dateDebut,
    this.dateFin,
    this.dureeMois = 0,
    this.loyer = 0,
    this.charges = 0,
    this.montantMensuel = 0,
    this.depot = 0,
    this.depotStatut = 'non_recu',
    this.depotRendu,
    this.relancesActives = true,
    this.termineLe,
    this.motifFin,
    this.joursRestants,
    this.resume = const ResumeBail(),
    this.compteurEauEntree,
    this.compteurElecEntree,
    this.compteurEauSortie,
    this.compteurElecSortie,
    this.remarques,
    this.contratUrl,
    this.creePar,
    this.creeLe,
    this.loyers,
    this.colocataires = const [],
    this.cinPhotos = const [],
    this.etatLieuxPhotos = const [],
  });

  bool get actif => statut == 'actif';
  bool get aJour => resume.resteDu <= 0.004 && resume.enRetard <= 0.004;

  String get libelleDepot {
    switch (depotStatut) {
      case 'recu':
        return 'Dépôt reçu';
      case 'restitue':
        return 'Dépôt restitué';
      default:
        return 'Dépôt non reçu';
    }
  }

  /// Aucun paiement actif et depot non encaisse : le serveur accepte la suppression.
  bool get supprimable =>
      depotStatut == 'non_recu' &&
      resume.totalPaye <= 0.004 &&
      (loyers ?? const <Loyer>[]).every((l) => l.paiements.every((p) => p.annule));

  factory Bail.fromJson(Map<String, dynamic> json) {
    final proprio = _objet(json['proprietaire']);
    final resume = _objet(json['resume']);
    return Bail(
      id: _entier(json['id']) ?? 0,
      statut: _texte(json['statut']) ?? 'actif',
      bien: BienBail.fromJson(_objet(json['bien']) ?? const {}),
      locataire: PersonneBail.fromJson(_objet(json['locataire']) ?? const {}),
      proprietaire: proprio == null ? null : PersonneBail.fromJson(proprio),
      dateDebut: _date(json['dateDebut']),
      dateFin: _date(json['dateFin']),
      dureeMois: _entier(json['dureeMois']) ?? 0,
      loyer: _montant(json['loyer']),
      charges: _montant(json['charges']),
      montantMensuel: _montant(json['montantMensuel']),
      depot: _montant(json['depot']),
      depotStatut: _texte(json['depotStatut']) ?? 'non_recu',
      depotRendu: _montantOuNull(json['depotRendu']),
      relancesActives: json['relancesActives'] == true || json['relancesActives'] == 1,
      termineLe: _date(json['termineLe']),
      motifFin: _texte(json['motifFin']),
      joursRestants: _entier(json['joursRestants']),
      resume: resume == null ? const ResumeBail() : ResumeBail.fromJson(resume),
      compteurEauEntree: _texte(json['compteurEauEntree']),
      compteurElecEntree: _texte(json['compteurElecEntree']),
      compteurEauSortie: _texte(json['compteurEauSortie']),
      compteurElecSortie: _texte(json['compteurElecSortie']),
      remarques: _texte(json['remarques']),
      contratUrl: _texte(json['contratUrl']),
      creePar: _texte(json['creePar']),
      creeLe: _texte(json['creeLe']),
      loyers: json['loyers'] is List ? _liste(json['loyers']).map(Loyer.fromJson).toList() : null,
      colocataires:
          _liste(json['colocataires']).map(Colocataire.fromJson).where((c) => c.nom.isNotEmpty).toList(),
      cinPhotos: _urls(json['cinPhotos']),
      etatLieuxPhotos: _urls(json['etatLieuxPhotos']),
    );
  }
}

/// Reponse d'une ecriture : l'objet et l'eventuel avertissement du serveur.
class AvecAvertissement<T> {
  final T valeur;
  final String? avertissement;

  const AvecAvertissement(this.valeur, this.avertissement);
}

class PaiementEnregistre {
  final Loyer loyer;
  final PaiementLoyer paiement;
  final String? avertissement;

  const PaiementEnregistre({required this.loyer, required this.paiement, this.avertissement});
}

class ImpayeBail {
  final int bailId;
  final String locataire;
  final String? tel;
  final String bien;
  final int mois;
  final double reste;
  final DateTime? plusAncien;

  const ImpayeBail({
    required this.bailId,
    this.locataire = '',
    this.tel,
    this.bien = '',
    this.mois = 0,
    this.reste = 0,
    this.plusAncien,
  });

  factory ImpayeBail.fromJson(Map<String, dynamic> json) => ImpayeBail(
        bailId: _entier(json['bailId']) ?? 0,
        locataire: _nom(json['locataire']),
        tel: _texte(json['tel']) ?? (json['locataire'] is Map ? _texte(json['locataire']['tel']) : null),
        bien: _titre(json['bien']),
        mois: _entier(json['mois']) ?? 0,
        reste: _montant(json['reste']),
        plusAncien: _date(json['plusAncien']),
      );
}

class BailFinissant {
  final int bailId;
  final String locataire;
  final String bien;
  final DateTime? dateFin;
  final int? joursRestants;

  const BailFinissant({
    required this.bailId,
    this.locataire = '',
    this.bien = '',
    this.dateFin,
    this.joursRestants,
  });

  factory BailFinissant.fromJson(Map<String, dynamic> json) => BailFinissant(
        bailId: _entier(json['bailId']) ?? 0,
        locataire: _nom(json['locataire']),
        bien: _titre(json['bien']),
        dateFin: _date(json['dateFin']),
        joursRestants: _entier(json['joursRestants']),
      );
}

String _nom(dynamic v) => v is Map ? (_texte(v['nom']) ?? '') : (_texte(v) ?? '');

String _titre(dynamic v) => v is Map ? (_texte(v['titre']) ?? '') : (_texte(v) ?? '');

class TableauBaux {
  final int bauxActifs;
  final int biens;
  final int biensLibres;
  final double impayesTotal;
  final int impayesLocataires;
  final double attenduMois;
  final double encaisseMois;
  final double? tauxRecouvrementMois;
  final List<ImpayeBail> impayes;
  final List<BailFinissant> finissants;
  final List<Loyer> prochainesEcheances;

  const TableauBaux({
    this.bauxActifs = 0,
    this.biens = 0,
    this.biensLibres = 0,
    this.impayesTotal = 0,
    this.impayesLocataires = 0,
    this.attenduMois = 0,
    this.encaisseMois = 0,
    this.tauxRecouvrementMois,
    this.impayes = const [],
    this.finissants = const [],
    this.prochainesEcheances = const [],
  });

  factory TableauBaux.fromJson(Map<String, dynamic> json) => TableauBaux(
        bauxActifs: _entier(json['bauxActifs']) ?? 0,
        biens: _entier(json['biens']) ?? 0,
        biensLibres: _entier(json['biensLibres']) ?? 0,
        impayesTotal: _montant(json['impayesTotal']),
        impayesLocataires: _entier(json['impayesLocataires']) ?? 0,
        attenduMois: _montant(json['attenduMois']),
        encaisseMois: _montant(json['encaisseMois']),
        tauxRecouvrementMois: _montantOuNull(json['tauxRecouvrementMois']),
        impayes: _liste(json['impayes']).map(ImpayeBail.fromJson).toList(),
        finissants: _liste(json['finissants']).map(BailFinissant.fromJson).toList(),
        prochainesEcheances: _liste(json['prochainesEcheances']).map(Loyer.fromJson).toList(),
      );
}

class BailDuBien {
  final int id;
  final String locataire;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final bool enCours;

  /// Loyer et charges du mois, quand le serveur les donne.
  final double? montantMensuel;

  const BailDuBien({
    required this.id,
    this.locataire = '',
    this.dateDebut,
    this.dateFin,
    this.enCours = false,
    this.montantMensuel,
  });

  factory BailDuBien.fromJson(Map<String, dynamic> json) => BailDuBien(
        id: _entier(json['id']) ?? 0,
        locataire: _nom(json['locataire']),
        dateDebut: _date(json['dateDebut']),
        dateFin: _date(json['dateFin']),
        enCours: json['enCours'] == true || json['enCours'] == 1,
        montantMensuel: _montantOuNull(json['montantMensuel']) ?? _montantOuNull(json['loyer']),
      );
}

/// Un logement proposé en location longue durée.
class BienLongueDuree {
  final int id;
  final String titre;
  final String? adresse;
  final String? photo;
  final double? loyerPropose;
  final BailDuBien? bail;

  const BienLongueDuree({
    required this.id,
    this.titre = '',
    this.adresse,
    this.photo,
    this.loyerPropose,
    this.bail,
  });

  bool get libre => bail == null;

  /// Le loyer a afficher : celui du bail en cours, sinon le loyer propose.
  double? get loyerAffiche => bail?.montantMensuel ?? loyerPropose;

  factory BienLongueDuree.fromJson(Map<String, dynamic> json) {
    final bail = _objet(json['bail']);
    return BienLongueDuree(
      id: _entier(json['id']) ?? 0,
      titre: _texte(json['titre']) ?? 'Bien',
      adresse: _texte(json['adresse']),
      photo: _texte(json['photo']),
      loyerPropose: _montantOuNull(json['loyerPropose']),
      bail: bail == null ? null : BailDuBien.fromJson(bail),
    );
  }
}
