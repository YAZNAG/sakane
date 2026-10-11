import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/activite_equipe/activite_agents/cubit/activite_agents_cubit.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/models/activite_agents.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// « Activité des agents » : l'engagement de chaque agent de réservation,
/// lu sur les données réelles de la période.
///
/// Les totaux donnent la mesure d'ensemble, le graphique compare les
/// réservations au travail de terrain tranche par tranche, et la liste
/// classe les agents du plus actif au moins actif. Le serveur reste juge
/// des droits : il répond 403 si « view_agent_activity » manque.
class ActiviteAgentsPage extends StatelessWidget {
  const ActiviteAgentsPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => ActiviteAgentsCubit()..charger(),
        child: const ActiviteAgentsPage(),
      );

  /// Les couleurs des deux séries comparées.
  static const Color _couleurReservations = AppColors.primaryColor;
  static const Color _couleurTerrain = couleurOrangeActivite;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiviteAgentsCubit, ActiviteAgentsState>(
      builder: (context, state) {
        final cubit = context.read<ActiviteAgentsCubit>();
        return Scaffold(
          backgroundColor: const Color(0xFFF5F8FA),
          appBar: AppBar(
            title: const Text('Activité des agents',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            elevation: 0,
            centerTitle: true,
            actions: [BoutonExport(tableau: () => _tableau(state))],
          ),
          body: RefreshIndicator(
            color: AppColors.primaryColor,
            onRefresh: cubit.charger,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                _filtres(context, state, cubit),
                const SizedBox(height: 10),
                if (state.erreur != null) ...[
                  ErreurActivite(
                      message: state.erreur!, onReessayer: cubit.charger),
                  const SizedBox(height: 10),
                ],
                if (state.premierChargement)
                  const SqueletteActivite(totaux: 5, graphique: true)
                else
                  ..._contenu(context, state, cubit),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Les filtres ───────────────────────────────────────────────────

  Widget _filtres(BuildContext context, ActiviteAgentsState state,
      ActiviteAgentsCubit cubit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: carteActivite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FiltrePeriodeActivite(
            periode: state.periode,
            du: state.du,
            au: state.au,
            onPeriode: cubit.choisirPeriode,
            onDates: cubit.choisirDates,
          ),
          const Divider(height: 18, color: couleurBordureActivite),
          Row(
            children: [
              const Icon(Icons.view_week_outlined,
                  size: 16, color: couleurGrisActivite),
              const SizedBox(width: 6),
              const Text('Regrouper par',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: couleurTexteActivite)),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final g in GroupeActivite.values)
                      PuceActivite(
                        libelle: g.libelle,
                        choisie: state.groupe == g,
                        onTap: () => cubit.choisirGroupe(g),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (state.enChargement && state.activite != null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0xFFEDF1F4),
                color: AppColors.primaryColor,
              ),
            ),
        ],
      ),
    );
  }

  // ── Le contenu ────────────────────────────────────────────────────

  List<Widget> _contenu(BuildContext context, ActiviteAgentsState state,
      ActiviteAgentsCubit cubit) {
    final activite = state.activite;
    if (activite == null) {
      return const [
        VideActivite(
          icone: Icons.insights_outlined,
          titre: 'Rien à afficher',
          detail: "Tirez l'écran vers le bas pour charger l'activité.",
        ),
      ];
    }

    // Le regroupement que le serveur a réellement appliqué : il peut
    // différer de celui demandé si la période est trop courte.
    final groupe = GroupeActivite.depuis(activite.groupe);

    return [
      _totaux(activite),
      const SizedBox(height: 12),
      _graphique(activite, groupe),
      const SizedBox(height: 12),
      const Padding(
        padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text('Par agent',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: couleurTexteActivite)),
      ),
      if (activite.agents.isEmpty)
        const VideActivite(
          icone: Icons.groups_outlined,
          titre: 'Aucune activité sur cette période',
          detail: 'Personne n\'a créé de réservation ni fait de terrain '
              'entre ces deux dates. Élargissez la période.',
        )
      else
        for (final agent in activite.agents)
          _carteAgent(agent, activite, state, cubit, groupe),
    ];
  }

  Widget _totaux(ActiviteAgents activite) {
    final t = activite.totaux;
    final minutes = activite.minutesNettoyage;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        CarteTotalActivite(
          libelle: 'Réservations',
          valeur: '${t.reservations}',
          icone: FontAwesomeIcons.calendarCheck,
          teinte: AppColors.primaryColor,
        ),
        CarteTotalActivite(
          libelle: 'Appartements loués',
          valeur: '${t.biensLoues}',
          icone: FontAwesomeIcons.building,
          teinte: couleurVertActivite,
        ),
        CarteTotalActivite(
          libelle: 'Clés remises',
          valeur: '${t.clesRemises}',
          icone: FontAwesomeIcons.key,
          teinte: couleurOrangeActivite,
        ),
        CarteTotalActivite(
          libelle: 'Clés récupérées',
          valeur: '${t.clesRecuperees}',
          icone: FontAwesomeIcons.rotateLeft,
          teinte: const Color(0xFF6153C9),
        ),
        CarteTotalActivite(
          libelle: 'Nettoyages',
          valeur: '${t.nettoyages}',
          detail: minutes == null || minutes <= 0
              ? null
              : dureeActivite(minutes),
          icone: FontAwesomeIcons.broom,
          teinte: const Color(0xFF2A7189),
        ),
      ],
    );
  }

  /// Les deux séries comparées, tranche par tranche.
  Widget _graphique(ActiviteAgents activite, GroupeActivite groupe) {
    final serie = activite.serie;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      decoration: carteActivite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Réservations et terrain',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: couleurTexteActivite)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 2),
            child: Text('« Terrain » : les clés remises et récupérées.',
                style: TextStyle(fontSize: 11, color: couleurGrisActivite)),
          ),
          const SizedBox(height: 6),
          if (serie.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 18, 4, 26),
              child: Text('Aucun mouvement sur cette période.',
                  style:
                      TextStyle(fontSize: 12.5, color: couleurGrisActivite)),
            )
          else
            SizedBox(
              height: 240,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  labelRotation: serie.length > 7 ? 45 : 0,
                  labelStyle: const TextStyle(
                      fontSize: 10, color: couleurGrisActivite),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  labelStyle: const TextStyle(
                      fontSize: 10, color: couleurGrisActivite),
                ),
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  textStyle: const TextStyle(
                      fontSize: 11.5, color: couleurTexteActivite),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<TrancheActivite, String>>[
                  SplineSeries<TrancheActivite, String>(
                    name: 'Réservations',
                    color: _couleurReservations,
                    width: 2.5,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataSource: serie,
                    xValueMapper: (d, _) =>
                        libelleTrancheActivite(d.debut, d.tranche, groupe),
                    yValueMapper: (d, _) => d.reservations,
                  ),
                  SplineSeries<TrancheActivite, String>(
                    name: 'Terrain',
                    color: _couleurTerrain,
                    width: 2.5,
                    markerSettings: const MarkerSettings(isVisible: true),
                    dataSource: serie,
                    xValueMapper: (d, _) =>
                        libelleTrancheActivite(d.debut, d.tranche, groupe),
                    yValueMapper: (d, _) => d.terrain,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── La carte d'un agent ───────────────────────────────────────────

  Widget _carteAgent(AgentActivite agent, ActiviteAgents activite,
      ActiviteAgentsState state, ActiviteAgentsCubit cubit,
      GroupeActivite groupe) {
    final ouverte = state.agentsOuverts.contains(agent.id);
    final teinte = _teinteAgent(agent.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: carteActivite,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => cubit.basculerAgent(agent.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: teinte.withValues(alpha: .13),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          agent.initiales,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: teinte),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              agent.nom.isEmpty ? 'Sans nom' : agent.nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: couleurTexteActivite),
                            ),
                            if (agent.rolesTexte.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  agent.rolesTexte,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: couleurGrisActivite),
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: ouverte ? .5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: const Icon(Icons.expand_more,
                            size: 22, color: couleurGrisActivite),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ChiffreActivite(
                          libelle: 'Réserv.',
                          valeur: '${agent.reservations}',
                          teinte: AppColors.primaryColor,
                        ),
                      ),
                      Expanded(
                        child: ChiffreActivite(
                          libelle: 'Apparts loués',
                          valeur: '${agent.biensLoues}',
                          teinte: couleurVertActivite,
                        ),
                      ),
                      Expanded(
                        child: ChiffreActivite(
                          libelle: 'Clés remises',
                          valeur: '${agent.clesRemises}',
                          teinte: couleurOrangeActivite,
                        ),
                      ),
                      Expanded(
                        child: ChiffreActivite(
                          libelle: 'Clés récup.',
                          valeur: '${agent.clesRecuperees}',
                          teinte: const Color(0xFF6153C9),
                        ),
                      ),
                      Expanded(
                        child: ChiffreActivite(
                          libelle: 'Nettoyages',
                          valeur: '${agent.nettoyages}',
                          detail: agent.minutesNettoyage == null ||
                                  agent.minutesNettoyage! <= 0
                              ? null
                              : dureeActivite(agent.minutesNettoyage),
                          teinte: const Color(0xFF2A7189),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: couleurFondActivite,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 15, color: couleurVertActivite),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Encaissé sur ses réservations',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: couleurGrisActivite)),
                        ),
                        Text(
                          montantActivite(agent.montant),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: couleurVertActivite,
                            fontFeatures: chiffresActivite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ouverte
                ? _detailAgent(agent, activite, groupe)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Le détail par tranche d'un agent : ses réservations et son terrain.
  Widget _detailAgent(
      AgentActivite agent, ActiviteAgents activite, GroupeActivite groupe) {
    // Une tranche où l'agent n'a rien fait n'apprend rien : on la saute.
    final tranches = <(TrancheActivite, ActiviteParAgent)>[];
    for (final t in activite.serie) {
      final sien = t.parAgent[agent.id];
      if (sien == null || sien.vide) continue;
      tranches.add((t, sien));
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: couleurFondActivite,
        border: Border(top: BorderSide(color: couleurBordureActivite)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Détail par ${groupe.libelle.toLowerCase()}',
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: couleurGrisActivite),
          ),
          const SizedBox(height: 8),
          if (tranches.isEmpty)
            const Text('Aucun mouvement tranche par tranche.',
                style: TextStyle(fontSize: 12, color: couleurGrisActivite))
          else
            for (final (tranche, sien) in tranches)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        libelleTrancheActivite(
                            tranche.debut, tranche.tranche, groupe),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: couleurTexteActivite,
                            fontFeatures: chiffresActivite),
                      ),
                    ),
                    PastilleActivite(
                      texte: '${sien.reservations} réserv.',
                      teinte: _couleurReservations,
                    ),
                    const SizedBox(width: 6),
                    PastilleActivite(
                      texte: '${sien.terrain} terrain',
                      teinte: _couleurTerrain,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// La teinte du cercle d'initiales : stable pour un même agent.
  Color _teinteAgent(int id) {
    const teintes = [
      AppColors.primaryColor,
      Color(0xFF2E9E5B),
      Color(0xFFE8710A),
      Color(0xFF6153C9),
      Color(0xFF2A7189),
      Color(0xFFC29411),
      Color(0xFF9B3DA0),
      Color(0xFFD64545),
    ];
    return teintes[id.abs() % teintes.length];
  }

  // ── L'export ──────────────────────────────────────────────────────

  /// Ce que l'écran exporte : une ligne par agent, comme la liste.
  TableauExportable? _tableau(ActiviteAgentsState state) {
    final activite = state.activite;
    if (activite == null) return null;
    final t = activite.totaux;
    return TableauExportable(
      titre: 'Activité des agents',
      sousTitre: 'Du ${dateExport(state.du)} au ${dateExport(state.au)}'
          ' — regroupé par ${state.groupe.libelle.toLowerCase()}',
      colonnes: const [
        'Agent',
        'Rôles',
        'Réservations',
        'Appartements loués',
        'Clés remises',
        'Clés récupérées',
        'Nettoyages',
        'Temps de nettoyage',
        'Montant encaissé',
      ],
      lignes: activite.agents
          .map((a) => [
                a.nom,
                a.rolesTexte,
                '${a.reservations}',
                '${a.biensLoues}',
                '${a.clesRemises}',
                '${a.clesRecuperees}',
                '${a.nettoyages}',
                a.minutesNettoyage == null || a.minutesNettoyage! <= 0
                    ? ''
                    : dureeActivite(a.minutesNettoyage),
                montantExport(a.montant),
              ])
          .toList(),
      totaux: [
        'TOTAL',
        '',
        '${t.reservations}',
        '${t.biensLoues}',
        '${t.clesRemises}',
        '${t.clesRecuperees}',
        '${t.nettoyages}',
        activite.minutesNettoyage == null
            ? ''
            : dureeActivite(activite.minutesNettoyage),
        montantExport(
            activite.agents.fold<double>(0, (somme, a) => somme + a.montant)),
      ],
    );
  }
}
