/// Les caisses, telles que le serveur les rend.
///
/// Le solde n'est jamais calculé ici : il vient du serveur, qui l'établit
/// à partir des mouvements. Un solde recalculé côté application pourrait
/// diverger de celui qui fait foi.

class MouvementCaisse {
  final int id;
  final String sens;
  final double montant;
  final String motif;
  final String libelle;
  final String? commentaire;
  final DateTime? effectueLe;

  /// Qui a passe l'ecriture. Vide pour un report automatique.
  final String? par;

  /// La caisse concernée, quand le serveur la précise.
  final String? caisse;

  /// La réservation ou la charge à l'origine du mouvement, s'il y en a
  /// une. Absentes des anciennes réponses du serveur.
  final int? bookingId;
  final int? chargeId;
  final String? reference;

  const MouvementCaisse({
    required this.id,
    required this.sens,
    required this.montant,
    required this.motif,
    required this.libelle,
    this.commentaire,
    this.effectueLe,
    this.par,
    this.caisse,
    this.bookingId,
    this.chargeId,
    this.reference,
  });

  bool get estEntree => sens == "entree";

  factory MouvementCaisse.fromJson(Map<String, dynamic> json) {
    return MouvementCaisse(
      id: json["id"] ?? 0,
      sens: json["sens"] ?? "entree",
      montant: (json["montant"] as num?)?.toDouble() ?? 0,
      motif: json["motif"] ?? "",
      libelle: json["libelle"] ?? "",
      commentaire: _texteOuNul(json["commentaire"]),
      effectueLe: DateTime.tryParse(json["effectueLe"] ?? "")?.toLocal(),
      par: json["par"],
      caisse: _texteOuNul(json["caisse"] is Map
          ? (json["caisse"] as Map)["nom"]
          : json["caisse"]),
      bookingId:
          _entierAirbnb(json["bookingId"] ?? json["reservationId"]),
      chargeId: _entierAirbnb(json["chargeId"]),
      reference: _texteOuNul(json["reference"]),
    );
  }
}

class RemiseCaisse {
  final int id;
  final double montantDeclare;
  final double? montantRecu;
  final String statut;
  final double ecart;
  final DateTime? declareLe;
  final DateTime? confirmeLe;

  /// La caisse qui reçoit, quand le serveur la précise.
  final String? destination;
  final String? commentaire;

  /// Ce qu'a écrit la personne qui a confirmé la réception.
  final String? commentaireReception;

  /// Qui a confirmé la réception, quand le serveur le précise.
  final String? confirmePar;

  const RemiseCaisse({
    required this.id,
    required this.montantDeclare,
    this.montantRecu,
    required this.statut,
    this.ecart = 0,
    this.declareLe,
    this.confirmeLe,
    this.destination,
    this.commentaire,
    this.commentaireReception,
    this.confirmePar,
  });

  bool get enAttente => statut == "en_attente";

  factory RemiseCaisse.fromJson(Map<String, dynamic> json) {
    return RemiseCaisse(
      id: json["id"] ?? 0,
      montantDeclare: (json["montantDeclare"] as num?)?.toDouble() ?? 0,
      montantRecu: (json["montantRecu"] as num?)?.toDouble(),
      statut: json["statut"] ?? "en_attente",
      ecart: (json["ecart"] as num?)?.toDouble() ?? 0,
      declareLe: DateTime.tryParse(json["declareLe"] ?? "")?.toLocal(),
      confirmeLe: DateTime.tryParse(json["confirmeLe"] ?? "")?.toLocal(),
      destination: _texteOuNul(json["destination"]),
      commentaire: _texteOuNul(json["commentaire"]),
      commentaireReception: _texteOuNul(json["commentaireReception"]),
      confirmePar: _texteOuNul(json["confirmePar"]),
    );
  }
}

class MaCaisse {
  /// Vrai pour la caisse principale, qui ne se transfere pas a
  /// elle-meme.
  final bool principale;
  final int id;
  final String nom;
  final bool ouverte;
  final double solde;

  /// Ce qu'il restait à la clôture précédente : de quoi ouvrir la
  /// suivante d'un geste, sans ressaisir le montant.
  final double aReporter;

  /// La caisse en cours, nulle si aucune n'est ouverte.
  final int? numero;
  final double ouvertureMontant;
  final bool reporte;
  final DateTime? ouverteLe;
  final List<MouvementCaisse> mouvements;
  final List<RemiseCaisse> remises;

  /// Ce que d'autres ont envoyé à cette caisse et qui attend d'être
  /// confirmé : le détenteur voit le détail et la photo avant d'accepter.
  final List<TransfertAConfirmer> aConfirmer;

  const MaCaisse({
    this.principale = false,
    required this.id,
    required this.nom,
    required this.ouverte,
    required this.solde,
    this.aReporter = 0,
    this.numero,
    this.ouvertureMontant = 0,
    this.reporte = false,
    this.ouverteLe,
    this.mouvements = const [],
    this.remises = const [],
    this.aConfirmer = const [],
  });

  factory MaCaisse.fromJson(Map<String, dynamic> json) {
    final session = json["session"] as Map<String, dynamic>?;

    return MaCaisse(
      principale: json["principale"] ?? false,
      id: json["id"] ?? 0,
      aReporter: (json["aReporter"] as num?)?.toDouble() ?? 0,
      numero: session?["numero"],
      ouvertureMontant: (session?["ouverture"] as num?)?.toDouble() ?? 0,
      reporte: session?["reporte"] ?? false,
      ouverteLe: DateTime.tryParse(session?["ouverteLe"] ?? "")?.toLocal(),
      nom: json["nom"] ?? "Ma caisse",
      ouverte: json["ouverte"] ?? false,
      solde: (json["solde"] as num?)?.toDouble() ?? 0,
      mouvements: (json["mouvements"] as List?)
              ?.map((e) => MouvementCaisse.fromJson(e))
              .toList() ??
          const [],
      remises: (json["remises"] as List?)
              ?.map((e) => RemiseCaisse.fromJson(e))
              .toList() ??
          const [],
      aConfirmer: (json["aConfirmer"] as List?)
              ?.map((e) => TransfertAConfirmer.fromJson(e))
              .toList() ??
          const [],
    );
  }
}

class SoldeCaisse {
  final int id;
  final String nom;
  final String type;
  final double solde;
  final bool ouverte;

  const SoldeCaisse({
    required this.id,
    required this.nom,
    required this.type,
    required this.solde,
    required this.ouverte,
  });

  bool get estAgence => type == "agence";

  factory SoldeCaisse.fromJson(Map<String, dynamic> json) {
    return SoldeCaisse(
      id: json["id"] ?? 0,
      nom: json["nom"] ?? "-",
      type: json["type"] ?? "agent",
      solde: (json["solde"] as num?)?.toDouble() ?? 0,
      ouverte: json["ouverte"] ?? false,
    );
  }
}

class RemiseEnAttente {
  final int id;
  final String caisse;
  final double montantDeclare;
  final DateTime? declareLe;
  final String? commentaire;

  const RemiseEnAttente({
    required this.id,
    required this.caisse,
    required this.montantDeclare,
    this.declareLe,
    this.commentaire,
  });

  factory RemiseEnAttente.fromJson(Map<String, dynamic> json) {
    return RemiseEnAttente(
      id: json["id"] ?? 0,
      caisse: json["caisse"] ?? "-",
      montantDeclare: (json["montantDeclare"] as num?)?.toDouble() ?? 0,
      declareLe: DateTime.tryParse(json["declareLe"] ?? "")?.toLocal(),
      commentaire: json["commentaire"],
    );
  }
}

/// La vue d'ensemble, réservée à l'administrateur.
class VueCaisses {
  final List<SoldeCaisse> caisses;
  final List<RemiseEnAttente> aConfirmer;
  final double enTransit;

  const VueCaisses({
    this.caisses = const [],
    this.aConfirmer = const [],
    this.enTransit = 0,
  });

  factory VueCaisses.fromJson(Map<String, dynamic> json) {
    return VueCaisses(
      caisses: (json["caisses"] as List?)
              ?.map((e) => SoldeCaisse.fromJson(e))
              .toList() ??
          const [],
      aConfirmer: (json["aConfirmer"] as List?)
              ?.map((e) => RemiseEnAttente.fromJson(e))
              .toList() ??
          const [],
      enTransit: (json["enTransit"] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Un comptage de caisse, figé à l'instant de la clôture.
///
/// L'écart n'est pas recalculé : il vaut ce qu'il valait ce jour-là,
/// sans quoi il changerait au gré des mouvements suivants.
class Cloturage {
  final int id;
  final String caisse;
  final int caisseId;

  /// Ce que la caisse contenait au début de la période — le montant
  /// compté à la clôture précédente, ou zéro pour la première.
  final double montantDepart;
  final double totalEntrees;
  final double totalSorties;
  final double totalRemis;
  final DateTime? debutPeriode;

  final double soldeTheorique;
  final double montantCompte;
  final double ecart;
  final bool juste;
  final String auteur;
  final DateTime? clotureLe;
  final String? commentaire;

  const Cloturage({
    required this.id,
    required this.caisse,
    this.caisseId = 0,
    this.montantDepart = 0,
    this.totalEntrees = 0,
    this.totalSorties = 0,
    this.totalRemis = 0,
    this.debutPeriode,
    required this.soldeTheorique,
    required this.montantCompte,
    required this.ecart,
    required this.juste,
    this.auteur = "",
    this.clotureLe,
    this.commentaire,
  });

  bool get excedent => ecart > 0.005;

  factory Cloturage.fromJson(Map<String, dynamic> json) {
    return Cloturage(
      id: json["id"] ?? 0,
      caisse: json["caisse"] ?? "-",
      caisseId: json["caisseId"] ?? 0,
      montantDepart: (json["montantDepart"] as num?)?.toDouble() ?? 0,
      totalEntrees: (json["totalEntrees"] as num?)?.toDouble() ?? 0,
      totalSorties: (json["totalSorties"] as num?)?.toDouble() ?? 0,
      totalRemis: (json["totalRemis"] as num?)?.toDouble() ?? 0,
      debutPeriode: DateTime.tryParse(json["debutPeriode"] ?? "")?.toLocal(),
      soldeTheorique: (json["soldeTheorique"] as num?)?.toDouble() ?? 0,
      montantCompte: (json["montantCompte"] as num?)?.toDouble() ?? 0,
      ecart: (json["ecart"] as num?)?.toDouble() ?? 0,
      juste: json["juste"] ?? true,
      auteur: json["auteur"] ?? "",
      clotureLe: DateTime.tryParse(json["clotureLe"] ?? "")?.toLocal(),
      commentaire: json["commentaire"],
    );
  }
}

/// Une caisse ouverte puis close, avec son propre journal.
///
/// Les mouvements ne sont pas meles d'une caisse a l'autre : un solde
/// n'a de sens que rapporte au fond avec lequel la caisse a demarre.
class SessionCaisse {
  final int id;
  final int numero;
  final double ouverture;

  /// Vrai lorsque le fond vient du montant compte a la cloture
  /// precedente, faux lorsqu'il a ete saisi.
  final bool reporte;

  final DateTime? ouverteLe;
  final DateTime? closeLe;
  final bool ouverte;
  final double solde;
  final List<MouvementCaisse> mouvements;

  const SessionCaisse({
    required this.id,
    required this.numero,
    this.ouverture = 0,
    this.reporte = false,
    this.ouverteLe,
    this.closeLe,
    this.ouverte = false,
    this.solde = 0,
    this.mouvements = const [],
  });

  factory SessionCaisse.fromJson(Map<String, dynamic> json) {
    return SessionCaisse(
      id: json["id"] ?? 0,
      numero: json["numero"] ?? 0,
      ouverture: (json["ouverture"] as num?)?.toDouble() ?? 0,
      reporte: json["reporte"] ?? false,
      ouverteLe: DateTime.tryParse(json["ouverteLe"] ?? "")?.toLocal(),
      closeLe: DateTime.tryParse(json["closeLe"] ?? "")?.toLocal(),
      ouverte: json["ouverte"] ?? false,
      solde: (json["solde"] as num?)?.toDouble() ?? 0,
      mouvements: ((json["mouvements"] as List?) ?? const [])
          .map((e) => MouvementCaisse.fromJson(e))
          .toList(),
    );
  }
}

/// Un transfert reçu, en attente de confirmation.
///
/// Le destinataire compte ce qu'il a reçu : c'est ce montant qui entre
/// dans sa caisse, pas celui qui a été annoncé.
class TransfertAConfirmer {
  final int id;

  /// La caisse qui envoie.
  final String caisse;
  final double montantDeclare;
  final DateTime? declareLe;
  final String? commentaire;

  /// La photo jointe par l'expéditeur, s'il en a joint une.
  final String? piece;

  /// Qui a envoyé, quand le serveur le précise.
  final String? par;

  const TransfertAConfirmer({
    required this.id,
    required this.caisse,
    required this.montantDeclare,
    this.declareLe,
    this.commentaire,
    this.piece,
    this.par,
  });

  factory TransfertAConfirmer.fromJson(Map<String, dynamic> json) {
    final piece = json["piece"];

    return TransfertAConfirmer(
      id: json["id"] ?? 0,
      caisse: json["caisse"] ?? "-",
      montantDeclare: (json["montantDeclare"] as num?)?.toDouble() ?? 0,
      declareLe: DateTime.tryParse(json["declareLe"] ?? "")?.toLocal(),
      commentaire: _texteOuNul(json["commentaire"]),
      piece: piece is String && piece.isNotEmpty ? piece : null,
      par: _texteOuNul(json["par"] ?? json["declarePar"]),
    );
  }
}

/// Une caisse vers laquelle on peut envoyer des espèces.
class CaisseDestinataire {
  final int id;
  final String nom;

  /// Vrai pour la caisse de l'agence.
  final bool principale;

  const CaisseDestinataire({
    required this.id,
    required this.nom,
    this.principale = false,
  });

  factory CaisseDestinataire.fromJson(Map<String, dynamic> json) {
    return CaisseDestinataire(
      id: json["id"] ?? 0,
      nom: json["nom"] ?? "-",
      principale: json["principale"] ?? false,
    );
  }
}

// ── La caisse Airbnb ────────────────────────────────────────────────

/// Un mouvement de la caisse Airbnb : l'entrée d'un séjour payé sur
/// Airbnb, ou la sortie d'un transfert vers une autre caisse.
class MouvementCaisseAirbnb {
  final int id;
  final DateTime? date;
  final String sens;
  final double montant;
  final String libelle;

  /// La réservation à l'origine de l'entrée, s'il y en a une.
  final int? bookingId;
  final String? commentaire;
  final String? par;

  const MouvementCaisseAirbnb({
    required this.id,
    this.date,
    required this.sens,
    required this.montant,
    required this.libelle,
    this.bookingId,
    this.commentaire,
    this.par,
  });

  bool get estEntree => sens != "sortie";

  factory MouvementCaisseAirbnb.fromJson(Map<String, dynamic> json) {
    final commentaire = json["commentaire"]?.toString();
    final par = json["par"]?.toString();
    return MouvementCaisseAirbnb(
      id: _entierAirbnb(json["id"]) ?? 0,
      date: DateTime.tryParse(json["date"]?.toString() ?? "")?.toLocal(),
      sens: json["sens"]?.toString() ?? "entree",
      montant: _nombreAirbnb(json["montant"]),
      libelle: json["libelle"]?.toString() ?? "",
      bookingId: _entierAirbnb(json["bookingId"]),
      commentaire:
          commentaire == null || commentaire.trim().isEmpty ? null : commentaire,
      par: par == null || par.trim().isEmpty ? null : par,
    );
  }
}

/// La caisse qui reçoit automatiquement le montant des séjours payés
/// sur Airbnb. Réservée à l'administrateur.
class CaisseAirbnb {
  final int id;
  final String nom;
  final double solde;
  final double totalEncaisse;
  final double totalTransfere;
  final List<MouvementCaisseAirbnb> mouvements;

  /// Les caisses vers lesquelles transférer.
  final List<CaisseDestinataire> destinations;

  const CaisseAirbnb({
    required this.id,
    required this.nom,
    required this.solde,
    this.totalEncaisse = 0,
    this.totalTransfere = 0,
    this.mouvements = const [],
    this.destinations = const [],
  });

  factory CaisseAirbnb.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> liste(dynamic v) => v is List
        ? v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];

    return CaisseAirbnb(
      id: _entierAirbnb(json["id"]) ?? 0,
      nom: json["nom"]?.toString() ?? "Caisse Airbnb",
      solde: _nombreAirbnb(json["solde"]),
      totalEncaisse: _nombreAirbnb(json["totalEncaisse"]),
      totalTransfere: _nombreAirbnb(json["totalTransfere"]),
      mouvements:
          liste(json["mouvements"]).map(MouvementCaisseAirbnb.fromJson).toList(),
      destinations: liste(json["destinations"])
          .map((d) => CaisseDestinataire(
                id: _entierAirbnb(d["id"]) ?? 0,
                nom: d["nom"]?.toString() ?? "-",
                principale: d["principale"] == true ||
                    d["principale"] == 1 ||
                    d["principale"] == "1",
              ))
          .toList(),
    );
  }
}

double _nombreAirbnb(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? "") ?? 0;
}

int? _entierAirbnb(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? "");
}

/// Une chaîne non vide, ou nul : un commentaire vide n'est pas affiché.
String? _texteOuNul(dynamic v) {
  final t = v?.toString();
  return t == null || t.trim().isEmpty ? null : t;
}
