import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/baux/cubit/bail_detail_cubit.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/baux/ui/components/dialogues_bail.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:toastification/toastification.dart';

/// Une echeance du bail : paiements, encaissement et ajustement du montant.
Future<void> ouvrirFeuilleLoyer(BuildContext context, BailDetailCubit cubit, Loyer loyer) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(value: cubit, child: _FeuilleLoyer(loyerId: loyer.id, initial: loyer)),
  );
}

/// Les messages s'affichent par-dessus la feuille, pas sous elle.
void _signaler(BuildContext context, ResultatBail res, String succes) {
  if (!context.mounted) return;
  if (res.erreur != null) {
    showToast('Échec', context, description: res.erreur, type: ToastificationType.error, second: 5);
    return;
  }
  if (res.avertissement != null) {
    showToast(succes, context, description: res.avertissement, type: ToastificationType.warning, second: 7);
  } else {
    showToast(succes, context);
  }
}

class _FeuilleLoyer extends StatelessWidget {
  final int loyerId;
  final Loyer initial;

  const _FeuilleLoyer({required this.loyerId, required this.initial});

  Future<void> _encaisser(BuildContext context, BailDetailCubit cubit, Loyer l) async {
    final tel = cubit.state.bail?.locataire.tel;
    final choix = await demanderEncaissement(context, l, telDisponible: (tel ?? '').isNotEmpty);
    if (choix == null || !context.mounted) return;
    final res = await cubit.encaisser(
      l.id,
      montant: choix.montant,
      payeLe: choix.date,
      mode: choix.mode,
      reference: choix.reference,
      remarque: choix.remarque,
      envoyerQuittance: choix.envoyerQuittance,
    );
    if (context.mounted) _signaler(context, res, 'Paiement enregistré');
  }

  Future<void> _modifierMontant(BuildContext context, BailDetailCubit cubit, Loyer l) async {
    final montant = await demanderMontantEcheance(context, l);
    if (montant == null || !context.mounted) return;
    final res = await cubit.modifierMontant(l.id, montant);
    if (context.mounted) _signaler(context, res, 'Montant modifié');
  }

  Future<void> _annuler(BuildContext context, BailDetailCubit cubit, PaiementLoyer p) async {
    final motif = await demanderAnnulationPaiement(context, p);
    if (motif == null || !context.mounted) return;
    final res = await cubit.annulerPaiement(p.id, motif.isEmpty ? null : motif);
    if (context.mounted) _signaler(context, res, 'Paiement annulé');
  }

  Future<void> _envoyerQuittance(BuildContext context, BailDetailCubit cubit, PaiementLoyer p) async {
    final res = await cubit.envoyerQuittance(p.id);
    if (context.mounted) _signaler(context, res, 'Quittance envoyée');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .7,
      minChildSize: .4,
      maxChildSize: .95,
      expand: false,
      builder: (context, controleur) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BlocBuilder<BailDetailCubit, BailDetailState>(
          builder: (context, state) {
            final cubit = context.read<BailDetailCubit>();
            final l = cubit.loyer(loyerId) ?? initial;
            final couleur = CouleursBail.statutLoyer(l.statut);
            final gerer = peutEncaisserLoyers;
            final paiements = [...l.paiements]..sort((a, b) => (b.payeLe ?? DateTime(0)).compareTo(a.payeLe ?? DateTime(0)));
            return ListView(
              controller: controleur,
              padding: EdgeInsets.fromLTRB(18, 10, 18, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: CouleursBail.bordure, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                if (state.enCours)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2, color: CouleursBail.teinte),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(l.libelle,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                    ),
                    PastilleBail(texte: libelleStatutLoyer(l.statut), couleur: couleur),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${periodeBail(l.periodeDebut, l.periodeFin)} • échéance le ${dateBail(l.echeance)}',
                  style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _chiffre('Montant', l.montant, CouleursBail.texte),
                    _chiffre('Payé', l.paye, CouleursBail.paye),
                    _chiffre('Reste', l.reste, l.reste > 0.004 ? couleur : CouleursBail.paye),
                  ],
                ),
                if (gerer) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (l.reste > 0.004)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: state.enCours ? null : () => _encaisser(context, cubit, l),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Encaisser'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CouleursBail.paye,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      if (l.reste > 0.004) const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.enCours ? null : () => _modifierMontant(context, cubit, l),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Modifier le montant'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CouleursBail.teinte,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text('Paiements (${paiements.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                const SizedBox(height: 8),
                if (paiements.isEmpty)
                  const Text('Aucun paiement pour cette échéance.', style: TextStyle(color: CouleursBail.texteDoux))
                else
                  for (final p in paiements) ...[
                    _paiement(context, cubit, p, state.enCours),
                    const SizedBox(height: 8),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chiffre(String libelle, double valeur, Color couleur) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: CouleursBail.fond, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(libelle, style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(montantLisible(valeur),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: couleur)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paiement(BuildContext context, BailDetailCubit cubit, PaiementLoyer p, bool enCours) {
    final gerer = peutEncaisserLoyers;
    final depot = Dependencies.get<Repository>();
    return Opacity(
      opacity: p.annule ? .6 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.annule ? CouleursBail.retard.withValues(alpha: .4) : CouleursBail.bordure),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(montantLisible(p.montant),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      decoration: p.annule ? TextDecoration.lineThrough : null,
                    )),
                const SizedBox(width: 8),
                PastilleBail(texte: p.libelleMode, couleur: CouleursBail.aPayer),
                const Spacer(),
                if (p.annule) const PastilleBail(texte: 'Annulé', couleur: CouleursBail.retard),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                'Le ${dateBail(p.payeLe)}',
                if ((p.par ?? '').isNotEmpty) 'par ${p.par}',
                if ((p.reference ?? '').isNotEmpty) 'réf. ${p.reference}',
              ].join(' • '),
              style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
            ),
            if ((p.remarque ?? '').isNotEmpty)
              Text(p.remarque!, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte)),
            if (p.annule)
              Text(
                'Annulé${(p.annuleLe ?? '').isEmpty ? '' : ' le ${p.annuleLe}'}'
                '${(p.motifAnnulation ?? '').isEmpty ? '' : ' : ${p.motifAnnulation}'}',
                style: const TextStyle(fontSize: 12, color: CouleursBail.retard),
              )
            else if ((p.quittanceEnvoyeeLe ?? '').isNotEmpty)
              Text('Quittance envoyée le ${p.quittanceEnvoyeeLe}',
                  style: const TextStyle(fontSize: 12, color: CouleursBail.paye)),
            if (!p.annule) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => ouvrirPdfBail(context, () => depot.telechargerQuittance(p.id), 'Quittance'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Quittance'),
                  ),
                  if (gerer)
                    TextButton.icon(
                      onPressed: enCours ? null : () => _envoyerQuittance(context, cubit, p),
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Envoyer la quittance'),
                    ),
                  if (gerer)
                    TextButton.icon(
                      onPressed: enCours ? null : () => _annuler(context, cubit, p),
                      style: TextButton.styleFrom(foregroundColor: CouleursBail.retard),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Annuler le paiement'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
