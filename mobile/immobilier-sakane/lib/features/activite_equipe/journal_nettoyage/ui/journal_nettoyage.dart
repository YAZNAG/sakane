import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/features/activite_equipe/journal_nettoyage/cubit/journal_nettoyage_cubit.dart';
import 'package:immobilier/models/journal_nettoyage.dart';

/// « Journal de nettoyage » : l'historique de tous les appartements
/// nettoyés, jour par jour.
///
/// Chaque journée est une section repliable ; la plus récente s'ouvre
/// d'elle-même. Le serveur reste juge des droits : il répond 403 si
/// « view_cleaning_log » manque.
class JournalNettoyagePage extends StatefulWidget {
  const JournalNettoyagePage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => JournalNettoyageCubit()..charger(),
        child: const JournalNettoyagePage(),
      );

  @override
  State<JournalNettoyagePage> createState() => _JournalNettoyagePageState();
}

class _JournalNettoyagePageState extends State<JournalNettoyagePage> {
  final TextEditingController _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalNettoyageCubit, JournalNettoyageState>(
      builder: (context, state) {
        final cubit = context.read<JournalNettoyageCubit>();
        return Scaffold(
          backgroundColor: const Color(0xFFF5F8FA),
          appBar: AppBar(
            title: const Text('Journal de nettoyage',
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
                _filtres(state, cubit),
                const SizedBox(height: 10),
                if (state.erreur != null) ...[
                  ErreurActivite(
                      message: state.erreur!, onReessayer: cubit.charger),
                  const SizedBox(height: 10),
                ],
                if (state.premierChargement)
                  const SqueletteActivite(totaux: 4, lignes: 5)
                else
                  ..._contenu(state),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Les filtres ───────────────────────────────────────────────────

  Widget _filtres(JournalNettoyageState state, JournalNettoyageCubit cubit) {
    final journal = state.journal;
    final biens = journal?.biens ?? const <BienNettoyage>[];
    final personnes = journal?.personnes ?? const <PersonneNettoyage>[];

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
          TextField(
            controller: _recherche,
            onChanged: cubit.chercher,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: couleurTexteActivite),
            decoration: InputDecoration(
              isDense: true,
              hintText: "Nom de l'appartement ou de la personne",
              hintStyle:
                  const TextStyle(fontSize: 13, color: couleurGrisActivite),
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: couleurGrisActivite),
              suffixIcon: state.recherche.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.close,
                          size: 18, color: couleurGrisActivite),
                      onPressed: () {
                        _recherche.clear();
                        cubit.chercher('');
                      },
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              filled: true,
              fillColor: couleurFondActivite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide:
                    const BorderSide(color: couleurBordureActivite),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide:
                    const BorderSide(color: couleurBordureActivite),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: AppColors.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _liste<int>(
                  icone: Icons.apartment_outlined,
                  libelleTous: 'Tous les appartements',
                  valeur: state.bienId,
                  choix: [
                    for (final b in biens) (b.id, b.nom),
                  ],
                  onChange: cubit.choisirBien,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _liste<int>(
                  icone: Icons.person_outline,
                  libelleTous: 'Tout le monde',
                  valeur: state.agentId,
                  choix: [
                    for (final p in personnes) (p.id, p.nom),
                  ],
                  onChange: cubit.choisirAgent,
                ),
              ),
            ],
          ),
          if (state.enChargement && state.journal != null)
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

  /// Une liste déroulante : « tous » en premier, puis les choix.
  Widget _liste<T>({
    required IconData icone,
    required String libelleTous,
    required T? valeur,
    required List<(T, String)> choix,
    required ValueChanged<T?> onChange,
  }) {
    // Une valeur retenue qui a disparu ferait planter le menu : on la
    // ramène à « tous » le temps que le serveur réponde.
    final connue = valeur != null && choix.any((c) => c.$1 == valeur);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: couleurFondActivite,
        border: Border.all(color: couleurBordureActivite),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icone, size: 17, color: couleurGrisActivite),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T?>(
                value: connue ? valeur : null,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.expand_more,
                    size: 19, color: couleurGrisActivite),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: couleurTexteActivite),
                items: [
                  DropdownMenuItem<T?>(
                    value: null,
                    child: Text(libelleTous,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: couleurGrisActivite)),
                  ),
                  for (final (cle, nom) in choix)
                    DropdownMenuItem<T?>(
                      value: cle,
                      child: Text(nom.isEmpty ? 'Sans nom' : nom,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onChange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Le contenu ────────────────────────────────────────────────────

  List<Widget> _contenu(JournalNettoyageState state) {
    final journal = state.journal;
    if (journal == null) {
      return const [
        VideActivite(
          icone: Icons.cleaning_services_outlined,
          titre: 'Rien à afficher',
          detail: "Tirez l'écran vers le bas pour charger le journal.",
        ),
      ];
    }

    return [
      _bandeauTotaux(journal),
      const SizedBox(height: 12),
      if (journal.parJour.isEmpty || journal.nettoyages.isEmpty)
        VideActivite(
          icone: Icons.cleaning_services_outlined,
          titre: state.filtre
              ? 'Aucun nettoyage avec ces filtres'
              : 'Aucun nettoyage sur cette période',
          detail: state.filtre
              ? 'Effacez la recherche ou remettez les listes sur « tous » '
                  'pour voir tout le journal.'
              : "Aucun appartement n'a été nettoyé entre ces deux dates. "
                  'Élargissez la période.',
        )
      else
        for (var i = 0; i < journal.parJour.length; i++)
          _sectionJour(journal, journal.parJour[i], i == 0),
    ];
  }

  Widget _bandeauTotaux(JournalNettoyage journal) {
    final t = journal.totaux;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        CarteTotalActivite(
          libelle: 'Nettoyages',
          valeur: '${t.nombre}',
          icone: FontAwesomeIcons.broom,
          teinte: AppColors.primaryColor,
        ),
        CarteTotalActivite(
          libelle: 'Appartements',
          valeur: '${t.biens}',
          icone: FontAwesomeIcons.building,
          teinte: couleurVertActivite,
        ),
        CarteTotalActivite(
          libelle: 'Temps total',
          valeur: dureeActivite(t.minutes),
          icone: FontAwesomeIcons.clock,
          teinte: couleurOrangeActivite,
        ),
        CarteTotalActivite(
          libelle: 'Durée moyenne',
          valeur: dureeActivite(t.moyenne),
          icone: FontAwesomeIcons.stopwatch,
          teinte: const Color(0xFF2A7189),
        ),
      ],
    );
  }

  Widget _sectionJour(
      JournalNettoyage journal, JourNettoyage jour, bool ouverte) {
    final lignes = journal.duJour(jour);
    final titre = libelleJourActivite(jour.jour);
    return SectionRepliableActivite(
      titre: titre[0].toUpperCase() + titre.substring(1),
      sousTitre: '${jour.biens} ${pluriel(jour.biens, 'appartement')}'
          ' · ${dureeActivite(jour.minutes)}',
      ouverteAuDepart: ouverte,
      enfants: [
        if (lignes.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Text('Aucun détail pour cette journée.',
                style: TextStyle(fontSize: 12, color: couleurGrisActivite)),
          )
        else
          for (var i = 0; i < lignes.length; i++)
            _ligne(lignes[i], derniere: i == lignes.length - 1),
      ],
    );
  }

  Widget _ligne(Nettoyage n, {required bool derniere}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: derniere
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF0F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.bien.isEmpty ? 'Appartement inconnu' : n.bien,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: couleurTexteActivite),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: couleurGrisActivite),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        n.par.isEmpty ? 'Personne non précisée' : n.par,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: couleurGrisActivite),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                n.enCours
                    ? 'Depuis ${heureActivite(n.debut)}'
                    : '${heureActivite(n.debut)} → ${heureActivite(n.fin)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: couleurTexteActivite,
                  fontFeatures: chiffresActivite,
                ),
              ),
              const SizedBox(height: 4),
              if (n.enCours)
                const PastilleActivite(
                  texte: 'En cours',
                  teinte: couleurOrangeActivite,
                  icone: Icons.autorenew,
                )
              else
                PastilleActivite(
                  texte: dureeActivite(n.minutes),
                  teinte: couleurVertActivite,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── L'export ──────────────────────────────────────────────────────

  /// Ce que l'écran exporte : une ligne par nettoyage, dans l'ordre affiché.
  TableauExportable? _tableau(JournalNettoyageState state) {
    final journal = state.journal;
    if (journal == null) return null;
    final lignes = <List<String>>[];
    for (final jour in journal.parJour) {
      for (final n in journal.duJour(jour)) {
        lignes.add([
          dateExport(n.debut ?? jour.jour),
          n.bien,
          n.par,
          heureActivite(n.debut),
          n.enCours ? 'En cours' : heureActivite(n.fin),
          n.enCours ? '' : dureeActivite(n.minutes),
        ]);
      }
    }
    final t = journal.totaux;
    return TableauExportable(
      titre: 'Journal de nettoyage',
      sousTitre: 'Du ${dateExport(state.du)} au ${dateExport(state.au)}',
      colonnes: const [
        'Jour',
        'Appartement',
        'Personne',
        'Début',
        'Fin',
        'Durée',
      ],
      lignes: lignes,
      totaux: [
        'TOTAL',
        '${t.biens} ${pluriel(t.biens, 'appartement')}',
        '',
        '',
        '',
        dureeActivite(t.minutes),
      ],
    );
  }
}
