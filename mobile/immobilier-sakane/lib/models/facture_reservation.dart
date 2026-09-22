import 'package:immobilier/models/detail_reservation.dart';

/// Une facture de reservation, deposee dans un fichier temporaire.
///
/// Tant qu'elle n'est pas appliquee, le serveur rend un apercu (sans
/// numero). Une fois appliquee, elle est figee : on ne peut plus que la
/// voir, la telecharger ou l'envoyer.
class FactureReservation {
  final String chemin;
  final String nom;
  final String? numero;
  final bool appliquee;
  final double ht;
  final double montantTva;
  final double ttc;
  final String clientNom;
  final String? clientIce;
  final String? clientAdresse;

  /// Taux de TVA en pourcentage.
  final double tva;

  const FactureReservation({
    required this.chemin,
    this.nom = 'facture',
    this.numero,
    this.appliquee = false,
    this.ht = 0,
    this.montantTva = 0,
    this.ttc = 0,
    this.clientNom = '',
    this.clientIce,
    this.clientAdresse,
    this.tva = 20,
  });

  factory FactureReservation.fromJson(Map<String, dynamic> json, String chemin) {
    return FactureReservation(
      chemin: chemin,
      nom: lireTexte(json['nom']) ?? 'facture',
      numero: lireTexte(json['numero']),
      appliquee: lireBooleen(json['appliquee']),
      ht: lireNombre(json['ht']),
      montantTva: lireNombre(json['montantTva']),
      ttc: lireNombre(json['ttc']),
      clientNom: lireTexte(json['clientNom']) ?? '',
      clientIce: lireTexte(json['clientIce']),
      clientAdresse: lireTexte(json['clientAdresse']),
      tva: lireNombre(json['tva'], 20),
    );
  }

  String get titre => numero == null ? 'Facture' : 'Facture N° $numero';
}
