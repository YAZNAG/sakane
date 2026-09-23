import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/apercu_famille_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/carte_groupe.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/cartes_du_jour.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/dossiers_du_type.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/detail_reservation.dart';
import 'package:immobilier/features/immobilier/list_immobilier/ui/components/realestate_widget.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/apercu_famille.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// Une carte d'etat propre a la longue duree ou a la vente : elle ouvre
/// le module correspondant, deja filtre.
class _CarteEtat {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final List<Color> degrade;
  final int? nombre;
  final String? unite;
  final String route;

  const _CarteEtat({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.degrade,
    required this.nombre,
    required this.route,
    this.unite,
  });
}

/// Deuxième niveau : la famille de biens, et ce qui s'y passe aujourd'hui.
///
/// Pour la location courte durée, l'écran tient en deux temps : quatre
/// compteurs qui disent l'état du parc, puis les arrivées et les départs
/// du jour — les seuls gestes qui ne peuvent pas attendre.
///
/// La longue durée et la vente n'ont ni arrivée ni départ : elles gardent
/// leurs propres états, comptés par leur tableau de bord.
class EtatsDuTypePage extends StatelessWidget {
  final TypeBien type;

  const EtatsDuTypePage({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ApercuFamilleCubit(type.code)..charger(),
      child: _EcranFamille(type: type),
    );
  }
}

class _EcranFamille extends StatefulWidget {
  final TypeBien type;

  const _EcranFamille({required this.type});

  @override
  State<_EcranFamille> createState() => _EcranFamilleState();
}

class _EcranFamilleState extends State<_EcranFamille> {
  TableauBaux? _baux;
  TableauVentes? _ventes;

  /// Recherche dans les biens de la famille : la loupe ouvre le champ,
  /// et le champ remplace la liste par ses résultats.
  bool _recherche = false;
  String _terme = '';
  final TextEditingController _champ = TextEditingController();

  TypeBien get type => widget.type;

  bool get _courteDuree => type.code == 'rent-short';

  ApercuFamilleCubit get _apercu => context.read<ApercuFamilleCubit>();

  @override
  void initState() {
    super.initState();
    _chargerCompteurs();
  }

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  /// Les compteurs sont un plus : sans reponse, les cartes restent utilisables.
  Future<void> _chargerCompteurs() async {
    if (!peutVoirBaux) return;
    final depot = Dependencies.get<Repository>();
    try {
      if (type.code == 'rent-long') {
        final t = await depot.fetchTableauBaux();
        if (mounted) setState(() => _baux = t);
      } else if (type.code == 'selle') {
        final t = await depot.fetchTableauVentes();
        if (mounted) setState(() => _ventes = t);
      }
    } catch (_) {}
  }

  Future<void> _actualiser() async {
    final erreur = await Future.wait([
      context.read<GroupesCubit>().charger(),
      _chargerCompteurs(),
      _apercu.rafraichir(),
    ]).then((resultats) => resultats.last as String?);
    if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
  }

  // ── La barre de titre ────────────────────────────────────────────

  AppBar _barre(bool enCours) {
    if (_recherche) {
      return appBarClaire(
        titre: '',
        enCours: enCours,
        retour: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Fermer la recherche',
          onPressed: () => setState(() {
            _recherche = false;
            _terme = '';
            _champ.clear();
          }),
        ),
        actions: [
          Expanded(
            child: TextField(
              controller: _champ,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _terme = v.trim()),
              style: const TextStyle(fontSize: 15, color: texteAccueil),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Rechercher un bien…',
                hintStyle: TextStyle(fontSize: 15, color: texteDouxAccueil),
              ),
            ),
          ),
          if (_terme.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: texteDouxAccueil),
              tooltip: 'Effacer',
              onPressed: () => setState(() {
                _terme = '';
                _champ.clear();
              }),
            ),
        ],
      );
    }

    return appBarClaire(
      titre: type.titre,
      enCours: enCours,
      retour: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Retour',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Rechercher un bien',
          onPressed: () => setState(() => _recherche = true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApercuFamilleCubit, ApercuFamilleState>(
      builder: (context, etat) {
        return Scaffold(
          backgroundColor: fondAccueil,
          appBar: _barre(etat.enCours),
          body: BlocBuilder<GroupesCubit, GroupesState>(
            builder: (context, groupes) {
              if (_recherche) return _resultats(groupes);
              return RefreshIndicator(
                onRefresh: _actualiser,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: _courteDuree
                      ? _corpsCourteDuree(etat, groupes)
                      : _corpsAutresFamilles(groupes),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Courte durée : compteurs, arrivées, départs ──────────────────

  List<Widget> _corpsCourteDuree(
      ApercuFamilleState etat, GroupesState groupes) {
    final compteurs = etat.apercu?.compteurs;
    final chargement = etat.chargement && etat.apercu == null;

    // La liste des biens déjà chargée sert de repli : les compteurs
    // restent justes même si l'aperçu du serveur manque.
    int? nombre(EtatBien e) {
      if (compteurs != null) {
        switch (e) {
          case EtatBien.tous:
            return compteurs.total;
          case EtatBien.reserves:
            return compteurs.reserves;
          case EtatBien.disponibles:
            return compteurs.disponibles;
          case EtatBien.nettoyage:
            return compteurs.nettoyage;
        }
      }
      if (groupes.fetchStatus == AppStatus.loading && groupes.biens == null) {
        return null;
      }
      return groupes.compterEtat(type.code, e);
    }

    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 165 / 118,
        children: [
          CarteCompteur(
            libelle: 'Tous les biens',
            nombre: nombre(EtatBien.tous),
            teinte: AppColors.primaryColor,
            onTap: () => _ouvrir(EtatBien.tous),
          ),
          CarteCompteur(
            libelle: 'Réservés',
            nombre: nombre(EtatBien.reserves),
            teinte: bleuCharte,
            onTap: () => _ouvrir(EtatBien.reserves),
          ),
          CarteCompteur(
            libelle: 'Disponibles',
            nombre: nombre(EtatBien.disponibles),
            teinte: vertAccueil,
            onTap: () => _ouvrir(EtatBien.disponibles),
          ),
          CarteCompteur(
            libelle: 'En nettoyage',
            nombre: nombre(EtatBien.nettoyage),
            teinte: orangeAccueil,
            onTap: () => _ouvrir(EtatBien.nettoyage),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (etat.echecTotal)
        CarteErreurResume(
          message: etat.erreur,
          onReessayer: () => _apercu.charger(),
        )
      else ...[
        TitreDuJour(
          titre: "Arrivées d'aujourd'hui",
          nombre: chargement ? null : (etat.apercu?.arrivees.length ?? 0),
        ),
        if (chargement)
          ...List.filled(2, const SqueletteSejour())
        else if ((etat.apercu?.arrivees ?? const []).isEmpty)
          const LigneVide(texte: "Aucune arrivée aujourd'hui")
        else
          ...etat.apercu!.arrivees.map((s) => CarteSejourDuJour(
                sejour: s,
                sens: SensDuJour.arrivee,
                enCours: etat.enCours,
                onOuvrir: () => _ouvrirReservation(s),
                onConfirmer: _peutConfirmerArrivee(s)
                    ? () => _confirmerArrivee(s)
                    : null,
              )),
        const SizedBox(height: 18),
        TitreDuJour(
          titre: 'Départs du jour',
          nombre: chargement ? null : (etat.apercu?.departs.length ?? 0),
        ),
        if (chargement)
          ...List.filled(2, const SqueletteSejour())
        else if ((etat.apercu?.departs ?? const []).isEmpty)
          const LigneVide(texte: "Aucun départ aujourd'hui")
        else
          ...etat.apercu!.departs.map((s) => CarteSejourDuJour(
                sejour: s,
                sens: SensDuJour.depart,
                enCours: etat.enCours,
                onOuvrir: () => _ouvrirReservation(s),
                onConfirmer:
                    _peutConfirmerDepart(s) ? () => _confirmerDepart(s) : null,
              )),
        // La lecture a échoué mais l'écran garde la réponse précédente :
        // le message reste discret, sous les listes.
        if ((etat.erreur ?? '').isNotEmpty) ...[
          const SizedBox(height: 14),
          CarteErreurResume(
            message: etat.erreur,
            onReessayer: () => _apercu.charger(),
          ),
        ],
      ],
    ];
  }

  /// Un séjour Airbnb ne se confirme pas ici : Airbnb en décide.
  bool _peutConfirmerArrivee(SejourDuJour s) =>
      !s.estAirbnb && s.bienId != null && peut(AppPermission.confirmCheckin);

  bool _peutConfirmerDepart(SejourDuJour s) =>
      !s.estAirbnb && s.bienId != null && peut(AppPermission.confirmCheckout);

  Future<void> _confirmerArrivee(SejourDuJour s) async {
    final ok = await confirmer(
      context,
      titre: "Confirmer l'arrivée ?",
      message: '${s.client.isEmpty ? 'Le client' : s.client} entre dans '
          '« ${s.bien} » aujourd\'hui à ${s.heure}.',
      action: 'Confirmer',
      couleur: AppColors.primaryColor,
    );
    if (!ok || !mounted) return;
    final erreur = await _apercu.confirmerArrivee(s.bienId!);
    if (mounted) {
      afficherMessage(context, erreur ?? 'Arrivée confirmée.',
          erreur: erreur != null);
    }
  }

  Future<void> _confirmerDepart(SejourDuJour s) async {
    final ok = await confirmer(
      context,
      titre: 'Confirmer le départ ?',
      message: '${s.client.isEmpty ? 'Le client' : s.client} quitte '
          '« ${s.bien} » aujourd\'hui à ${s.heure}.',
      action: 'Confirmer',
      couleur: AppColors.primaryColor,
    );
    if (!ok || !mounted) return;
    final erreur = await _apercu.confirmerDepart(s.bienId!);
    if (mounted) {
      afficherMessage(context, erreur ?? 'Départ confirmé.',
          erreur: erreur != null);
    }
  }

  Future<void> _ouvrirReservation(SejourDuJour s) async {
    if (s.id <= 0) {
      // Sans réservation chez nous (séjour Airbnb), la fiche du bien est
      // ce qui se rapproche le plus du détail attendu.
      if (s.bienId != null) {
        await GoRouter.of(context)
            .push(Routes.homeImmobilier.replaceFirst(':id', '${s.bienId}'));
        if (mounted) await _apercu.rafraichir();
      }
      return;
    }
    final modifie = await DetailReservationPage.ouvrir(context, s.id);
    if (modifie && mounted) await _apercu.rafraichir();
  }

  // ── Longue durée et vente : les états de leur module ─────────────

  List<_CarteEtat> get _cartesLongueDuree {
    final t = _baux;
    return [
      _CarteEtat(
        titre: 'Loués',
        sousTitre: 'Un bail en cours',
        icone: Icons.key_rounded,
        degrade: const [Color(0xFF6D4AB0), Color(0xFFB06AB3)],
        nombre: t == null ? null : t.biens - t.biensLibres,
        route: '${Routes.baux}?onglet=logements&filtre=loues',
      ),
      _CarteEtat(
        titre: 'Libres',
        sousTitre: 'Aucun bail : prêts à être loués',
        icone: Icons.lock_open_rounded,
        degrade: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        nombre: t?.biensLibres,
        route: '${Routes.baux}?onglet=logements&filtre=libres',
      ),
      _CarteEtat(
        titre: 'Loyers impayés',
        sousTitre: t == null || t.impayesTotal <= 0
            ? 'Locataires en retard'
            : 'Reste dû : ${prixSimple(t.impayesTotal)} MAD',
        icone: Icons.money_off_csred_outlined,
        degrade: const [Color(0xFFE53935), Color(0xFFFF7043)],
        nombre: t?.impayesLocataires,
        unite: (t?.impayesLocataires ?? 0) > 1 ? 'LOCATAIRES' : 'LOCATAIRE',
        route: '${Routes.baux}?onglet=baux&filtre=impayes',
      ),
      _CarteEtat(
        titre: 'Baux qui se terminent',
        sousTitre: 'Dans les 60 prochains jours',
        icone: Icons.hourglass_bottom_rounded,
        degrade: const [Color(0xFFEF6C00), Color(0xFFFFB300)],
        nombre: t?.finissants.length,
        unite: (t?.finissants.length ?? 0) > 1 ? 'BAUX' : 'BAIL',
        route: '${Routes.baux}?onglet=baux&filtre=finissants',
      ),
    ];
  }

  List<_CarteEtat> get _cartesVente {
    final t = _ventes;
    return [
      _CarteEtat(
        titre: 'À vendre',
        sousTitre: 'En vente, sans compromis',
        icone: Icons.sell_outlined,
        degrade: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        nombre: t?.aVendre,
        route: cheminVentes(filtre: 'a_vendre'),
      ),
      _CarteEtat(
        titre: 'Sous compromis',
        sousTitre: 'Compromis de vente signé',
        icone: Icons.handshake_outlined,
        degrade: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
        nombre: t?.compromis,
        route: cheminVentes(filtre: 'compromis'),
      ),
      _CarteEtat(
        titre: 'Vendus',
        sousTitre: 'Ventes conclues',
        icone: Icons.verified_outlined,
        degrade: const [Color(0xFF6D4AB0), Color(0xFFB06AB3)],
        nombre: t?.vendus,
        route: cheminVentes(filtre: 'vendu'),
      ),
      _CarteEtat(
        titre: 'Sans mandat',
        sousTitre: 'Aucun mandat de vente actif',
        icone: Icons.assignment_late_outlined,
        degrade: const [Color(0xFFEF6C00), Color(0xFFFFB300)],
        nombre: t?.sansMandat,
        route: cheminVentes(filtre: 'sans_mandat'),
      ),
      _CarteEtat(
        titre: 'Visites',
        sousTitre: 'Les visites récentes',
        icone: Icons.directions_walk,
        degrade: const [Color(0xFFE53935), Color(0xFFFF7043)],
        nombre: t?.visitesCeMois,
        unite: 'CE MOIS',
        route: Routes.visitesVentes,
      ),
    ];
  }

  List<Widget> _corpsAutresFamilles(GroupesState groupes) {
    if (groupes.fetchStatus == AppStatus.loading && groupes.biens == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final cartes =
        type.code == 'rent-long' ? _cartesLongueDuree : _cartesVente;

    return [
      // « Tous les biens » garde les dossiers : c'est la qu'on range.
      CarteGroupe(
        nombre: groupes.compterEtat(type.code, EtatBien.tous),
        titre: EtatBien.tous.titre,
        sousTitre: EtatBien.tous.sousTitre,
        libelleAction: 'Voir les dossiers',
        icone: EtatBien.tous.icone,
        degrade: EtatBien.tous.degrade,
        onTap: () => _ouvrir(EtatBien.tous),
      ),
      ...cartes.map((c) => CarteGroupe(
            nombre: c.nombre,
            unite: c.unite,
            titre: c.titre,
            sousTitre: c.sousTitre,
            libelleAction: 'Voir la liste',
            icone: c.icone,
            degrade: c.degrade,
            onTap: () => _ouvrirModule(c.route),
          )),
    ];
  }

  // ── Recherche dans les biens de la famille ──────────────────────

  Widget _resultats(GroupesState groupes) {
    final terme = _terme.toLowerCase();
    final tous = (groupes.biens ?? const <Realestate>[])
        .where((b) => b.typeTransaction?.value == type.code)
        .toList();

    if (terme.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Tapez le nom, la ville ou la référence d\'un bien.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: texteDouxAccueil),
          ),
        ),
      );
    }

    final trouves = tous.where((b) {
      final champs = [
        b.title,
        b.address?.address,
        b.address?.city?.name,
        b.dossier?.nom,
        '${b.id}',
      ];
      return champs.any((c) => (c ?? '').toLowerCase().contains(terme));
    }).toList();

    if (trouves.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Aucun bien ne correspond à « $_terme ».',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: texteDouxAccueil),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: trouves.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RealestateWidget(
          realestate: trouves[i],
          onClick: (b) => GoRouter.of(context)
              .push(Routes.homeImmobilier.replaceFirst(':id', '${b.id}')),
        ),
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────

  Future<void> _ouvrirModule(String route) async {
    await GoRouter.of(context).push(route);
    if (mounted) _chargerCompteurs();
  }

  /// Chaque etat passe par les dossiers : c'est la structure de rangement
  /// de cette application, elle vaut aussi pour les etats operationnels.
  void _ouvrir(EtatBien etat) {
    final groupes = context.read<GroupesCubit>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: groupes,
        child: DossiersDuTypePage(type: type, etat: etat),
      ),
    ));
  }
}
