import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/components/statut_bien_chip.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/cubit/calendrier_bien_cubit.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/fiche_bail.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/fiche_reservation.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/mois_calendrier.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/add_reservation/pre_remplissage_reservation.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/manager.dart';

/// Calendrier de gestion d'un bien, a la maniere d'Airbnb : prix des
/// nuits, blocages et reservations (historique compris).
class CalendrierBienPage extends StatefulWidget {
  final int bienId;
  final String? titre;

  const CalendrierBienPage({super.key, required this.bienId, this.titre});

  static Widget page(int bienId, {String? titre}) {
    return BlocProvider(
      create: (_) => CalendrierBienCubit(bienId, titre: titre)..charger(),
      child: CalendrierBienPage(bienId: bienId, titre: titre),
    );
  }

  @override
  State<CalendrierBienPage> createState() => _CalendrierBienPageState();
}

class _CalendrierBienPageState extends State<CalendrierBienPage> {
  final Key _centre = UniqueKey();
  final ScrollController _defilement = ScrollController();
  /// Droits du calendrier : prix des nuits, blocage, déblocage.
  final bool _peutPrix = Dependencies.get<Manager>().can(AppPermission.updateNightPrices);
  final bool _peutBloquer = Dependencies.get<Manager>().can(AppPermission.blockDates);
  final bool _peutDebloquer = Dependencies.get<Manager>().can(AppPermission.unblockDates);
  final bool _voitAirbnb = Dependencies.get<Manager>().can(AppPermission.viewAirbnb);
  bool get _peutModifier => _peutPrix || _peutBloquer || _peutDebloquer;
  final bool _peutReserver = Dependencies.get<Manager>().can(AppPermission.createReservation);

  /// Selectionner des nuits sert autant a les gerer (prix, blocage) qu'a
  /// les reserver : celui qui peut creer une reservation selectionne donc
  /// des dates comme un administrateur, sans pouvoir les bloquer.
  bool get _peutSelectionner => _peutModifier || _peutReserver;

  CalendrierBienCubit get _cubit => context.read<CalendrierBienCubit>();

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendrierBienCubit, CalendrierBienState>(
      builder: (context, state) {
        final cal = state.calendrier;
        final titre = (cal?.titre ?? '').isNotEmpty ? cal!.titre! : (widget.titre ?? '');
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Calendrier',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            bottom: state.enCours
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3, color: Colors.white, backgroundColor: Colors.transparent),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: "Aujourd'hui",
                icon: const Icon(Icons.today, color: Colors.white),
                onPressed: cal == null ? null : _allerAujourdhui,
              ),
              if (_voitAirbnb)
              IconButton(
                tooltip: 'Airbnb',
                icon: const FaIcon(FontAwesomeIcons.airbnb, color: Colors.white, size: 20),
                onPressed: () => _ouvrirAirbnb(titre),
              ),
            ],
          ),
          body: _corps(state, titre),
          // Une selection qui touche une reservation Airbnb ne se reserve
          // pas : le panneau l'indique a la place du bouton.
          floatingActionButton: _peutReserver && cal != null && !_selectionSurAirbnb(state, cal)
              ? FloatingActionButton.extended(
                  heroTag: 'ajouter-reservation-calendrier',
                  onPressed: () => _ajouterReservation(state),
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une réservation', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
          bottomNavigationBar: cal != null && state.aSelection ? _panneauSelection(state, cal) : null,
        );
      },
    );
  }

  Widget _corps(CalendrierBienState state, String titre) {
    if (state.statut == AppStatus.error && state.calendrier == null) {
      return Center(
        child: MyErrorWidget(
          error: state.erreur ?? "Le calendrier n'a pas pu être chargé.",
          action: 'Réessayer',
          actionCLick: () => _cubit.charger(),
        ),
      );
    }
    final cal = state.calendrier;
    if (cal == null) return Center(child: MyLoadingIndicator());

    return Column(
      children: [
        _entete(cal, titre),
        _joursSemaine(),
        const Divider(height: 1, color: CouleursCalendrier.bordure),
        Expanded(child: _mois(state, cal)),
      ],
    );
  }

  // ── En-tete ──────────────────────────────────────────────────────

  Widget _entete(CalendrierBien cal, String titre) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: CouleursCalendrier.bordure)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titre.isNotEmpty)
                      Text(titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(
                      style: const TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux),
                      children: [
                        const TextSpan(text: 'Prix habituel : '),
                        TextSpan(
                          text: '${prixSimple(cal.prixBase)} MAD',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: CouleursCalendrier.texte),
                        ),
                        const TextSpan(text: ' / nuit'),
                      ],
                    )),
                    if (cal.statutJour != null) ...[
                      const SizedBox(height: 6),
                      StatutBienChip(statut: cal.statutJour!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _legende(_puce(Colors.white, bordure: true), 'Disponible'),
                _legende(_puce(CouleursCalendrier.paye), 'Réservée'),
                _legende(_puce(CouleursCalendrier.passee), 'Passée'),
                _legende(_puce(CouleursAirbnb.rose), 'Airbnb'),
                _legende(_puce(CouleursCalendrier.bail), 'Bail longue durée'),
                _legende(
                  Container(
                    width: 16,
                    height: 12,
                    decoration: BoxDecoration(
                      color: CouleursCalendrier.bloque,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      child: CustomPaint(painter: RayuresPainter()),
                    ),
                  ),
                  'Bloquée',
                ),
                _legende(
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: CouleursCalendrier.prixSpecial, shape: BoxShape.circle),
                  ),
                  'Prix personnalisé',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _puce(Color couleur, {bool bordure = false}) => Container(
        width: 16,
        height: 10,
        decoration: BoxDecoration(
          color: couleur,
          borderRadius: BorderRadius.circular(5),
          border: bordure ? Border.all(color: CouleursCalendrier.rayures) : null,
        ),
      );

  Widget _legende(Widget puce, String texte) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          children: [
            puce,
            const SizedBox(width: 5),
            Text(texte, style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux)),
          ],
        ),
      );

  Widget _joursSemaine() {
    const initiales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          for (int i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  initiales[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: i >= 5 ? AppColors.primaryColor : CouleursCalendrier.texteDoux,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Les mois ─────────────────────────────────────────────────────

  Widget _mois(CalendrierBienState state, CalendrierBien cal) {
    final t = aujourdhui();
    final moisCourant = DateTime(t.year, t.month, 1);
    final du = state.du ?? cal.du;
    final au = state.au ?? cal.au;

    // Mois anterieurs (du plus recent au plus ancien) au-dessus du centre.
    final avant = <DateTime>[];
    for (var m = DateTime(moisCourant.year, moisCourant.month - 1, 1);
        !m.isBefore(DateTime(du.year, du.month, 1));
        m = DateTime(m.year, m.month - 1, 1)) {
      avant.add(m);
    }
    final apres = <DateTime>[];
    for (var m = moisCourant; !m.isAfter(au); m = DateTime(m.year, m.month + 1, 1)) {
      apres.add(m);
    }

    Widget mois(DateTime m) => MoisCalendrier(
          key: ValueKey(m),
          mois: m,
          calendrier: cal,
          estSelectionne: state.estSelectionne,
          debutSelection: state.debut,
          finSelection: state.fin,
          onTap: (j) => _toucher(state, cal, j),
        );

    return RefreshIndicator(
      onRefresh: () async {
        final erreur = await _cubit.rafraichir();
        if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
      },
      child: CustomScrollView(
        controller: _defilement,
        center: _centre,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _boutonPrecedents(state)),
          // Avant le centre, la liste pousse vers le haut : l'indice 0
          // est le mois le plus proche.
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => mois(avant[i]),
              childCount: avant.length,
            ),
          ),
          SliverList(
            key: _centre,
            delegate: SliverChildBuilderDelegate(
              (_, i) => mois(apres[i]),
              childCount: apres.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Text(
                'Calendrier affiché jusqu’au ${dateMoyenne(au)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: CouleursCalendrier.texteDoux),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boutonPrecedents(CalendrierBienState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: state.chargementAnterieur
              ? null
              : () async {
                  final erreur = await _cubit.chargerMoisPrecedents();
                  if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
                },
          icon: state.chargementAnterieur
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.history, size: 18),
          label: const Text('Voir les mois précédents'),
          style: OutlinedButton.styleFrom(
            foregroundColor: CouleursCalendrier.texte,
            side: const BorderSide(color: CouleursCalendrier.bordure),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirAirbnb(String titre) async {
    await GoRouter.of(context).push(cheminAirbnbBien(widget.bienId, titre: titre));
    // Un lien enregistre ou synchronise change les sejours Airbnb.
    if (mounted) await _cubit.rafraichir();
  }

  /// Formulaire de reservation du bien, aux nuits selectionnees s'il y
  /// en a (le depart est le lendemain de la derniere nuit).
  Future<void> _ajouterReservation(CalendrierBienState state) async {
    final debut = state.debut, fin = state.finOuDebut;
    final cal = state.calendrier;
    if (cal != null && _selectionSurAirbnb(state, cal)) {
      afficherMessage(context, 'Dates réservées sur Airbnb : elles ne peuvent pas être réservées ici.',
          erreur: true);
      return;
    }
    final avecDates = debut != null && fin != null && !debut.isBefore(aujourdhui());
    final cree = await ouvrirAjoutReservation(
      context,
      widget.bienId,
      preRemplissage: avecDates
          ? PreRemplissageReservation(
              arrivee: debut,
              depart: DateTime(fin.year, fin.month, fin.day + 1),
            )
          : null,
    );
    if (!cree || !mounted) return;
    _cubit.annulerSelection();
    final erreur = await _cubit.rafraichir();
    if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
  }

  /// La selection contient une nuit reservee sur Airbnb (un simple
  /// blocage Airbnb reste libre) : elle ne peut pas etre reservee, par
  /// l'administrateur comme par l'agent.
  bool _selectionSurAirbnb(CalendrierBienState state, CalendrierBien cal) =>
      state.aSelection && state.nuitsSelectionnees.any((n) => cal.reservationAirbnbDe(n) != null);

  /// Fiche d'un sejour Airbnb ; un contrat cree depuis la fiche (ou un
  /// retour de la reservation) recharge le calendrier.
  Future<void> _ouvrirSejourAirbnb(SejourAirbnb sejour) async {
    final change = await ouvrirFicheSejourAirbnb(context, sejour, bienId: widget.bienId);
    if (!change || !mounted) return;
    final erreur = await _cubit.rafraichir();
    if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
  }

  void _allerAujourdhui() {
    // Le mois courant est l'origine du defilement.
    if (!_defilement.hasClients) return;
    _defilement.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  // ── Toucher un jour ──────────────────────────────────────────────

  void _toucher(CalendrierBienState state, CalendrierBien cal, DateTime jour) {
    final reservation = cal.reservationDe(jour);
    final passe = jour.isBefore(aujourdhui());
    final enSelection = state.debut != null && state.fin == null;

    // Une selection commencee se termine sur n'importe quel jour a venir.
    if (_peutSelectionner && enSelection && !passe) {
      HapticFeedback.selectionClick();
      _cubit.toucherJour(jour);
      return;
    }
    if (reservation != null) {
      ouvrirFicheReservation(context, _cubit, reservation);
      return;
    }
    final bail = cal.bailDe(jour);
    if (bail != null) {
      ouvrirFicheBail(context, _cubit, bail);
      return;
    }
    // Une reservation Airbnb occupe le jour ; un jour seulement bloque sur
    // Airbnb reste reservable ici : il se selectionne comme un jour libre.
    final sejourAirbnb = cal.sejourAirbnbDe(jour);
    if (sejourAirbnb != null &&
        (sejourAirbnb.estReservation || passe || !_peutSelectionner)) {
      _ouvrirSejourAirbnb(sejourAirbnb);
      return;
    }
    if (passe) {
      final blocage = cal.blocageDe(jour);
      afficherMessage(
        context,
        blocage != null
            ? 'Bloquée${(blocage.motif ?? '').isEmpty ? '' : ' : ${blocage.motif}'}'
                '${(blocage.par ?? '').isEmpty ? '' : ' (par ${blocage.par})'}'
            : 'Les jours passés ne peuvent pas être modifiés.',
      );
      return;
    }
    if (!_peutSelectionner) {
      final blocage = cal.blocageDe(jour);
      afficherMessage(
        context,
        blocage != null
            ? 'Bloquée${(blocage.motif ?? '').isEmpty ? '' : ' : ${blocage.motif}'}'
            : '${dateLongue(jour)} : ${prixSimple(cal.prixDe(jour))} MAD / nuit',
      );
      return;
    }
    HapticFeedback.selectionClick();
    _cubit.toucherJour(jour);
  }

  // ── Panneau de selection ─────────────────────────────────────────

  Widget _panneauSelection(CalendrierBienState state, CalendrierBien cal) {
    final nuits = state.nuitsSelectionnees;
    final du = state.debut!;
    final au = state.finOuDebut!;
    // Un bail ou une reservation Airbnb occupe ses jours comme une
    // reservation ; un jour seulement bloque sur Airbnb reste libre.
    final aReservation = nuits.any(cal.estOccupe);
    final aNuitAirbnb = nuits.any((n) => cal.reservationAirbnbDe(n) != null);
    final aBlocage = nuits.any((n) => cal.blocageDe(n) != null);
    final aLibre = nuits.any((n) => cal.blocageDe(n) == null && !cal.estOccupe(n));
    final aPrixSpecial = nuits.any(cal.aPrixSpecial);
    final prix = nuits.map(cal.prixDe).toSet();
    final blocage = nuits.length == 1 ? cal.blocageDe(du) : null;

    final periode = state.fin == null || du == au
        ? dateLongue(du)
        : 'Du ${dateCourte(du)} au ${dateMoyenne(au)}';

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Color(0x2617262E), blurRadius: 18, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${periode[0].toUpperCase()}${periode.substring(1)}',
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          pluriel(nuits.length, 'nuit'),
                          prix.length == 1 ? '${prixSimple(prix.first)} MAD / nuit' : 'prix variables',
                          if (state.fin == null) 'touchez le dernier jour',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux),
                      ),
                      if (blocage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Bloquée${(blocage.motif ?? '').isEmpty ? '' : ' : ${blocage.motif}'}'
                            '${(blocage.par ?? '').isEmpty ? '' : ' (par ${blocage.par})'}',
                            style: const TextStyle(fontSize: 12, color: CouleursCalendrier.erreur),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Annuler la sélection',
                  onPressed: _cubit.annulerSelection,
                  icon: const Icon(Icons.close, color: CouleursCalendrier.texteDoux),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Prix et blocages restent reserves a qui peut modifier
                  // le bien : le panneau n'offre que les actions permises.
                  if (_peutModifier) ...[
                    if (_peutPrix)
                    _action(Icons.sell_outlined, 'Modifier le prix', AppColors.primaryColor,
                        state.enCours ? null : () => _modifierPrix(cal, prix), plein: true),
                    if (aPrixSpecial && _peutPrix)
                      _action(Icons.restart_alt, 'Prix habituel', CouleursCalendrier.prixSpecial,
                          state.enCours ? null : () => _prixHabituel(nuits.length, cal)),
                    if (aLibre && _peutBloquer)
                      _action(Icons.lock_outline, 'Bloquer', CouleursCalendrier.erreur,
                          state.enCours ? null : () => _bloquer(du, au, nuits.length, aReservation)),
                    if (aBlocage && _peutDebloquer)
                      _action(Icons.lock_open, 'Débloquer', const Color(0xFF2E7D32),
                          state.enCours ? null : () => _debloquer(du, au)),
                  ],
                  // Sans droit de modification, la selection ne sert qu'a
                  // reserver : l'action passe alors au premier plan.
                  if (!_peutModifier &&
                      _peutReserver &&
                      !aReservation &&
                      !aNuitAirbnb &&
                      !du.isBefore(aujourdhui()))
                    _action(Icons.event_available, 'Réserver ces dates', AppColors.primaryColor,
                        state.enCours ? null : () => _ajouterReservation(state), plein: true),
                  // Reservee sur Airbnb : rien a reserver ici, pour
                  // personne (administrateur compris).
                  if (aNuitAirbnb) _datesAirbnb(),
                  _action(Icons.close, 'Annuler la sélection', CouleursCalendrier.texteDoux,
                      _cubit.annulerSelection),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A la place de « Réserver ces dates » quand la selection touche une
  /// reservation Airbnb.
  Widget _datesAirbnb() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: CouleursAirbnb.rose.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CouleursAirbnb.rose.withValues(alpha: .45)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.airbnb, size: 16, color: CouleursAirbnb.rose),
            SizedBox(width: 8),
            Text('Dates réservées sur Airbnb',
                style: TextStyle(fontWeight: FontWeight.w700, color: CouleursAirbnb.rose)),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icone, String texte, Color couleur, VoidCallback? onTap, {bool plein = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: plein
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icone, size: 18),
              label: Text(texte),
              style: ElevatedButton.styleFrom(
                backgroundColor: couleur,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icone, size: 18),
              label: Text(texte),
              style: OutlinedButton.styleFrom(
                foregroundColor: couleur,
                side: BorderSide(color: couleur.withValues(alpha: .45)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }

  void _resultat(String? erreur, String succes) {
    if (!mounted) return;
    afficherMessage(context, erreur ?? succes, erreur: erreur != null);
  }

  Future<void> _modifierPrix(CalendrierBien cal, Set<double> prixActuels) async {
    final controleur = TextEditingController(
      text: prixActuels.length == 1 ? prixSimple(prixActuels.first) : '',
    );
    final nuits = _cubit.state.nuitsSelectionnees.length;
    final prix = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setEtat) {
          final valeur = lireMontant(controleur.text);
          final valide = valeur != null && valeur > 0;
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Prix par nuit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pluriel(nuits, 'nuit')} sélectionnée${nuits > 1 ? 's' : ''}. '
                  'Prix habituel : ${prixSimple(cal.prixBase)} MAD.',
                  style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texteDoux),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controleur,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  onChanged: (_) => setEtat(() {}),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    suffixText: 'MAD',
                    hintText: '0',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (valide && nuits > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Total pour la période : ${montantLisible(valeur * nuits)}',
                        style: const TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: valide ? () => Navigator.of(ctx).pop(valeur) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    if (prix == null || !mounted) return;
    _resultat(await _cubit.definirPrix(prix), 'Prix enregistré.');
  }

  Future<void> _prixHabituel(int nuits, CalendrierBien cal) async {
    final ok = await confirmer(
      context,
      titre: 'Revenir au prix habituel ?',
      message: 'Les ${pluriel(nuits, 'nuit')} sélectionnée${nuits > 1 ? 's' : ''} '
          'repasseront à ${prixSimple(cal.prixBase)} MAD.',
      action: 'Confirmer',
      couleur: CouleursCalendrier.prixSpecial,
    );
    if (!ok || !mounted) return;
    _resultat(await _cubit.prixHabituel(), 'Prix habituel rétabli.');
  }

  Future<void> _bloquer(DateTime du, DateTime au, int nuits, bool aReservation) async {
    if (aReservation) {
      afficherMessage(
        context,
        'La période contient une réservation, un bail ou une réservation Airbnb : elle ne peut pas être bloquée.',
        erreur: true,
      );
      return;
    }
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bloquer ces dates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Du ${dateMoyenne(du)} au ${dateMoyenne(au)} (${pluriel(nuits, 'nuit')}). '
              'Le bien ne pourra pas être réservé pendant cette période.',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: motif,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Motif (facultatif)',
                hintText: 'Travaux, séjour du propriétaire…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CouleursCalendrier.erreur,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
    final texte = motif.text;
    if (ok != true || !mounted) return;
    _resultat(await _cubit.bloquer(texte), 'Dates bloquées.');
  }

  Future<void> _debloquer(DateTime du, DateTime au) async {
    final ok = await confirmer(
      context,
      titre: 'Débloquer ces dates ?',
      message: 'Du ${dateMoyenne(du)} au ${dateMoyenne(au)} : le bien redeviendra réservable.',
      action: 'Débloquer',
      couleur: const Color(0xFF2E7D32),
    );
    if (!ok || !mounted) return;
    _resultat(await _cubit.debloquer(), 'Dates débloquées.');
  }
}
