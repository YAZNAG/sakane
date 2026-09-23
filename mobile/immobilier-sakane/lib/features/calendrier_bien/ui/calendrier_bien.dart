import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
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
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_reservation/pre_remplissage_reservation.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/manager.dart';

/// Calendrier de gestion d'un bien : un mois à la fois, le prix de
/// chaque nuit, et les séjours posés en barres continues par-dessus.
///
/// On y lit d'abord ce qui est occupé et ce qui est libre ; on y agit
/// ensuite, en glissant le doigt sur les nuits à changer.
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
  /// Droits du calendrier : prix des nuits, blocage, déblocage.
  final bool _peutPrix = Dependencies.get<Manager>().can(AppPermission.updateNightPrices);
  final bool _peutBloquer = Dependencies.get<Manager>().can(AppPermission.blockDates);
  final bool _peutDebloquer = Dependencies.get<Manager>().can(AppPermission.unblockDates);
  final bool _voitAirbnb = Dependencies.get<Manager>().can(AppPermission.viewAirbnb);
  final bool _peutReserver = Dependencies.get<Manager>().can(AppPermission.createReservation);

  bool get _peutModifier => _peutPrix || _peutBloquer || _peutDebloquer;

  /// Sélectionner des nuits sert autant à les gérer (prix, blocage) qu'à
  /// les réserver : celui qui peut créer une réservation sélectionne donc
  /// des dates comme un administrateur, sans pouvoir les bloquer.
  bool get _peutSelectionner => _peutModifier || _peutReserver;

  /// Le mois affiché, et les deux repères du glissement en cours.
  late DateTime _mois = _moisDe(aujourdhui());
  DateTime? _ancre;
  DateTime? _dernierGlisse;

  CalendrierBienCubit get _cubit => context.read<CalendrierBienCubit>();

  static DateTime _moisDe(DateTime d) => DateTime(d.year, d.month, 1);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendrierBienCubit, CalendrierBienState>(
      builder: (context, state) {
        final cal = state.calendrier;
        final titre = (cal?.titre ?? '').isNotEmpty ? cal!.titre! : (widget.titre ?? '');
        return Scaffold(
          backgroundColor: fondAccueil,
          appBar: _barreTitre(state, titre),
          body: _corps(state),
          // Une sélection ouvre sa propre barre d'actions : le bouton
          // flottant s'efface pour lui laisser le bas de l'écran.
          floatingActionButton: _peutReserver && cal != null && !state.aSelection
              ? FloatingActionButton.extended(
                  heroTag: 'ajouter-reservation-calendrier',
                  onPressed: () => _ajouterReservation(state),
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une réservation',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
          bottomNavigationBar:
              cal != null && state.aSelection ? _barreActions(state, cal) : null,
        );
      },
    );
  }

  // ── La barre de titre ────────────────────────────────────────────

  PreferredSizeWidget _barreTitre(CalendrierBienState state, String titre) {
    return AppBar(
      backgroundColor: fondAccueil,
      surfaceTintColor: fondAccueil,
      foregroundColor: texteAccueil,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Calendrier',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: texteAccueil)),
          if (titre.isNotEmpty)
            Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: texteDouxAccueil),
            ),
        ],
      ),
      actions: [
        if (_voitAirbnb)
          IconButton(
            tooltip: 'Airbnb',
            icon: const FaIcon(FontAwesomeIcons.airbnb, size: 18, color: texteDouxAccueil),
            onPressed: () => _ouvrirAirbnb(titre),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 2),
          child: OutlinedButton(
            onPressed: _mois == _moisDe(aujourdhui()) ? null : _allerAujourdhui,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              disabledForegroundColor: AppColors.primaryColor.withValues(alpha: .5),
              side: BorderSide(color: AppColors.primaryColor.withValues(alpha: .45)),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("Aujourd'hui",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(state.enCours ? 3 : 1),
        child: state.enCours
            ? const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.primaryColor,
                backgroundColor: bordureAccueil,
              )
            : const Divider(height: 1, thickness: 1, color: bordureAccueil),
      ),
    );
  }

  // ── Le corps ─────────────────────────────────────────────────────

  Widget _corps(CalendrierBienState state) {
    final cal = state.calendrier;
    if (cal == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        child: state.statut == AppStatus.error
            ? CarteErreurResume(
                message: state.erreur ?? "Le calendrier n'a pas pu être chargé.",
                onReessayer: () => _cubit.charger(),
              )
            : const _SqueletteCalendrier(),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: () async {
        final erreur = await _cubit.rafraichir();
        if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, 10, 12, state.aSelection ? 24 : 96),
        children: [
          _legende(),
          const SizedBox(height: 12),
          _navigationMois(state, cal),
          if (_estPremierMoisCharge(state)) _voirMoisPrecedents(state),
          const SizedBox(height: 10),
          _joursSemaine(),
          const SizedBox(height: 4),
          MoisCalendrier(
            key: ValueKey(_mois),
            mois: _mois,
            calendrier: cal,
            estSelectionne: state.estSelectionne,
            onTapJour: (j) => _toucher(state, cal, j),
            onTapReservation: (r) => ouvrirFicheReservation(context, _cubit, r),
            onTapBail: (b) => ouvrirFicheBail(context, _cubit, b),
            onTapAirbnb: _ouvrirSejourAirbnb,
            onGlissementDebut: _peutSelectionner ? _glissementDebut : null,
            onGlissementVers: _peutSelectionner ? _glissementVers : null,
            onGlissementFin: _peutSelectionner ? _glissementFin : null,
          ),
          const SizedBox(height: 14),
          _carteAide(),
        ],
      ),
    );
  }

  // ── La légende ───────────────────────────────────────────────────

  Widget _legende() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _pastilleLegende(_carre(CouleursCalendrier.sejourPaye), 'Payé'),
        _pastilleLegende(_carre(CouleursCalendrier.sejourPartiel), 'Partiel'),
        _pastilleLegende(_carre(CouleursCalendrier.sejourNonPaye), 'Non payé'),
        _pastilleLegende(_carre(CouleursCalendrier.sejourAirbnb), 'Airbnb'),
        _pastilleLegende(_carreRaye(), 'Bloqué'),
        _pastilleLegende(_carre(CouleursCalendrier.bail), 'Bail'),
      ],
    );
  }

  Widget _carre(Color couleur) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
      );

  Widget _carreRaye() => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: CouleursCalendrier.bloque,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(3)),
          child: CustomPaint(painter: RayuresPainter()),
        ),
      );

  Widget _pastilleLegende(Widget carre, String texte) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          carre,
          const SizedBox(width: 5),
          Text(texte, style: const TextStyle(fontSize: 11.5, color: texteDouxAccueil)),
        ],
      );

  // ── Le mois affiché ──────────────────────────────────────────────

  Widget _navigationMois(CalendrierBienState state, CalendrierBien cal) {
    final dernier = state.au ?? cal.au;
    final finChargee = DateTime(dernier.year, dernier.month, 1);
    final suivantPossible = !DateTime(_mois.year, _mois.month + 1, 1).isAfter(finChargee);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mois précédent',
              onPressed: state.chargementAnterieur ? null : _moisPrecedent,
              icon: const Icon(Icons.chevron_left, color: texteAccueil),
            ),
            Expanded(
              child: Text(
                titreMois(_mois),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: texteAccueil),
              ),
            ),
            IconButton(
              tooltip: 'Mois suivant',
              onPressed: suivantPossible
                  ? () => setState(() => _mois = DateTime(_mois.year, _mois.month + 1, 1))
                  : null,
              icon: const Icon(Icons.chevron_right, color: texteAccueil),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Prix habituel : ${prixSimple(cal.prixBase)} MAD / nuit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: texteDouxAccueil),
              ),
            ),
            if (cal.statutJour != null) ...[
              const SizedBox(width: 8),
              StatutBienChip(statut: cal.statutJour!, compact: true),
            ],
          ],
        ),
      ],
    );
  }

  /// Le mois affiché est le plus ancien que le serveur a donné.
  bool _estPremierMoisCharge(CalendrierBienState state) {
    final du = state.du ?? state.calendrier?.du;
    return du != null && _mois == DateTime(du.year, du.month, 1);
  }

  Widget _voirMoisPrecedents(CalendrierBienState state) {
    return Center(
      child: TextButton.icon(
        onPressed: state.chargementAnterieur ? null : () => _chargerPrecedents(),
        icon: state.chargementAnterieur
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.history, size: 16),
        label: const Text('Voir les mois précédents', style: TextStyle(fontSize: 12.5)),
        style: TextButton.styleFrom(
          foregroundColor: texteDouxAccueil,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _joursSemaine() {
    const initiales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (int i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                initiales[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: i >= 5 ? AppColors.primaryColor : texteDouxAccueil,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _carteAide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bordureAccueil,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: texteDouxAccueil),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Touchez une barre pour ouvrir la fiche ; glissez sur les jours '
              'pour sélectionner une période.',
              style: TextStyle(fontSize: 12, height: 1.35, color: texteDouxAccueil),
            ),
          ),
        ],
      ),
    );
  }

  // ── Se déplacer dans le temps ────────────────────────────────────

  void _allerAujourdhui() => setState(() => _mois = _moisDe(aujourdhui()));

  Future<void> _chargerPrecedents() async {
    final erreur = await _cubit.chargerMoisPrecedents();
    if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
  }

  /// Le mois d'avant ; s'il n'est pas encore chargé, le serveur en
  /// donne trois de plus avant de l'afficher.
  Future<void> _moisPrecedent() async {
    final cible = DateTime(_mois.year, _mois.month - 1, 1);
    final state = _cubit.state;
    final du = state.du ?? state.calendrier?.du;
    if (du != null && cible.isBefore(DateTime(du.year, du.month, 1))) {
      await _chargerPrecedents();
      if (!mounted) return;
      final nouveau = _cubit.state.du;
      if (nouveau == null || cible.isBefore(DateTime(nouveau.year, nouveau.month, 1))) return;
    }
    if (mounted) setState(() => _mois = cible);
  }

  // ── Airbnb ───────────────────────────────────────────────────────

  Future<void> _ouvrirAirbnb(String titre) async {
    await GoRouter.of(context).push(cheminAirbnbBien(widget.bienId, titre: titre));
    // Un lien enregistré ou synchronisé change les séjours Airbnb.
    if (mounted) await _cubit.rafraichir();
  }

  /// Fiche d'un séjour Airbnb ; un contrat créé depuis la fiche (ou un
  /// retour de la réservation) recharge le calendrier.
  Future<void> _ouvrirSejourAirbnb(SejourAirbnb sejour) async {
    final change = await ouvrirFicheSejourAirbnb(context, sejour, bienId: widget.bienId);
    if (!change || !mounted) return;
    final erreur = await _cubit.rafraichir();
    if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
  }

  /// La sélection contient une nuit réservée sur Airbnb (un simple
  /// blocage Airbnb reste libre) : elle ne peut pas être réservée, par
  /// l'administrateur comme par l'agent.
  bool _selectionSurAirbnb(CalendrierBienState state, CalendrierBien cal) =>
      state.aSelection && state.nuitsSelectionnees.any((n) => cal.reservationAirbnbDe(n) != null);

  /// Formulaire de réservation du bien, aux nuits sélectionnées s'il y
  /// en a (le départ est le lendemain de la dernière nuit).
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

  // ── Choisir des nuits ────────────────────────────────────────────

  /// Le doigt se pose : la période part de ce jour.
  void _glissementDebut(DateTime jour) {
    if (jour.isBefore(aujourdhui())) {
      _ancre = null;
      return;
    }
    _ancre = jour;
    _dernierGlisse = jour;
    HapticFeedback.selectionClick();
    _cubit.selectionner(jour, jour);
  }

  /// Le doigt traverse : la période s'étend jusqu'au jour survolé, en
  /// avant comme en arrière de son point de départ.
  void _glissementVers(DateTime jour) {
    final ancre = _ancre;
    if (ancre == null || jour == _dernierGlisse || jour.isBefore(aujourdhui())) return;
    _dernierGlisse = jour;
    HapticFeedback.selectionClick();
    _cubit.selectionner(ancre, jour);
  }

  void _glissementFin() {
    _ancre = null;
    _dernierGlisse = null;
  }

  /// L'appui simple reste : un jour, puis un second, font la période.
  void _toucher(CalendrierBienState state, CalendrierBien cal, DateTime jour) {
    final reservation = cal.reservationDe(jour);
    final passe = jour.isBefore(aujourdhui());
    final enSelection = state.debut != null && state.fin == null;

    // Une sélection commencée se termine sur n'importe quel jour à venir.
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
    // Une réservation Airbnb occupe le jour ; un jour seulement bloqué sur
    // Airbnb reste réservable ici : il se sélectionne comme un jour libre.
    final sejourAirbnb = cal.sejourAirbnbDe(jour);
    if (sejourAirbnb != null && (sejourAirbnb.estReservation || passe || !_peutSelectionner)) {
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

  // ── La barre d'actions de la sélection ───────────────────────────

  Widget _barreActions(CalendrierBienState state, CalendrierBien cal) {
    final nuits = state.nuitsSelectionnees;
    final du = state.debut!;
    final au = state.finOuDebut!;
    final depart = ajouterJours(au, 1);
    // Un bail ou une réservation Airbnb occupe ses jours comme une
    // réservation ; un jour seulement bloqué sur Airbnb reste libre.
    final aReservation = nuits.any(cal.estOccupe);
    final aNuitAirbnb = nuits.any((n) => cal.reservationAirbnbDe(n) != null);
    final aBlocage = nuits.any((n) => cal.blocageDe(n) != null);
    final aLibre = nuits.any((n) => cal.blocageDe(n) == null && !cal.estOccupe(n));
    final aPrixSpecial = nuits.any(cal.aPrixSpecial);
    final prix = nuits.map(cal.prixDe).toSet();
    final blocage = nuits.length == 1 ? cal.blocageDe(du) : null;
    final occupe = state.enCours;

    // Bloquer et débloquer occupent la même place : la période est
    // libre, ou elle est déjà bloquée.
    final montreDebloquer = aBlocage && !aLibre && _peutDebloquer;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Color(0x2617262E), blurRadius: 18, offset: Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${dateChiffree(du)} → ${dateChiffree(depart)} · ${pluriel(nuits.length, 'nuit')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: texteAccueil),
                  ),
                ),
                TextButton(
                  onPressed: _cubit.annulerSelection,
                  style: TextButton.styleFrom(
                    foregroundColor: texteDouxAccueil,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (blocage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Bloquée${(blocage.motif ?? '').isEmpty ? '' : ' : ${blocage.motif}'}'
                  '${(blocage.par ?? '').isEmpty ? '' : ' (par ${blocage.par})'}',
                  style: const TextStyle(fontSize: 12, color: CouleursCalendrier.erreur),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_peutPrix)
                  Expanded(
                    child: _bouton('Modifier le prix', AppColors.primaryColor,
                        occupe ? null : () => _modifierPrix(cal, prix)),
                  ),
                if (montreDebloquer)
                  Expanded(
                    child: _bouton('Débloquer', const Color(0xFF2E7D32),
                        occupe ? null : () => _debloquer(du, au)),
                  )
                else if (_peutBloquer)
                  Expanded(
                    child: _bouton('Bloquer', CouleursCalendrier.erreur,
                        occupe ? null : () => _bloquer(du, au, nuits.length, aReservation)),
                  ),
                if (_peutReserver)
                  Expanded(
                    child: aNuitAirbnb
                        ? _noteAirbnb()
                        : _bouton(
                            'Réserver',
                            AppColors.primaryColor,
                            occupe || du.isBefore(aujourdhui())
                                ? null
                                : () => _ajouterReservation(state),
                            plein: true,
                          ),
                  ),
              ],
            ),
            // Le retour au prix habituel ne concerne qu'une période déjà
            // personnalisée : il reste discret, sous les trois actions.
            if (aPrixSpecial && _peutPrix)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: occupe ? null : () => _prixHabituel(nuits.length, cal),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Revenir au prix habituel', style: TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: orangeAccueil,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bouton(String texte, Color couleur, VoidCallback? onTap, {bool plein = false}) {
    final libelle = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(texte,
          maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: plein
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: couleur,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: libelle,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: couleur,
                side: BorderSide(color: couleur.withValues(alpha: .45)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: libelle,
            ),
    );
  }

  /// À la place de « Réserver » quand la sélection touche une
  /// réservation Airbnb : ces nuits ne se réservent pas ici.
  Widget _noteAirbnb() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: CouleursCalendrier.sejourAirbnb.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CouleursCalendrier.sejourAirbnb.withValues(alpha: .45)),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Sur Airbnb',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CouleursCalendrier.sejourAirbnb)),
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

/// L'esquisse du calendrier, le temps de la lecture : la légende, le
/// mois, la grille des jours.
class _SqueletteCalendrier extends StatelessWidget {
  const _SqueletteCalendrier();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: const [
            BlocSquelette(hauteur: 11, largeur: 54),
            BlocSquelette(hauteur: 11, largeur: 60),
            BlocSquelette(hauteur: 11, largeur: 70),
            BlocSquelette(hauteur: 11, largeur: 58),
          ],
        ),
        const SizedBox(height: 20),
        const Center(child: BlocSquelette(hauteur: 18, largeur: 150)),
        const SizedBox(height: 10),
        const Center(child: BlocSquelette(hauteur: 11, largeur: 180)),
        const SizedBox(height: 18),
        for (int s = 0; s < 5; s++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                for (int c = 0; c < 7; c++)
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(1.5),
                      child: BlocSquelette(hauteur: 66, rayon: 10),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
