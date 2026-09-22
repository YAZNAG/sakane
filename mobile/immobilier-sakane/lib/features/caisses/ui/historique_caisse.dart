import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/caisses/cubit/historique_cubit.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/features/caisses/ui/components/historique_par_jour.dart';
import 'package:immobilier/features/caisses/ui/components/ligne_mouvement_caisse.dart';
import 'package:immobilier/features/caisses/ui/components/motifs_caisse.dart';
import 'package:immobilier/features/caisses/ui/components/section_caisse.dart';

/// L'historique d'une caisse : ses caisses successives et ses clôtures.
///
/// Deux journaux séparés plutôt qu'un seul mêlé : un mouvement déplace
/// de l'argent, une clôture constate ce qu'il en reste. Les confondre
/// rendrait les deux illisibles.
class HistoriqueCaissePage extends StatelessWidget {

  TableauExportable? _tableauExport(HistoriqueState state) {
    if (state.chargement == AppStatus.loading || state.chargement == AppStatus.error) {
      return null;
    }
    double entrees = 0, sorties = 0;
    final lignes = <List<String>>[];
    for (final s in state.sessions) {
      for (final m in s.mouvements) {
        if (m.estEntree) {
          entrees += m.montant;
        } else {
          sorties += m.montant;
        }
        lignes.add([
          '${s.numero}',
          dateHeureExport(m.effectueLe),
          m.estEntree ? 'Entrée' : 'Sortie',
          // Le libellé du motif quand le serveur n'a rien écrit : une
          // ligne d'export sans nom ne se relit pas.
          libelleOperationCaisse(m.libelle, m.motif, entree: m.estEntree),
          m.commentaire ?? '',
          m.par ?? '',
          montantExport(m.estEntree ? m.montant : -m.montant),
        ]);
      }
    }
    return TableauExportable(
      titre: 'Journal de caisse${nomCaisse == null ? '' : ' - $nomCaisse'}',
      colonnes: const ['Caisse n°', 'Date', 'Sens', 'Libellé', 'Commentaire', 'Par', 'Montant'],
      lignes: lignes,
      totaux: [
        'TOTAL', '', '',
        'Entrées ${montantExport(entrees)} / Sorties ${montantExport(sorties)}',
        '', '', montantExport(entrees - sorties),
      ],
    );
  }

  /// Caisse à consulter. Nulle pour la sienne.
  final int? caisseId;
  final String? nomCaisse;

  const HistoriqueCaissePage({super.key, this.caisseId, this.nomCaisse});

  static Widget page({int? caisseId, String? nomCaisse}) => BlocProvider(
        create: (_) => HistoriqueCubit(caisseId)..charger(),
        child: HistoriqueCaissePage(caisseId: caisseId, nomCaisse: nomCaisse),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: couleurFondCaisse,
        appBar: AppBar(
          title: Text(
            nomCaisse ?? "Journal de caisse",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryColor,
          actions: [
            BoutonExport(
                tableau: () => _tableauExport(context.read<HistoriqueCubit>().state)),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Caisses"),
              Tab(text: "Clôtures"),
            ],
          ),
        ),
        body: BlocBuilder<HistoriqueCubit, HistoriqueState>(
          builder: (context, state) {
            final cubit = context.read<HistoriqueCubit>();

            if (state.chargement == AppStatus.loading) {
              return const SqueletteCaisse(sections: 4);
            }

            if (state.chargement == AppStatus.error) {
              return RefreshIndicator(
                onRefresh: cubit.charger,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _Message(
                      icone: Icons.wifi_off,
                      titre: "Historique indisponible",
                      detail:
                          state.erreur ?? "Vérifiez la connexion, puis réessayez.",
                    ),
                  ],
                ),
              );
            }

            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: cubit.charger,
                  child: _Caisses(sessions: state.sessions, nomCaisse: nomCaisse),
                ),
                RefreshIndicator(
                  onRefresh: cubit.charger,
                  child: _Cloturages(cloturages: state.cloturages),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// -- Les caisses successives -----------------------------------------

class _Caisses extends StatelessWidget {
  final List<SessionCaisse> sessions;
  final String? nomCaisse;

  const _Caisses({required this.sessions, this.nomCaisse});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _Message(
            icone: Icons.point_of_sale_outlined,
            titre: "Aucune caisse",
            detail: "Les caisses ouvertes puis clôturées apparaîtront ici, "
                "chacune avec son journal.",
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        for (final s in sessions)
          CarteSessionCaisse(session: s, nomCaisse: nomCaisse),
      ],
    );
  }
}

class CarteSessionCaisse extends StatelessWidget {
  final SessionCaisse session;

  /// Le nom de la caisse, repris dans le détail d'un mouvement quand le
  /// serveur ne le précise pas.
  final String? nomCaisse;

  const CarteSessionCaisse({super.key, required this.session, this.nomCaisse});

  @override
  Widget build(BuildContext context) {
    final ouverte = session.ouverte;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            color: ouverte
                ? AppColors.primaryColor.withValues(alpha: .45)
                : couleurBordureCaisse),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // La caisse en cours est celle qu'on vient consulter ; les
          // precedentes attendent qu'on les demande.
          initiallyExpanded: ouverte,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (ouverte ? AppColors.primaryColor : couleurTexteDouxCaisse)
                  .withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ouverte ? Icons.point_of_sale_outlined : Icons.inventory_2_outlined,
              size: 19,
              color: ouverte ? AppColors.primaryColor : couleurTexteDouxCaisse,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text("Caisse n° ${session.numero}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: couleurTexteCaisse)),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ouverte
                      ? AppColors.primaryColor.withValues(alpha: .12)
                      : const Color(0xFFEEF1F4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ouverte ? "En cours" : "Clôturée",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ouverte
                        ? AppColors.primaryColor
                        : couleurTexteDouxCaisse,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              ouverte
                  ? "Ouverte ${_heure(session.ouverteLe)}"
                  : "Du ${_jour(session.ouverteLe)} au ${_jour(session.closeLe)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5, color: couleurTexteDouxCaisse),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(montantCaisseTexte(session.solde),
                  style: styleMontantCaisse(
                    couleur: ouverte
                        ? AppColors.primaryColor
                        : couleurTexteCaisse,
                  )),
              Text(
                  "${session.mouvements.length} opération"
                  "${session.mouvements.length > 1 ? 's' : ''}",
                  style: const TextStyle(
                      fontSize: 10.5, color: couleurTexteDouxCaisse)),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(session.reporte ? Icons.move_down : Icons.edit_outlined,
                      size: 14, color: couleurTexteDouxCaisse),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      session.reporte
                          ? "Fond reporté de la caisse précédente : "
                              "${montantCaisseTexte(session.ouverture)}"
                          : "Fond de départ saisi : "
                              "${montantCaisseTexte(session.ouverture)}",
                      style: const TextStyle(
                          fontSize: 11.5, color: couleurTexteDouxCaisse),
                    ),
                  ),
                ],
              ),
            ),
            if (session.mouvements.isEmpty)
              const VideSectionCaisse(
                "Aucune opération dans cette caisse.",
                icone: Icons.receipt_long_outlined,
              )
            else
              // Regroupées par jour : la journée la plus récente ouverte,
              // les autres repliées.
              JournalParJourCaisse(
                mouvements: session.mouvements,
                solde: session.solde,
                nomCaisse: nomCaisse == null
                    ? "Caisse n° ${session.numero}"
                    : "$nomCaisse — caisse n° ${session.numero}",
              ),
          ],
        ),
      ),
    );
  }
}

// ── Les clôtures ────────────────────────────────────────────────────

class _Cloturages extends StatelessWidget {
  final List<Cloturage> cloturages;

  const _Cloturages({required this.cloturages});

  @override
  Widget build(BuildContext context) {
    if (cloturages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _Message(
            icone: Icons.fact_check_outlined,
            titre: "Aucune clôture",
            detail: "Comptez vos espèces en fin de journée : "
                "l'écart, s'il y en a un, sera enregistré ici.",
          ),
        ],
      );
    }

    // Groupées par caisse : l'administrateur en consulte plusieurs, et
    // mêler les comptages de deux agents rendrait la lecture inutile.
    final parCaisse = <String, List<Cloturage>>{};
    for (final c in cloturages) {
      parCaisse.putIfAbsent(c.caisse, () => []).add(c);
    }

    final plusieurs = parCaisse.length > 1;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        for (final groupe in parCaisse.entries) ...[
          if (plusieurs)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 6, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 16, color: couleurTexteDouxCaisse),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      groupe.key,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: couleurTexteCaisse,
                      ),
                    ),
                  ),
                  Text(
                    "${groupe.value.length} clôture"
                    "${groupe.value.length > 1 ? 's' : ''}",
                    style: const TextStyle(
                        fontSize: 11.5, color: couleurTexteDouxCaisse),
                  ),
                ],
              ),
            ),
          ...groupe.value.map((c) => _CarteCloture(cloture: c)),
        ],
      ],
    );
  }
}

class _CarteCloture extends StatelessWidget {
  final Cloturage cloture;

  const _CarteCloture({required this.cloture});

  @override
  Widget build(BuildContext context) {
    final couleur = cloture.juste
        ? couleurEntreeCaisse
        : (cloture.excedent ? couleurAttenteCaisse : couleurSortieCaisse);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: couleurBordureCaisse),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  cloture.juste
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 18,
                  color: couleur,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cloture.juste
                      ? "Comptage juste"
                      : (cloture.excedent ? "Excédent" : "Manquant"),
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: couleur),
                ),
              ),
              if (!cloture.juste)
                Text(
                  "${cloture.ecart > 0 ? '+' : '−'} "
                  "${montantCaisseTexte(cloture.ecart.abs())}",
                  style: styleMontantCaisse(taille: 15, couleur: couleur),
                ),
            ],
          ),
          const SizedBox(height: 11),
          // Le parcours de la période : d'où l'on partait, ce qui est
          // entré, ce qui est sorti, ce qui est parti à l'agence.
          _Ligne("Montant de départ", montantCaisseTexte(cloture.montantDepart)),
          _Ligne("Entré sur la période",
              "+ ${montantCaisseTexte(cloture.totalEntrees)}",
              couleur: couleurEntreeCaisse),
          _Ligne("Sorti sur la période",
              "− ${montantCaisseTexte(cloture.totalSorties)}",
              couleur: couleurSortieCaisse),
          if (cloture.totalRemis > 0.005)
            _Ligne("dont remis à l'agence",
                montantCaisseTexte(cloture.totalRemis),
                secondaire: true),
          const Divider(height: 16),
          _Ligne("Solde attendu", montantCaisseTexte(cloture.soldeTheorique),
              gras: true),
          _Ligne("Espèces comptées", montantCaisseTexte(cloture.montantCompte),
              gras: true),
          const SizedBox(height: 7),
          Text(
            "${_heure(cloture.clotureLe)}"
            "${cloture.auteur.isEmpty ? '' : ' — ${cloture.auteur}'}",
            style: const TextStyle(
                fontSize: 11.5, color: couleurTexteDouxCaisse),
          ),
          if (cloture.commentaire?.isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Text(cloture.commentaire!,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
          ],
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final String libelle;
  final String valeur;
  final Color? couleur;
  final bool gras;

  /// Une précision rattachée à la ligne précédente : elle se retire et
  /// s'efface, pour ne pas se lire comme un poste de plus.
  final bool secondaire;

  const _Ligne(this.libelle, this.valeur,
      {this.couleur, this.gras = false, this.secondaire = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          top: 2, bottom: 2, left: secondaire ? 14 : 0),
      child: Row(
        children: [
          Expanded(
            child: Text(libelle,
                style: TextStyle(
                    fontSize: secondaire ? 12 : 13,
                    color: couleurTexteDouxCaisse)),
          ),
          Text(valeur,
              style: styleMontantCaisse(
                taille: secondaire ? 12.5 : 13.5,
                poids: gras ? FontWeight.bold : FontWeight.w600,
                couleur: couleur ??
                    (secondaire ? couleurTexteDouxCaisse : couleurTexteCaisse),
              )),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;

  const _Message(
      {required this.icone, required this.titre, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 70, 30, 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: couleurTexteCaisse)),
          const SizedBox(height: 6),
          Text(detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, height: 1.35, color: couleurTexteDouxCaisse)),
        ],
      ),
    );
  }
}

// ── Mise en forme ───────────────────────────────────────────────────

String _jour(DateTime? d) {
  if (d == null) return "Sans date";
  final maintenant = DateTime.now();
  if (d.year == maintenant.year &&
      d.month == maintenant.month &&
      d.day == maintenant.day) {
    return "Aujourd'hui";
  }
  final hier = maintenant.subtract(const Duration(days: 1));
  if (d.year == hier.year && d.month == hier.month && d.day == hier.day) {
    return "Hier";
  }
  return "${d.day.toString().padLeft(2, '0')}/"
      "${d.month.toString().padLeft(2, '0')}/${d.year}";
}

String _heure(DateTime? d) {
  if (d == null) return "—";
  return "${_jour(d)} à ${d.hour.toString().padLeft(2, '0')}:"
      "${d.minute.toString().padLeft(2, '0')}";
}
