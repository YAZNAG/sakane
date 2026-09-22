import 'dart:convert';
import 'dart:math';

/// Etat d'une operation enregistree hors connexion.
enum StatutOperation {
  /// Attend le retour de la connexion.
  enAttente,

  /// Envoi en cours vers le serveur.
  envoiEnCours,

  /// Le serveur a refuse l'operation (dates occupees, donnees invalides...).
  /// L'operation ne sera pas retentee : elle demande une decision humaine.
  refusee,
}

/// Une ecriture effectuee sans connexion, conservee sur le telephone
/// jusqu'a son envoi au serveur.
///
/// L'identifiant [id] sert de cle d'idempotence : le serveur la memorise,
/// si bien qu'un renvoi apres une coupure ne cree jamais de doublon.
class OperationEnAttente {
  final String id;
  final String type;
  final String libelle;
  final String methode;
  final String chemin;
  final Map<String, dynamic> donnees;

  /// Fichiers joints, copies dans un dossier durable de l'application.
  /// Cle = nom du champ attendu par le serveur ("document", "images[]"),
  /// valeur = chemins locaux. Un champ terminé par [] accepte plusieurs
  /// fichiers.
  final Map<String, List<String>> fichiers;

  final DateTime creeLe;
  int tentatives;
  StatutOperation statut;
  String? message;

  /// Le compte qui a fait l'action et son jeton : l'envoi se fait en son
  /// nom, meme si un autre compte s'est connecte entre-temps.
  String? jeton;
  int? managerId;
  String? managerNom;

  /// Session expiree : l'action attend que ce compte se reconnecte.
  bool aReconnecter;

  OperationEnAttente({
    required this.id,
    required this.type,
    required this.libelle,
    required this.methode,
    required this.chemin,
    required this.donnees,
    Map<String, List<String>>? fichiers,
    DateTime? creeLe,
    this.tentatives = 0,
    this.statut = StatutOperation.enAttente,
    this.message,
    this.jeton,
    this.managerId,
    this.managerNom,
    this.aReconnecter = false,
  })  : fichiers = fichiers ?? {},
        creeLe = creeLe ?? DateTime.now();

  bool get estRefusee => statut == StatutOperation.refusee;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'libelle': libelle,
        'methode': methode,
        'chemin': chemin,
        'donnees': donnees,
        'fichiers': fichiers,
        'creeLe': creeLe.toIso8601String(),
        'tentatives': tentatives,
        'statut': statut.name,
        'message': message,
        'jeton': jeton,
        'managerId': managerId,
        'managerNom': managerNom,
        'aReconnecter': aReconnecter,
      };

  factory OperationEnAttente.fromJson(Map<String, dynamic> json) {
    return OperationEnAttente(
      id: json['id'],
      type: json['type'] ?? 'inconnu',
      libelle: json['libelle'] ?? 'Opération',
      methode: json['methode'] ?? 'POST',
      chemin: json['chemin'],
      donnees: Map<String, dynamic>.from(json['donnees'] ?? {}),
      fichiers: (json['fichiers'] as Map?)?.map(
              (k, v) => MapEntry(k as String, List<String>.from(v))) ??
          {},
      creeLe: DateTime.tryParse(json['creeLe'] ?? '') ?? DateTime.now(),
      tentatives: json['tentatives'] ?? 0,
      statut: StatutOperation.values.firstWhere(
        (s) => s.name == json['statut'],
        orElse: () => StatutOperation.enAttente,
      ),
      message: json['message'],
      jeton: json['jeton'],
      managerId: (json['managerId'] as num?)?.toInt(),
      managerNom: json['managerNom'],
      aReconnecter: json['aReconnecter'] == true,
    );
  }

  @override
  String toString() => jsonEncode(toJson());

  /// Identifiant unique genere localement, sans dependance externe.
  static String nouvelId() {
    final alea = Random.secure();
    final octets = List<int>.generate(16, (_) => alea.nextInt(256));
    final hex = octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join();
    return 'op-${DateTime.now().millisecondsSinceEpoch}-$hex';
  }
}
