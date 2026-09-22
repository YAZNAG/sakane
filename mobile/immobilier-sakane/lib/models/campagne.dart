import 'dart:io';

/// Critères de sélection des destinataires d'une campagne.
class SegmentClients {
  /// tous | avec_reservation | sans_reservation | par_bien |
  /// par_periode | en_sejour | selection
  String type;
  int? realestateId;
  DateTime? du;
  DateTime? au;
  List<int> clients;

  SegmentClients({
    this.type = 'tous',
    this.realestateId,
    this.du,
    this.au,
    List<int>? clients,
  }) : clients = clients ?? [];

  Map<String, dynamic> toJson() => {
        'type': type,
        if (realestateId != null) 'realestate': realestateId,
        if (du != null) 'du': _date(du!),
        if (au != null) 'au': _date(au!),
        if (clients.isNotEmpty) 'clients': clients,
      };

  factory SegmentClients.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SegmentClients();
    return SegmentClients(
      type: json['type'] ?? 'tous',
      // Le serveur peut renvoyer les identifiants en texte ("565").
      realestateId: json['realestate'] == null ? null : _entierJson(json['realestate']),
      du: json['du'] != null ? DateTime.tryParse(json['du']) : null,
      au: json['au'] != null ? DateTime.tryParse(json['au']) : null,
      clients: (json['clients'] as List?)
              ?.map((e) => _entierJson(e))
              .where((id) => id > 0)
              .toList() ??
          [],
    );
  }

  static String _date(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";
}

DateTime? _dateJson(dynamic valeur) =>
    valeur == null ? null : DateTime.tryParse(valeur.toString())?.toLocal();

int _entierJson(dynamic valeur, [int defaut = 0]) {
  if (valeur is int) return valeur;
  if (valeur is num) return valeur.round();
  return int.tryParse('${valeur ?? ''}') ?? defaut;
}

/// Suivi de l'envoi vers un client.
class DestinataireCampagne {
  final int? id;

  /// Position dans la file d'envoi (1, 2, 3...).
  final int? ordre;
  final int? clientId;
  final String? nom;
  final String? telephone;

  /// en_attente | envoye | echec | ignore
  final String statut;
  final String? erreur;
  final DateTime? envoyeA;

  DestinataireCampagne({
    this.id,
    this.ordre,
    this.clientId,
    this.nom,
    this.telephone,
    this.statut = 'en_attente',
    this.erreur,
    this.envoyeA,
  });

  bool get enEchec => statut == 'echec';
  bool get envoye => statut == 'envoye';
  bool get enAttente => statut == 'en_attente';
  bool get ignore => statut == 'ignore';

  factory DestinataireCampagne.fromJson(Map<String, dynamic> json) {
    return DestinataireCampagne(
      id: json['id'],
      ordre: json['ordre'] == null ? null : _entierJson(json['ordre']),
      clientId: json['clientId'],
      nom: json['nom'],
      telephone: json['telephone'],
      statut: json['statut'] ?? 'en_attente',
      erreur: json['erreur'],
      envoyeA: _dateJson(json['envoyeA']),
    );
  }
}

/// Une diffusion de message vers un ensemble de clients.
class Campagne {
  int? id;
  String? titre;
  String? message;
  String? lien;
  String? imageUrl;

  /// Image choisie dans l'application, avant envoi au serveur.
  File? image;

  SegmentClients segment;

  /// brouillon | programmee | en_cours | en_pause | terminee | annulee
  String statut;

  /// Rythme d'envoi fixe du serveur.
  int parMinute;

  DateTime? planifieeA;
  DateTime? demarreeA;
  DateTime? termineeA;
  DateTime? pauseeA;
  DateTime? repriseA;
  DateTime? dernierEnvoiA;

  int nbDestinataires;
  int nbEnvoyes;
  int nbEchecs;
  int nbRestants;
  int nbEnAttente;
  int nbIgnores;

  /// Part traitee, de 0 a 100, calculee par le serveur.
  int? progression;

  /// Estimation serveur du temps restant, au rythme fixe.
  int? minutesRestantes;

  String? auteur;
  DateTime? creeLe;
  List<DestinataireCampagne>? destinataires;

  Campagne({
    this.id,
    this.titre,
    this.message,
    this.lien,
    this.imageUrl,
    this.image,
    SegmentClients? segment,
    this.statut = 'brouillon',
    this.parMinute = 2,
    this.planifieeA,
    this.demarreeA,
    this.termineeA,
    this.pauseeA,
    this.repriseA,
    this.dernierEnvoiA,
    this.nbDestinataires = 0,
    this.nbEnvoyes = 0,
    this.nbEchecs = 0,
    this.nbRestants = 0,
    this.nbEnAttente = 0,
    this.nbIgnores = 0,
    this.progression,
    this.minutesRestantes,
    this.auteur,
    this.creeLe,
    this.destinataires,
  }) : segment = segment ?? SegmentClients();

  bool get estLancee => statut == 'en_cours';
  bool get estEnPause => statut == 'en_pause';
  bool get estTerminee => statut == 'terminee';
  bool get estAnnulee => statut == 'annulee';
  bool get estProgrammee => statut == 'programmee';
  bool get estBrouillon => statut == 'brouillon';

  /// L'envoi avance ou va demarrer tout seul : l'ecran doit se rafraichir.
  bool get estActive => estLancee || estProgrammee;

  bool get peutEtreSupprimee => estBrouillon || estTerminee || estAnnulee;

  /// Part des messages déjà traités, pour la barre de progression.
  double get avancement {
    if (progression != null) {
      return (progression! / 100).clamp(0, 1).toDouble();
    }
    if (nbDestinataires == 0) return 0;
    return ((nbDestinataires - nbEnAttente) / nbDestinataires)
        .clamp(0, 1)
        .toDouble();
  }

  int get pourcentage => (avancement * 100).round();

  /// Temps restant estimé, en minutes, au rythme fixe du serveur.
  int get minutesEstimees {
    if (minutesRestantes != null) return minutesRestantes!;
    if (nbEnAttente == 0) return 0;
    return (nbEnAttente / (parMinute <= 0 ? 2 : parMinute)).ceil();
  }

  /// Position du prochain message à partir, dans l'ordre de la liste.
  int get prochainOrdre {
    final liste = destinataires;
    if (liste != null) {
      for (final d in liste) {
        if (d.enAttente && d.ordre != null) return d.ordre!;
      }
    }
    final traites = nbDestinataires - nbEnAttente;
    return traites < 0 ? 1 : traites + 1;
  }

  String get statutLisible {
    switch (statut) {
      case 'brouillon':
        return 'Brouillon';
      case 'programmee':
        return 'Programmée';
      case 'en_cours':
        return 'En cours';
      case 'en_pause':
        return 'En pause';
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      default:
        return statut;
    }
  }

  factory Campagne.fromJson(Map<String, dynamic> json) {
    final destinataires = (json['destinataires'] as List?)
        ?.map((e) => DestinataireCampagne.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    // La liste suit l'ordre d'envoi, meme si le serveur la renvoie melangee.
    destinataires?.sort(
        (a, b) => (a.ordre ?? 1 << 30).compareTo(b.ordre ?? 1 << 30));

    return Campagne(
      id: json['id'],
      titre: json['titre'],
      message: json['message'],
      lien: json['lien'],
      imageUrl: json['image'],
      segment: SegmentClients.fromJson(
          json['segment'] is Map ? Map<String, dynamic>.from(json['segment']) : null),
      statut: json['statut'] ?? 'brouillon',
      parMinute: _entierJson(json['parMinute'], 2),
      planifieeA: _dateJson(json['planifieeA']),
      demarreeA: _dateJson(json['demarreeA']),
      termineeA: _dateJson(json['termineeA']),
      pauseeA: _dateJson(json['pauseeA']),
      repriseA: _dateJson(json['repriseA']),
      dernierEnvoiA: _dateJson(json['dernierEnvoiA']),
      nbDestinataires: _entierJson(json['nbDestinataires']),
      nbEnvoyes: _entierJson(json['nbEnvoyes']),
      nbEchecs: _entierJson(json['nbEchecs']),
      nbRestants: _entierJson(json['nbRestants']),
      // Anciennes reponses : le reste a envoyer s'appelait nbRestants.
      nbEnAttente: _entierJson(json['nbEnAttente'] ?? json['nbRestants']),
      nbIgnores: _entierJson(json['nbIgnores']),
      progression: json['progression'] == null
          ? null
          : _entierJson(json['progression']),
      minutesRestantes: json['minutesRestantes'] == null
          ? null
          : _entierJson(json['minutesRestantes']),
      auteur: json['auteur'],
      creeLe: _dateJson(json['creeLe']),
      destinataires: destinataires,
    );
  }
}

/// Résultat de l'estimation d'un segment, avant création.
class EstimationSegment {
  final int nombre;
  final int exclus;
  final List<String> exemples;

  EstimationSegment({
    this.nombre = 0,
    this.exclus = 0,
    List<String>? exemples,
  }) : exemples = exemples ?? [];

  factory EstimationSegment.fromJson(Map<String, dynamic> json) {
    return EstimationSegment(
      nombre: json['nombre'] ?? 0,
      exclus: json['exclus'] ?? 0,
      exemples: (json['exemples'] as List?)
              ?.map((e) => (e['nom'] ?? '').toString())
              .where((n) => n.isNotEmpty)
              .toList() ??
          [],
    );
  }
}
