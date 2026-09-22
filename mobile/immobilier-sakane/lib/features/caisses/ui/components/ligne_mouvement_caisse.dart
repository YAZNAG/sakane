import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:immobilier/components/ligne_commentaire.dart';
import 'package:immobilier/features/caisses/ui/components/historique_par_jour.dart';
import 'package:immobilier/features/caisses/ui/components/motifs_caisse.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/routes.dart';

/// Une opération de caisse, telle qu'elle apparaît dans un journal.
///
/// La même ligne sert à l'écran de la caisse et au journal complet :
/// une opération ne doit pas changer d'aspect selon l'endroit d'où on
/// la regarde. Son motif lui donne son icône et, quand le serveur n'a
/// pas rempli le libellé, son titre : aucune opération n'apparaît sans
/// nom.

/// Les mouvements du plus récent au plus ancien, ceux sans date en fin.
///
/// Le tri est refait ici plutôt que supposé : un apport saisi à la main
/// n'arrive pas forcément à la place où sa date le met.
List<MouvementCaisse> mouvementsTriesCaisse(Iterable<MouvementCaisse> source) {
  final liste = source.toList();
  liste.sort((a, b) {
    final da = a.effectueLe;
    final db = b.effectueLe;
    if (da == null && db == null) return b.id.compareTo(a.id);
    if (da == null) return 1;
    if (db == null) return -1;
    final parDate = db.compareTo(da);
    return parDate != 0 ? parDate : b.id.compareTo(a.id);
  });
  return liste;
}

/// Le solde après chaque opération, reconstitué en remontant la liste
/// depuis [soldeFinal].
///
/// La table est indexée par l'objet, non par l'identifiant : deux
/// mouvements sans identifiant ne s'écrasent plus l'un l'autre.
Map<MouvementCaisse, double> soldesApresCaisse(
    List<MouvementCaisse> triesDuPlusRecent, double soldeFinal) {
  final soldes = <MouvementCaisse, double>{};
  var courant = soldeFinal;
  for (final m in triesDuPlusRecent) {
    soldes[m] = courant;
    courant += m.estEntree ? -m.montant : m.montant;
  }
  return soldes;
}

/// Ouvre la fiche de détail d'une opération.
void detailMouvementCaisse(
  BuildContext context, {
  required MouvementCaisse mouvement,
  required String nomCaisse,
  double? soldeApres,
}) {
  final m = mouvement;
  final entree = m.estEntree;
  final booking = m.bookingId;
  final motif = motifCaisse(m.motif, entree: entree);

  afficherDetailOperation(
    context,
    titre: libelleOperationCaisse(m.libelle, m.motif, entree: entree),
    montant: "${entree ? '+' : '−'} ${montantCaisseTexte(m.montant)}",
    couleur: couleurSensCaisse(entree),
    icone: motif.icone,
    statut: entree ? "Entrée" : "Sortie",
    couleurStatut: couleurSensCaisse(entree),
    infos: [
      InfoDetail("Date", dateHeureCaisse(m.effectueLe), icone: Icons.schedule),
      InfoDetail("Par", m.par?.isNotEmpty == true ? m.par! : "Automatique",
          icone: Icons.person_outline),
      InfoDetail("Caisse", nomCaisse,
          icone: Icons.account_balance_wallet_outlined),
      InfoDetail("Type", motif.libelle, icone: Icons.label_outline),
      if (booking != null)
        InfoDetail("Réservation", "n° $booking",
            icone: Icons.event_available_outlined),
      if (m.chargeId != null)
        InfoDetail("Charge", "n° ${m.chargeId}",
            icone: Icons.receipt_long_outlined),
      if (m.reference != null)
        InfoDetail("Référence", m.reference!, icone: Icons.tag),
      if (soldeApres != null)
        InfoDetail("Solde après", montantCaisseTexte(soldeApres),
            icone: Icons.account_balance_outlined),
    ],
    commentaires: [CommentaireDetail("Commentaire", m.commentaire)],
    actions: [
      if (booking != null)
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            GoRouter.of(context).push(
                Routes.detailReservation.replaceFirst(':id', '$booking'));
          },
          icon: const Icon(Icons.open_in_new, size: 17),
          label: const Text("Voir la réservation"),
        ),
    ],
  );
}

/// Une opération dans la liste : son icône, son libellé, l'heure, le
/// montant signé et le solde qu'elle laisse derrière elle.
class LigneMouvementCaisse extends StatelessWidget {
  final MouvementCaisse mouvement;

  /// La caisse concernée, reprise dans la fiche de détail.
  final String nomCaisse;

  /// Le solde après l'opération. Nul quand il n'est pas reconstituable.
  final double? soldeApres;

  const LigneMouvementCaisse({
    super.key,
    required this.mouvement,
    required this.nomCaisse,
    this.soldeApres,
  });

  @override
  Widget build(BuildContext context) {
    final m = mouvement;
    final entree = m.estEntree;
    final couleur = couleurSensCaisse(entree);
    final motif = motifCaisse(m.motif, entree: entree);
    final solde = soldeApres;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: couleurBordureCaisse),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => detailMouvementCaisse(
          context,
          mouvement: m,
          nomCaisse: nomCaisse,
          soldeApres: solde,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(motif.icone, size: 17, color: couleur),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libelleOperationCaisse(m.libelle, m.motif,
                          entree: entree),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: couleurTexteCaisse),
                    ),
                    const SizedBox(height: 2),
                    // Le jour est dans l'en-tête de la journée : l'heure
                    // suffit ici.
                    Text(
                      m.effectueLe == null ? "—" : heureCaisse(m.effectueLe!),
                      style: const TextStyle(
                          fontSize: 11.5, color: couleurTexteDouxCaisse),
                    ),
                    LigneCommentaire(m.commentaire,
                        taille: 11.5,
                        marge: const EdgeInsets.only(top: 3, bottom: 1)),
                    // Qui a passé l'écriture : c'est la première question
                    // quand une opération surprend.
                    if (m.par?.isNotEmpty == true)
                      Text("par ${m.par}",
                          style: const TextStyle(
                              fontSize: 11.5, color: couleurTexteDouxCaisse)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${entree ? '+' : '−'} ${montantCaisseTexte(m.montant)}",
                    style: styleMontantCaisse(couleur: couleur),
                  ),
                  if (solde != null) ...[
                    const SizedBox(height: 2),
                    Text("solde ${montantCaisseTexte(solde)}",
                        style: styleMontantCaisse(
                            taille: 11,
                            poids: FontWeight.normal,
                            couleur: couleurTexteDouxCaisse)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les opérations d'une caisse, groupées par jour et cliquables.
class JournalParJourCaisse extends StatelessWidget {
  final List<MouvementCaisse> mouvements;
  final String nomCaisse;

  /// Le solde de la caisse après la dernière opération, pour
  /// reconstituer les soldes intermédiaires. Nul : aucun solde affiché.
  final double? solde;

  const JournalParJourCaisse({
    super.key,
    required this.mouvements,
    required this.nomCaisse,
    this.solde,
  });

  @override
  Widget build(BuildContext context) {
    final tries = mouvementsTriesCaisse(mouvements);
    final s = solde;
    final soldes =
        s == null ? const <MouvementCaisse, double>{} : soldesApresCaisse(tries, s);

    return HistoriqueParJour<MouvementCaisse>(
      elements: tries,
      date: (m) => m.effectueLe,
      estEntree: (m) => m.estEntree,
      montant: (m) => m.montant,
      ligne: (_, m) => LigneMouvementCaisse(
        mouvement: m,
        nomCaisse: nomCaisse,
        soldeApres: soldes[m],
      ),
    );
  }
}
