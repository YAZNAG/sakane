// Vente de biens : dossier de vente, mandats (عقد وساطة عقارية) et visites.
//
// Les montants sont en MAD, les dates du serveur au format AAAA-MM-JJ.

double? _montantOuNull(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));

int? _entier(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

DateTime? _date(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

DateTime? _instant(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

String? _texte(dynamic v) {
  final t = v?.toString().trim();
  return (t == null || t.isEmpty) ? null : t;
}

bool _vrai(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

Map<String, dynamic>? _objet(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

List<Map<String, dynamic>> _liste(dynamic v) =>
    (v as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

Map<String, String> _dictionnaire(dynamic v) {
  if (v is! Map) return const {};
  return {
    for (final e in v.entries)
      if (_texte(e.key) != null) e.key.toString(): _texte(e.value) ?? e.key.toString(),
  };
}

/// Statuts de vente connus du serveur.
class StatutVente {
  static const String aVendre = 'a_vendre';
  static const String compromis = 'compromis';
  static const String vendu = 'vendu';

  static const Map<String, String> libelles = {
    aVendre: 'À vendre',
    compromis: 'Sous compromis',
    vendu: 'Vendu',
  };

  static String libelle(String? code) => libelles[code] ?? 'À vendre';
}

/// Suites possibles d'une visite.
class SuiteVisite {
  static const Map<String, String> libelles = {
    'interesse': 'Intéressé',
    'a_relancer': 'À relancer',
    'offre': 'Offre faite',
    'pas_interesse': 'Pas intéressé',
  };

  static String libelle(String? code) => libelles[code] ?? (code ?? '');
}

class ProprietaireVente {
  final int? id;
  final String nom;
  final String? tel;

  const ProprietaireVente({this.id, this.nom = '', this.tel});

  factory ProprietaireVente.fromJson(Map<String, dynamic> json) => ProprietaireVente(
        id: _entier(json['id']),
        nom: _texte(json['nom']) ?? '',
        tel: _texte(json['tel']),
      );
}

/// Mandat de vente signe par le proprietaire.
class MandatVente {
  final int id;
  final int? bienId;
  final String proprietaireNom;
  final String? proprietaireCin;
  final String? proprietaireNationalite;
  final String? proprietaireAdresse;
  final String? proprietaireTel;
  final String? typeBien;
  final String? ville;
  final double? surface;
  final String? titreFoncier;
  final String? adresseBien;
  final double? prixDemande;
  final double? commission;
  final int? dureeMois;
  final DateTime? dateSignature;
  final DateTime? dateFin;
  final bool actif;
  final int? joursRestants;
  final String? remarques;
  final DateTime? creeLe;

  /// Proprietaire (fiche owner) auquel le mandat est rattache.
  final int? ownerId;

  /// Signature du proprietaire recueillie dans l'application.
  final bool signe;
  final DateTime? signeLe;

  /// Le bien lie au mandat ; null pour un mandat encore libre.
  final BienDeVisite? bien;

  const MandatVente({
    required this.id,
    this.bienId,
    this.proprietaireNom = '',
    this.proprietaireCin,
    this.proprietaireNationalite,
    this.proprietaireAdresse,
    this.proprietaireTel,
    this.typeBien,
    this.ville,
    this.surface,
    this.titreFoncier,
    this.adresseBien,
    this.prixDemande,
    this.commission,
    this.dureeMois,
    this.dateSignature,
    this.dateFin,
    this.actif = false,
    this.joursRestants,
    this.remarques,
    this.creeLe,
    this.ownerId,
    this.signe = false,
    this.signeLe,
    this.bien,
  });

  /// Libre : pas encore lie a un bien.
  bool get libre => bienId == null && bien == null;

  factory MandatVente.fromJson(Map<String, dynamic> json) {
    final bien = json['bien'];
    final objetBien = bien is Map ? BienDeVisite.fromJson(Map<String, dynamic>.from(bien)) : null;
    return MandatVente(
        id: _entier(json['id']) ?? 0,
        bienId: _entier(json['bienId']) ?? objetBien?.id ?? (bien is Map ? null : _entier(bien)),
        proprietaireNom: _texte(json['proprietaireNom']) ?? '',
        proprietaireCin: _texte(json['proprietaireCin']),
        proprietaireNationalite: _texte(json['proprietaireNationalite']),
        proprietaireAdresse: _texte(json['proprietaireAdresse']),
        proprietaireTel: _texte(json['proprietaireTel']),
        typeBien: _texte(json['typeBien']),
        ville: _texte(json['ville']),
        surface: _montantOuNull(json['surface']),
        titreFoncier: _texte(json['titreFoncier']),
        adresseBien: _texte(json['adresseBien']),
        prixDemande: _montantOuNull(json['prixDemande']),
        commission: _montantOuNull(json['commission']),
        dureeMois: _entier(json['dureeMois']),
        dateSignature: _date(json['dateSignature']),
        dateFin: _date(json['dateFin']),
        actif: _vrai(json['actif']),
        joursRestants: _entier(json['joursRestants']),
        remarques: _texte(json['remarques']),
        creeLe: _instant(json['creeLe']),
        ownerId: _entier(json['ownerId'] ?? json['owner']),
        signe: _vrai(json['signe']),
        signeLe: _instant(json['signeLe']),
        bien: objetBien,
      );
  }
}

/// Un mandat et les types de bien proposes par le serveur.
class FicheMandat {
  final MandatVente mandat;

  /// Libelle francais -> valeur arabe, comme [DossierVente.types].
  final Map<String, String> types;

  const FicheMandat({required this.mandat, this.types = const {}});

  factory FicheMandat.fromJson(Map<String, dynamic> json) => FicheMandat(
        mandat: MandatVente.fromJson(json),
        types: _dictionnaire(json['types']),
      );
}

/// Donnees pre-remplies d'un nouveau mandat, tirees du bien et de son
/// proprietaire (GET /ventes/biens/{id}/mandat-prerempli).
class MandatPrerempli {
  final int? ownerId;
  final String proprietaireNom;
  final String? proprietaireCin;
  final String? proprietaireNationalite;
  final String? proprietaireAdresse;
  final String? proprietaireTel;
  final String? typeBien;
  final String? ville;
  final double? surface;
  final String? titreFoncier;
  final String? adresseBien;
  final double? prixDemande;
  final double commission;
  final int dureeMois;
  final DateTime? dateSignature;

  /// Libelle francais -> valeur arabe, comme [DossierVente.types].
  final Map<String, String> types;

  /// Nombre de mandats deja enregistres pour ce bien.
  final int mandatsExistants;

  const MandatPrerempli({
    this.ownerId,
    this.proprietaireNom = '',
    this.proprietaireCin,
    this.proprietaireNationalite,
    this.proprietaireAdresse,
    this.proprietaireTel,
    this.typeBien,
    this.ville,
    this.surface,
    this.titreFoncier,
    this.adresseBien,
    this.prixDemande,
    this.commission = 2.5,
    this.dureeMois = 12,
    this.dateSignature,
    this.types = const {},
    this.mandatsExistants = 0,
  });

  factory MandatPrerempli.fromJson(Map<String, dynamic> json) {
    final existants = json['mandatsExistants'];
    return MandatPrerempli(
      ownerId: _entier(json['ownerId']),
      proprietaireNom: _texte(json['proprietaireNom']) ?? '',
      proprietaireCin: _texte(json['proprietaireCin']),
      proprietaireNationalite: _texte(json['proprietaireNationalite']),
      proprietaireAdresse: _texte(json['proprietaireAdresse']),
      proprietaireTel: _texte(json['proprietaireTel']),
      typeBien: _texte(json['typeBien']),
      ville: _texte(json['ville']),
      surface: _montantOuNull(json['surface']),
      titreFoncier: _texte(json['titreFoncier']),
      adresseBien: _texte(json['adresseBien']),
      prixDemande: _montantOuNull(json['prixDemande']),
      commission: _montantOuNull(json['commission']) ?? 2.5,
      dureeMois: _entier(json['dureeMois']) ?? 12,
      dateSignature: _date(json['dateSignature']),
      types: _dictionnaire(json['types']),
      mandatsExistants: existants is List ? existants.length : (_entier(existants) ?? 0),
    );
  }
}

/// Types de bien du contrat, quand le serveur ne les a pas encore fournis.
const Map<String, String> typesBienParDefaut = {
  'Appartement': 'شقة',
  'Villa': 'فيلا',
  'Immeuble': 'عمارة',
  'Maison': 'منزل',
  'Riad': 'رياض',
  'Terrain': 'بقعة أرضية',
  'Local commercial': 'محل تجاري',
  'Bureau': 'مكتب',
};

/// Le bien d'une visite, dans la liste des visites recentes.
class BienDeVisite {
  final int id;
  final String titre;
  final String? adresse;
  final String? photo;

  const BienDeVisite({required this.id, this.titre = '', this.adresse, this.photo});

  factory BienDeVisite.fromJson(Map<String, dynamic> json) => BienDeVisite(
        id: _entier(json['id']) ?? 0,
        titre: _texte(json['titre']) ?? 'Bien',
        adresse: _texte(json['adresse']),
        photo: _texte(json['photo']),
      );
}

class VisiteVente {
  final int id;
  final int? bienId;
  final int? clientId;
  final String visiteurNom;
  final String? visiteurCin;
  final String? visiteurNationalite;
  final String? visiteurAdresse;
  final String? visiteurTel;
  final DateTime? dateVisite;
  final double? commission;
  final String? suite;
  final String? suiteLibelle;
  final String? remarques;
  final String? agent;
  final DateTime? creeLe;
  final BienDeVisite? bien;
  /// Le client a signe le recu sur le telephone.
  final bool signe;
  final DateTime? signeLe;

  const VisiteVente({
    required this.id,
    this.bienId,
    this.clientId,
    this.visiteurNom = '',
    this.visiteurCin,
    this.visiteurNationalite,
    this.visiteurAdresse,
    this.visiteurTel,
    this.dateVisite,
    this.commission,
    this.suite,
    this.suiteLibelle,
    this.remarques,
    this.agent,
    this.creeLe,
    this.bien,
    this.signe = false,
    this.signeLe,
  });

  String get libelleSuite => suiteLibelle ?? SuiteVisite.libelle(suite);

  factory VisiteVente.fromJson(Map<String, dynamic> json) {
    final bien = _objet(json['bien']);
    final agent = json['agent'];
    return VisiteVente(
      id: _entier(json['id']) ?? 0,
      bienId: _entier(json['bienId']) ?? _entier(bien?['id']),
      clientId: _entier(json['clientId']),
      visiteurNom: _texte(json['visiteurNom']) ?? '',
      visiteurCin: _texte(json['visiteurCin']),
      visiteurNationalite: _texte(json['visiteurNationalite']),
      visiteurAdresse: _texte(json['visiteurAdresse']),
      visiteurTel: _texte(json['visiteurTel']),
      dateVisite: _date(json['dateVisite']),
      commission: _montantOuNull(json['commission']),
      suite: _texte(json['suite']),
      suiteLibelle: _texte(json['suiteLibelle']),
      remarques: _texte(json['remarques']),
      agent: agent is Map ? _texte(agent['nom'] ?? agent['name']) : _texte(agent),
      creeLe: _instant(json['creeLe']),
      bien: bien == null ? null : BienDeVisite.fromJson(bien),
      signe: _vrai(json['signe']),
      signeLe: _instant(json['signeLe']),
    );
  }
}

/// Un bien en vente, tel que la liste et le dossier le montrent.
class BienVente {
  final int id;
  final String titre;
  final String? adresse;
  final String? photo;
  final double? prix;
  final double? surface;
  final String statutVente;
  final String? statutVenteLibelle;
  final String? dossier;
  final ProprietaireVente? proprietaire;
  final MandatVente? mandat;
  final int nbMandats;
  final int nbVisites;
  final DateTime? derniereVisite;

  const BienVente({
    required this.id,
    this.titre = '',
    this.adresse,
    this.photo,
    this.prix,
    this.surface,
    this.statutVente = StatutVente.aVendre,
    this.statutVenteLibelle,
    this.dossier,
    this.proprietaire,
    this.mandat,
    this.nbMandats = 0,
    this.nbVisites = 0,
    this.derniereVisite,
  });

  String get libelleStatut => statutVenteLibelle ?? StatutVente.libelle(statutVente);

  factory BienVente.fromJson(Map<String, dynamic> json) {
    final proprietaire = _objet(json['proprietaire']);
    final mandat = _objet(json['mandat']);
    final dossier = json['dossier'];
    return BienVente(
      id: _entier(json['id']) ?? 0,
      titre: _texte(json['titre']) ?? 'Bien',
      adresse: _texte(json['adresse']),
      photo: _texte(json['photo']),
      prix: _montantOuNull(json['prix']),
      surface: _montantOuNull(json['surface']),
      statutVente: _texte(json['statutVente']) ?? StatutVente.aVendre,
      statutVenteLibelle: _texte(json['statutVenteLibelle']),
      dossier: dossier is Map ? _texte(dossier['nom'] ?? dossier['name']) : _texte(dossier),
      proprietaire: proprietaire == null ? null : ProprietaireVente.fromJson(proprietaire),
      mandat: mandat == null ? null : MandatVente.fromJson(mandat),
      nbMandats: _entier(json['nbMandats']) ?? 0,
      nbVisites: _entier(json['nbVisites']) ?? 0,
      derniereVisite: _date(json['derniereVisite']),
    );
  }
}

/// Le dossier de vente complet d'un bien.
class DossierVente {
  final BienVente bien;
  final String? typeBienPropose;
  final List<MandatVente> mandats;
  final List<VisiteVente> visites;

  /// Types de bien : libelle francais -> valeur arabe attendue par le serveur.
  final Map<String, String> types;
  final Map<String, String> statuts;
  final Map<String, String> suites;

  const DossierVente({
    required this.bien,
    this.typeBienPropose,
    this.mandats = const [],
    this.visites = const [],
    this.types = const {},
    this.statuts = const {},
    this.suites = const {},
  });

  factory DossierVente.fromJson(Map<String, dynamic> json) => DossierVente(
        bien: BienVente.fromJson(json),
        typeBienPropose: _texte(json['typeBienPropose']),
        mandats: _liste(json['mandats']).map(MandatVente.fromJson).toList(),
        visites: _liste(json['visites']).map(VisiteVente.fromJson).toList(),
        types: _dictionnaire(json['types']),
        statuts: _dictionnaire(json['statuts']),
        suites: _dictionnaire(json['suites']),
      );
}

class TableauVentes {
  final int biens;
  final int aVendre;
  final int compromis;
  final int vendus;
  final int sansMandat;
  final int mandatsActifs;
  final List<BienVente> mandatsQuiExpirent;
  final int visitesCeMois;
  final List<VisiteVente> visitesRecentes;

  const TableauVentes({
    this.biens = 0,
    this.aVendre = 0,
    this.compromis = 0,
    this.vendus = 0,
    this.sansMandat = 0,
    this.mandatsActifs = 0,
    this.mandatsQuiExpirent = const [],
    this.visitesCeMois = 0,
    this.visitesRecentes = const [],
  });

  factory TableauVentes.fromJson(Map<String, dynamic> json) => TableauVentes(
        biens: _entier(json['biens']) ?? 0,
        aVendre: _entier(json['aVendre']) ?? 0,
        compromis: _entier(json['compromis']) ?? 0,
        vendus: _entier(json['vendus']) ?? 0,
        sansMandat: _entier(json['sansMandat']) ?? 0,
        mandatsActifs: _entier(json['mandatsActifs']) ?? 0,
        mandatsQuiExpirent: _liste(json['mandatsQuiExpirent']).map(BienVente.fromJson).toList(),
        visitesCeMois: _entier(json['visitesCeMois']) ?? 0,
        visitesRecentes: _liste(json['visitesRecentes']).map(VisiteVente.fromJson).toList(),
      );
}
