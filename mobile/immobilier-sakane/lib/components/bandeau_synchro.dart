import 'package:flutter/material.dart';
import 'package:immobilier/core/offline/operation_en_attente.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

/// Bandeau d'etat du reseau : En ligne / Hors connexion /
/// Synchronisation en attente / Synchronisé.
///
/// Discret quand tout va bien, visible des qu'une action reste a envoyer.
class BandeauSynchro extends StatelessWidget {
  /// Masque le bandeau lorsque tout est a jour et la connexion presente.
  final bool masquerSiTout0k;

  const BandeauSynchro({super.key, this.masquerSiTout0k = true});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Synchronisation.instance,
      builder: (context, _) {
        final synchro = Synchronisation.instance;
        final etat = synchro.etat;

        if (masquerSiTout0k && etat == EtatSynchro.enLigne) {
          return const SizedBox.shrink();
        }

        final apparence = _apparence(etat);
        final attente = synchro.nombreEnAttente;
        final refusees = synchro.refusees.length;

        return Material(
          color: apparence.fond,
          child: InkWell(
            onTap: () => _ouvrirDetail(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  if (etat == EtatSynchro.enCours)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(apparence.texte),
                      ),
                    )
                  else
                    Icon(apparence.icone, size: 16, color: apparence.texte),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _texte(etat, attente),
                      style: TextStyle(
                        color: apparence.texte,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (refusees > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$refusees refusée${refusees > 1 ? 's' : ''}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (etat == EtatSynchro.enAttente) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.refresh, size: 16, color: apparence.texte),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _texte(EtatSynchro etat, int attente) {
    if (etat == EtatSynchro.horsConnexion && attente > 0) {
      return "Hors connexion — $attente action${attente > 1 ? 's' : ''} à envoyer";
    }
    if (etat == EtatSynchro.enAttente) {
      return "Synchronisation en attente — $attente action${attente > 1 ? 's' : ''}";
    }
    return etat.libelle;
  }

  _Apparence _apparence(EtatSynchro etat) {
    switch (etat) {
      case EtatSynchro.horsConnexion:
        return _Apparence(
            Colors.blueGrey.shade700, Colors.white, Icons.cloud_off);
      case EtatSynchro.enAttente:
        return _Apparence(
            Colors.orange.shade700, Colors.white, Icons.cloud_upload_outlined);
      case EtatSynchro.enCours:
        return _Apparence(Colors.blue.shade700, Colors.white, Icons.sync);
      case EtatSynchro.synchronise:
        return _Apparence(
            Colors.green.shade600, Colors.white, Icons.cloud_done_outlined);
      case EtatSynchro.enLigne:
        return _Apparence(
            Colors.green.shade50, Colors.green.shade800, Icons.cloud_done);
    }
  }

  void _ouvrirDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _DetailSynchro(),
    );
  }
}

class _Apparence {
  final Color fond;
  final Color texte;
  final IconData icone;
  _Apparence(this.fond, this.texte, this.icone);
}

/// Liste des operations en attente et de celles refusees par le serveur.
class _DetailSynchro extends StatelessWidget {
  const _DetailSynchro();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Synchronisation.instance,
      builder: (context, _) {
        final synchro = Synchronisation.instance;
        final attente =
            synchro.refusees.isEmpty && synchro.nombreEnAttente == 0;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      synchro.enLigne ? Icons.cloud_done : Icons.cloud_off,
                      size: 19,
                      color: synchro.enLigne
                          ? Colors.green.shade700
                          : Colors.blueGrey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      synchro.etat.libelle,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (synchro.enLigne && synchro.nombreEnAttente > 0)
                      TextButton.icon(
                        onPressed: () => synchro.synchroniser(),
                        icon: const Icon(Icons.sync, size: 17),
                        label: const Text("Envoyer maintenant"),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                if (attente)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 19, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Toutes vos actions ont été enregistrées sur le serveur.",
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (synchro.nombreEnAttente > 0) ...[
                  _sousTitre("À envoyer (${synchro.nombreEnAttente})"),
                  ..._lignes(context, synchro.enAttente, false),
                ],

                if (synchro.refusees.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _sousTitre(
                              "Refusées par le serveur (${synchro.refusees.length})")),
                      TextButton(
                        onPressed: () => synchro.oublierRefusees(),
                        child: const Text("Tout effacer",
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  ..._lignes(context, synchro.refusees, true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sousTitre(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
      );

  List<Widget> _lignes(
      BuildContext context, List<OperationEnAttente> operations, bool refus) {
    return operations
        .map((o) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    refus ? Icons.error_outline : Icons.schedule,
                    size: 17,
                    color: refus ? Colors.red.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.libelle,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w500)),
                        if (o.message != null)
                          Text(o.message!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red.shade700)),
                      ],
                    ),
                  ),
                  if (refus)
                    IconButton(
                      onPressed: () =>
                          Synchronisation.instance.oublier(o.id),
                      icon: const Icon(Icons.close, size: 17),
                      tooltip: "Retirer",
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ))
        .toList();
  }
}
