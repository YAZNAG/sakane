import 'package:flutter/material.dart';

import 'package:immobilier/features/caisses/ui/components/historique_par_jour.dart';

/// Le vocabulaire de la caisse : à chaque motif du serveur, un libellé
/// français et une icône.
///
/// Un motif que l'application ne connaît pas ne disparaît pas pour
/// autant : il est rendu lisible (« encaissement_solde » devient
/// « Encaissement solde ») et reçoit l'icône du sens. Aucune opération
/// ne tombe dans un cas muet — c'est la règle de ce fichier.

/// Comment présenter un motif : son libellé et son icône.
class MotifCaisse {
  final String libelle;
  final IconData icone;

  const MotifCaisse(this.libelle, this.icone);
}

/// Les motifs connus du serveur, entrées puis sorties.
const Map<String, MotifCaisse> motifsConnusCaisse = {
  // ── Ce qui entre ──
  "ouverture":
      MotifCaisse("Ouverture de caisse", Icons.play_circle_outline),
  "encaissement_reservation":
      MotifCaisse("Encaissement réservation", Icons.event_available_outlined),
  "encaissement_prolongation":
      MotifCaisse("Encaissement prolongation", Icons.more_time),
  "encaissement_solde":
      MotifCaisse("Encaissement du solde", Icons.payments_outlined),
  "caution_recue": MotifCaisse("Caution reçue", Icons.shield_outlined),
  "remise_recue":
      MotifCaisse("Transfert reçu", Icons.move_to_inbox_outlined),
  "apport": MotifCaisse("Apport", Icons.savings_outlined),
  "charge_annulee": MotifCaisse("Charge annulée", Icons.undo_outlined),
  "loyer": MotifCaisse("Loyer encaissé", Icons.home_work_outlined),
  "excedent": MotifCaisse("Excédent de caisse", Icons.trending_up),

  // ── Ce qui sort ──
  "charge": MotifCaisse("Charge payée", Icons.receipt_long_outlined),
  "remboursement":
      MotifCaisse("Remboursement client", Icons.assignment_return_outlined),
  "caution_rendue": MotifCaisse("Caution rendue", Icons.shield_moon_outlined),
  "remise_declaree":
      MotifCaisse("Transfert à l'agence", Icons.outbox_outlined),
  "versement_proprietaire":
      MotifCaisse("Versement propriétaire", Icons.real_estate_agent_outlined),
  "depot_banque":
      MotifCaisse("Dépôt en banque", Icons.account_balance_outlined),
  "depense_diverse":
      MotifCaisse("Dépense diverse", Icons.shopping_bag_outlined),
  "vidage":
      MotifCaisse("Caisse ramenée à zéro", Icons.cleaning_services_outlined),

  // ── Dans un sens comme dans l'autre ──
  "correction": MotifCaisse("Correction", Icons.tune),
};

/// Le motif, connu ou non.
///
/// [entree] sert au repli : sans lui, une opération inconnue reçoit
/// l'icône neutre des deux sens.
MotifCaisse motifCaisse(String motif, {bool? entree}) {
  final cle = motif.trim();
  final connu = motifsConnusCaisse[cle];
  if (connu != null) return connu;

  if (cle.isEmpty) {
    return MotifCaisse(
      entree == false ? "Sortie" : "Entrée",
      entree == false ? Icons.north_east : Icons.south_west,
    );
  }

  // Un motif ajouté côté serveur après cette version : il reste lisible.
  return MotifCaisse(motifLisible(cle), Icons.swap_vert);
}

/// Le titre d'une opération : celui du serveur s'il l'a rempli, le
/// libellé du motif sinon. Jamais vide.
String libelleOperationCaisse(String libelle, String motif,
    {bool? entree}) {
  final t = libelle.trim();
  if (t.isNotEmpty) return t;
  return motifCaisse(motif, entree: entree).libelle;
}

/// La couleur d'une opération : vert pour ce qui entre, rouge pour ce
/// qui sort.
Color couleurSensCaisse(bool entree) =>
    entree ? couleurEntreeCaisse : couleurSortieCaisse;

/// L'orange de ce qui attend une action.
const couleurAttenteCaisse = Color(0xFF8A6D1F);

/// Le rouge d'un écart ou d'un solde négatif.
const couleurAlerteCaisse = Color(0xFFB3261E);

/// Le texte principal et le texte secondaire des écrans de caisse.
const couleurTexteCaisse = Color(0xFF17262E);
const couleurTexteDouxCaisse = Color(0xFF6B7B84);

/// La bordure des cartes blanches.
const couleurBordureCaisse = Color(0xFFE2E8EC);

/// Le fond des écrans de caisse.
const couleurFondCaisse = Color(0xFFF2F5F7);

/// Des chiffres de largeur fixe : les montants s'alignent d'une ligne à
/// l'autre, comme sur un relevé.
const List<FontFeature> chiffresAlignesCaisse = [FontFeature.tabularFigures()];

/// Le style d'un montant, aligné sur les autres.
TextStyle styleMontantCaisse(
        {double taille = 14,
        FontWeight poids = FontWeight.bold,
        Color? couleur}) =>
    TextStyle(
      fontSize: taille,
      fontWeight: poids,
      color: couleur,
      fontFeatures: chiffresAlignesCaisse,
    );
