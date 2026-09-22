import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/baux/cubit/baux_cubit.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/routes.dart';

/// Location longue duree : tableau de bord, baux et logements.
class BauxPage extends StatefulWidget {
  /// Onglet d'ouverture : tableau, baux ou logements.
  final String? onglet;

  /// Filtre d'ouverture de l'onglet : actif, termine, tous, impayes, finissants
  /// pour les baux ; tous, loues ou libres pour les logements.
  final String? filtre;

  const BauxPage({super.key, this.onglet, this.filtre});

  static const List<String> onglets = ['tableau', 'baux', 'logements'];

  static Widget page({String? onglet, String? filtre}) => BlocProvider(
        create: (_) => BauxCubit(
          filtre: onglet == 'baux' && _filtresBaux.containsKey(filtre) ? filtre! : 'actif',
        )..toutCharger(),
        child: BauxPage(onglet: onglet, filtre: filtre),
      );

  static const Map<String, String> _filtresBaux = {
    'actif': 'Actifs',
    'termine': 'Terminés',
    'tous': 'Tous',
    'impayes': 'Impayés',
    'finissants': 'Se terminent',
  };

  @override
  State<BauxPage> createState() => _BauxPageState();
}

class _BauxPageState extends State<BauxPage> {
  final TextEditingController _recherche = TextEditingController();
  Timer? _attente;

  /// Filtre de l'onglet Logements : tous, loues ou libres.
  late String _filtreLogements =
      widget.onglet == 'logements' && const ['tous', 'loues', 'libres'].contains(widget.filtre)
          ? widget.filtre!
          : 'tous';

  BauxCubit get _cubit => context.read<BauxCubit>();

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _surRecherche(String texte) {
    setState(() {});
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _cubit.rechercher(texte);
    });
  }

  Future<void> _ouvrirBail(int id, {Bail? bail, bool nouveau = false}) async {
    final cubit = _cubit;
    await GoRouter.of(context).push(cheminBail(id, nouveau: nouveau), extra: bail);
    cubit.actualiser();
  }

  Future<void> _nouveauBail({BienLongueDuree? bien}) async {
    final cubit = _cubit;
    final cree = await GoRouter.of(context).push<Bail>(Routes.bailForm, extra: bien);
    cubit.actualiser();
    if (cree != null && mounted) _ouvrirBail(cree.id, bail: cree, nouveau: true);
  }

  @override
  Widget build(BuildContext context) {
    final onglet = BauxPage.onglets.indexOf(widget.onglet ?? '');
    return DefaultTabController(
      length: 3,
      initialIndex: onglet < 0 ? 0 : onglet,
      child: Scaffold(
        backgroundColor: CouleursBail.fond,
        appBar: AppBar(
          title: const Text('Location longue durée',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryColor,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: [
              Tab(text: 'Tableau de bord'),
              Tab(text: 'Baux'),
              Tab(text: 'Logements'),
            ],
          ),
        ),
        floatingActionButton: peutCreerBail
            ? FloatingActionButton.extended(
                onPressed: () => _nouveauBail(),
                backgroundColor: CouleursBail.teinte,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nouveau contrat', style: TextStyle(color: Colors.white)),
              )
            : null,
        body: BlocBuilder<BauxCubit, BauxState>(
          builder: (context, state) => TabBarView(
            children: [
              _tableau(state),
              _baux(state),
              _logements(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chargement(AppStatus? statut, Object? donnees, String? erreur, VoidCallback reessayer) {
    if (donnees != null) return const SizedBox();
    if (statut == AppStatus.error) {
      return Center(
        child: SingleChildScrollView(
          child: MyErrorWidget(error: erreur ?? 'Erreur', action: AppStrings.tryAgain, actionCLick: reessayer),
        ),
      );
    }
    return Center(child: MyLoadingIndicator());
  }

  // ── Tableau de bord ──────────────────────────────────────────────

  Widget _tableau(BauxState state) {
    final t = state.tableau;
    if (t == null) {
      return _chargement(state.statutTableau, t, state.erreurTableau, () => _cubit.chargerTableau());
    }
    final taux = _taux(t);
    return RefreshIndicator(
      onRefresh: () => _cubit.chargerTableau(silencieux: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: _kpi(
                  icone: Icons.warning_amber_rounded,
                  couleur: CouleursBail.retard,
                  titre: 'Loyers impayés',
                  valeur: montantLisible(t.impayesTotal),
                  detail: t.impayesLocataires == 0
                      ? 'Aucun locataire en retard'
                      : pluriel(t.impayesLocataires, 'locataire'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpi(
                  icone: Icons.payments_outlined,
                  couleur: CouleursBail.paye,
                  titre: 'Encaissé ce mois',
                  valeur: montantLisible(t.encaisseMois),
                  detail: 'sur ${montantLisible(t.attenduMois)} attendus',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _kpi(
                  icone: Icons.percent_rounded,
                  couleur: CouleursBail.aPayer,
                  titre: 'Recouvrement du mois',
                  valeur: taux == null ? '—' : '${taux.toStringAsFixed(taux >= 99.95 ? 0 : 1)} %',
                  detail: taux == null ? 'Rien d\'attendu ce mois' : null,
                  progression: taux == null ? null : (taux / 100).clamp(0.0, 1.0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpi(
                  icone: Icons.home_work_outlined,
                  couleur: CouleursBail.teinte,
                  titre: 'Biens libres',
                  valeur: '${t.biensLibres} / ${t.biens}',
                  detail: t.bauxActifs > 1 ? '${t.bauxActifs} baux actifs' : '${t.bauxActifs} bail actif',
                ),
              ),
            ],
          ),
          TitreSection(
            texte: 'Impayés',
            icone: Icons.money_off_csred_outlined,
            couleur: CouleursBail.retard,
            compteur: t.impayes.isEmpty ? null : '${t.impayes.length}',
          ),
          if (t.impayes.isEmpty)
            _vide('Aucun loyer impayé.', Icons.verified_outlined)
          else
            for (final i in t.impayes) ...[_impaye(i), const SizedBox(height: 8)],
          TitreSection(
            texte: 'Prochaines échéances (7 jours)',
            icone: Icons.event_note_outlined,
            couleur: CouleursBail.aPayer,
            compteur: t.prochainesEcheances.isEmpty ? null : '${t.prochainesEcheances.length}',
          ),
          if (t.prochainesEcheances.isEmpty)
            _vide('Aucune échéance dans les 7 prochains jours.', Icons.event_available_outlined)
          else
            for (final l in t.prochainesEcheances) ...[_echeance(l), const SizedBox(height: 8)],
          TitreSection(
            texte: 'Baux qui se terminent (60 jours)',
            icone: Icons.hourglass_bottom_rounded,
            couleur: CouleursBail.partiel,
            compteur: t.finissants.isEmpty ? null : '${t.finissants.length}',
          ),
          if (t.finissants.isEmpty)
            _vide('Aucun bail ne se termine bientôt.', Icons.event_available_outlined)
          else
            for (final f in t.finissants) ...[_finissant(f), const SizedBox(height: 8)],
        ],
      ),
    );
  }

  /// Le serveur peut rendre un pourcentage ou une fraction : on se cale sur les montants.
  double? _taux(TableauBaux t) {
    final v = t.tauxRecouvrementMois;
    if (v == null) return null;
    if (v <= 1.0001 && t.attenduMois > 0) {
      final fraction = t.encaisseMois / t.attenduMois;
      if ((fraction - v).abs() < 0.02 && (fraction * 100 - v).abs() > 0.02) return v * 100;
    }
    return v;
  }

  Widget _kpi({
    required IconData icone,
    required Color couleur,
    required String titre,
    required String valeur,
    String? detail,
    double? progression,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CouleursBail.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: couleur.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icone, size: 18, color: couleur),
          ),
          const SizedBox(height: 10),
          Text(titre, style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur)),
          ),
          if (progression != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progression,
                minHeight: 6,
                color: couleur,
                backgroundColor: couleur.withValues(alpha: .12),
              ),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
          ],
        ],
      ),
    );
  }

  Widget _vide(String texte, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CouleursBail.bordure),
      ),
      child: Row(
        children: [
          Icon(icone, color: CouleursBail.texteDoux, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: const TextStyle(color: CouleursBail.texteDoux, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _impaye(ImpayeBail i) {
    return CarteBail(
      onTap: () => _ouvrirBail(i.bailId),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.locataire.isEmpty ? 'Locataire' : i.locataire,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                const SizedBox(height: 2),
                Text(i.bien,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    PastilleBail(texte: montantLisible(i.reste), couleur: CouleursBail.retard),
                    PastilleBail(texte: '${i.mois} mois', couleur: CouleursBail.partiel),
                    if (i.plusAncien != null)
                      PastilleBail(
                          texte: 'depuis le ${dateBail(i.plusAncien)}', couleur: CouleursBail.texteDoux),
                  ],
                ),
              ],
            ),
          ),
          BoutonsContact(tel: i.tel),
        ],
      ),
    );
  }

  Widget _echeance(Loyer l) {
    final couleur = CouleursBail.statutLoyer(l.statut);
    return CarteBail(
      onTap: l.bailId == 0 ? null : () => _ouvrirBail(l.bailId),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: couleur.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text('${l.echeance?.day ?? ''}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: couleur)),
                Text(l.echeance == null ? '' : moisCourtsFr[l.echeance!.month - 1],
                    style: TextStyle(fontSize: 11, color: couleur)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.locataire ?? 'Locataire',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CouleursBail.texte)),
                Text('${l.bien ?? ''}${l.libelle.isEmpty ? '' : ' • ${l.libelle}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(montantLisible(l.reste > 0 ? l.reste : l.montant),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: CouleursBail.texte)),
              const SizedBox(height: 4),
              PastilleBail(texte: libelleStatutLoyer(l.statut), couleur: couleur),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finissant(BailFinissant f) {
    return CarteBail(
      onTap: () => _ouvrirBail(f.bailId),
      child: Row(
        children: [
          const Icon(Icons.event_busy_outlined, color: CouleursBail.partiel),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.locataire.isEmpty ? 'Locataire' : f.locataire,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CouleursBail.texte)),
                Text(f.bien,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(dateBail(f.dateFin), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (f.joursRestants != null)
                Text(libelleJoursRestants(f.joursRestants),
                    style: const TextStyle(fontSize: 11.5, color: CouleursBail.partiel)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Baux ─────────────────────────────────────────────────────────

  Widget _baux(BauxState state) {
    const filtres = BauxPage._filtresBaux;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Column(
            children: [
              TextField(
                controller: _recherche,
                onChanged: _surRecherche,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Locataire, téléphone, bien…',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon: _recherche.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade500),
                          onPressed: () {
                            _recherche.clear();
                            _surRecherche('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in filtres.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.value),
                          selected: state.filtre == f.key,
                          onSelected: (_) => _cubit.changerFiltre(f.key),
                          selectedColor: (f.key == 'impayes' ? CouleursBail.retard : CouleursBail.teinte)
                              .withValues(alpha: .15),
                          labelStyle: TextStyle(
                            fontWeight: state.filtre == f.key ? FontWeight.w700 : FontWeight.w500,
                            color: state.filtre == f.key
                                ? (f.key == 'impayes' ? CouleursBail.retard : CouleursBail.teinte)
                                : CouleursBail.texte,
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: CouleursBail.bordure),
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (state.statutListe == AppStatus.loading && state.baux != null)
          const LinearProgressIndicator(minHeight: 2, color: CouleursBail.teinte),
        Expanded(child: _listeBaux(state)),
      ],
    );
  }

  Widget _listeBaux(BauxState state) {
    final baux = state.baux;
    if (baux == null) {
      return _chargement(state.statutListe, baux, state.erreurListe, () => _cubit.chargerBaux());
    }
    return RefreshIndicator(
      onRefresh: () => _cubit.chargerBaux(silencieux: true),
      child: baux.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
              children: [
                const Icon(Icons.description_outlined, size: 56, color: CouleursBail.texteDoux),
                const SizedBox(height: 12),
                Text(
                  state.recherche.trim().isNotEmpty
                      ? 'Aucun bail ne correspond à la recherche.'
                      : state.filtre == 'finissants'
                          ? 'Aucun bail ne se termine dans les 60 jours.'
                          : state.filtre == 'impayes'
                              ? 'Aucun loyer impayé.'
                              : 'Aucun bail.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CouleursBail.texteDoux, fontSize: 14),
                ),
                if (state.statutListe == AppStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(state.erreurListe ?? '',
                        textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.retard)),
                  ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
              itemCount: baux.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _carteBail(baux[i]),
            ),
    );
  }

  Widget _carteBail(Bail b) {
    final r = b.resume;
    final jours = b.actif ? libelleJoursRestants(b.joursRestants) : '';
    return CarteBail(
      onTap: () => _ouvrirBail(b.id, bail: b),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhotoBien(url: b.bien.photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(b.bien.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                    ),
                    if (!b.actif) const PastilleBail(texte: 'Terminé', couleur: CouleursBail.aVenir),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: CouleursBail.texteDoux),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(b.locataire.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte)),
                    ),
                    if (b.locataire.listeNoire)
                      const Icon(Icons.block, size: 14, color: CouleursBail.retard),
                  ],
                ),
                const SizedBox(height: 2),
                Text(periodeBail(b.dateDebut, b.dateFin),
                    style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${montantLisible(b.montantMensuel)} / mois',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: CouleursBail.teinte)),
                    if (r.resteDu > 0.004)
                      PastilleBail(
                        texte: 'Reste ${montantLisible(r.resteDu)}',
                        couleur: r.enRetard > 0.004 ? CouleursBail.retard : CouleursBail.partiel,
                        icone: Icons.error_outline,
                      )
                    else
                      const PastilleBail(texte: 'À jour', couleur: CouleursBail.paye, icone: Icons.check_circle_outline),
                    if (jours.isNotEmpty)
                      PastilleBail(
                        texte: jours,
                        couleur: (b.joursRestants ?? 999) <= 60 ? CouleursBail.partiel : CouleursBail.texteDoux,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Logements ────────────────────────────────────────────────────

  Widget _logements(BauxState state) {
    final biens = state.biens;
    if (biens == null) {
      return _chargement(state.statutBiens, biens, state.erreurBiens, () => _cubit.chargerBiens());
    }
    final libres = biens.where((b) => b.libre).length;
    final filtres = {
      'tous': 'Tous les biens (${biens.length})',
      'loues': 'Loués (${biens.length - libres})',
      'libres': 'Libres ($libres)',
    };
    final affiches = biens.where((b) {
      switch (_filtreLogements) {
        case 'loues':
          return !b.libre;
        case 'libres':
          return b.libre;
        default:
          return true;
      }
    }).toList();
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in filtres.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.value),
                      selected: _filtreLogements == f.key,
                      onSelected: (_) => setState(() => _filtreLogements = f.key),
                      selectedColor: CouleursBail.teinte.withValues(alpha: .15),
                      labelStyle: TextStyle(
                        fontWeight: _filtreLogements == f.key ? FontWeight.w700 : FontWeight.w500,
                        color: _filtreLogements == f.key ? CouleursBail.teinte : CouleursBail.texte,
                      ),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: CouleursBail.bordure),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _cubit.chargerBiens(silencieux: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
              children: [
                if (affiches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      biens.isEmpty
                          ? 'Aucun bien proposé en location longue durée.'
                          : _filtreLogements == 'loues'
                              ? 'Aucun logement loué.'
                              : 'Aucun logement libre.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: CouleursBail.texteDoux, fontSize: 14),
                    ),
                  ),
                for (final b in affiches) ...[_carteLogement(b), const SizedBox(height: 10)],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _carteLogement(BienLongueDuree b) {
    final bail = b.bail;
    final loyer = b.loyerAffiche;
    final VoidCallback? action = bail != null
        ? () => _ouvrirBail(bail.id)
        : peutCreerBail
            ? () => _nouveauBail(bien: b)
            : null;
    return CarteBail(
      onTap: action,
      child: Row(
        children: [
          PhotoBien(url: b.photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(b.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                    ),
                    const SizedBox(width: 6),
                    bail == null
                        ? const PastilleBail(texte: 'Libre', couleur: CouleursBail.paye, icone: Icons.lock_open)
                        : PastilleBail(
                            texte: bail.enCours ? 'Loué' : 'Loué (à venir)',
                            couleur: CouleursBail.partiel,
                            icone: Icons.key_rounded,
                          ),
                  ],
                ),
                if ((b.adresse ?? '').isNotEmpty)
                  Text(b.adresse!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                const SizedBox(height: 6),
                Text(
                  loyer == null ? 'Loyer : non renseigné' : 'Loyer : ${montantLisible(loyer)} / mois',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: CouleursBail.teinte),
                ),
                if (bail != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: CouleursBail.texteDoux),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${bail.locataire.isEmpty ? 'Locataire' : bail.locataire}'
                          "${bail.dateFin == null ? '' : " • jusqu'au ${dateBail(bail.dateFin)}"}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (bail == null && peutCreerBail)
            const Icon(Icons.add_circle_outline, color: CouleursBail.teinte)
          else if (bail != null)
            const Icon(Icons.chevron_right, color: CouleursBail.texteDoux),
        ],
      ),
    );
  }
}
