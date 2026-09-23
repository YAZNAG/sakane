import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/components/statut_bien_chip.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/offline/synchronisation.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart';
import 'package:immobilier/features/gestion_immobilier/immobilier_by_status/ui/components/prolonger_dialogue.dart';
import 'package:immobilier/features/gestion_immobilier/immobilier_by_status/ui/components/shrink_dialogue.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/features/immobilier/home_immobilier/cubit/apercu_bien_cubit.dart';
import 'package:immobilier/features/immobilier/home_immobilier/cubit/home_immobilier_cubit.dart';
import 'package:immobilier/features/immobilier/home_immobilier/ui/components/fiche_bien_commun.dart';
import 'package:immobilier/features/ventes/cubit/dossier_vente_cubit.dart';
import 'package:immobilier/features/ventes/ui/components/suivi_vente.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/features/ventes/ui/creer_mandat.dart';
import 'package:immobilier/features/ventes/ui/formulaires_vente.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/apercu_bien.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/statut_jour.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// La fiche « Gestion du bien ».
///
/// Elle répond d'abord à la question de l'agent qui l'ouvre : ce bien,
/// aujourd'hui, où en est-il ? La photo et la carte d'identité disent de
/// quel bien il s'agit, la carte « Aujourd'hui » dit ce qui s'y passe et
/// ce qu'on peut y changer tout de suite, la grille range le reste.
///
/// Deux lectures l'alimentent : l'aperçu du jour
/// (`GET /api/dashboard/immobilier/bien/{id}/apercu`) et la fiche
/// complète déjà en place. La seconde suffit à afficher la page : si
/// l'aperçu manque, seuls les repères du jour s'effacent.
class ImmobilierHomePage extends StatefulWidget {
  final int propertyId;

  const ImmobilierHomePage({super.key, required this.propertyId});

  static Widget page(int id) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeImmobilierCubit(id)..fetchData()),
        BlocProvider(create: (_) => ApercuBienCubit(id)..charger()),
      ],
      child: ImmobilierHomePage(propertyId: id),
    );
  }

  @override
  State<ImmobilierHomePage> createState() => _ImmobilierHomePageState();
}

class _ImmobilierHomePageState extends State<ImmobilierHomePage> {
  /// Hauteur de la photo de tête, et débord de la carte d'identité.
  static const double _hauteurPhoto = 240;
  static const double _debordCarte = 56;

  int get _id => widget.propertyId;

  ApercuBienCubit get _apercuCubit => context.read<ApercuBienCubit>();

  /// Repli quand l'aperçu ne porte pas la liaison Airbnb.
  LienAirbnb? _airbnb;
  bool _airbnbCherche = false;

  // Location longue duree : le bail actif du bien, cherche une fois la
  // fiche chargee.
  Bail? _bailEnCours;
  bool _bailCherche = false;
  bool _rechercheBail = false;

  // Vente : le dossier de vente du bien (statut, mandat), cherche une fois.
  DossierVente? _dossierVente;
  bool _venteCherchee = false;

  bool _estLongueDuree(Realestate? r) => r?.typeTransaction?.value == 'rent-long';

  bool _estVente(Realestate? r) => r?.typeTransaction?.value == 'selle';

  /// Courte duree seulement : nuits, Airbnb et reservations.
  bool _estCourteDuree(Realestate? r) => !_estLongueDuree(r) && !_estVente(r);

  // ── Lectures d'appoint ──────────────────────────────────────────

  Future<void> _chargerAirbnb() async {
    _airbnbCherche = true;
    if (!peut(AppPermission.viewAirbnb)) return;
    try {
      final lien = await Dependencies.get<Repository>().fetchAirbnb(_id);
      if (mounted) setState(() => _airbnb = lien);
    } catch (_) {
      // Sans reponse, la tuile garde son sous-titre generique.
    }
  }

  Future<void> _chercherVente() async {
    _venteCherchee = true;
    try {
      final d = await Dependencies.get<Repository>().fetchDossierVente(_id);
      if (mounted) setState(() => _dossierVente = d);
    } catch (_) {
      // Sans reponse, la tuile garde son sous-titre generique.
    }
  }

  Future<void> _chercherBail() async {
    if (_rechercheBail) return;
    setState(() {
      _rechercheBail = true;
      _bailCherche = true;
    });
    Bail? trouve;
    try {
      final baux = await Dependencies.get<Repository>()
          .fetchBaux(statut: 'actif', bien: _id);
      trouve = baux.isEmpty ? null : baux.first;
    } catch (_) {
      // Sans reponse, on propose la creation : le serveur refusera un
      // bien deja loue.
    }
    if (!mounted) return;
    setState(() {
      _bailEnCours = trouve;
      _rechercheBail = false;
    });
  }

  /// Tirer-pour-rafraîchir : les deux lectures repartent ensemble.
  Future<void> _actualiser() async {
    context.read<HomeImmobilierCubit>().fetchData();
    final erreur = await _apercuCubit.rafraichir();
    if (!mounted) return;
    if (_estLongueDuree(_bien)) _chercherBail();
    if (_estVente(_bien)) _chercherVente();
    if (peut(AppPermission.viewAirbnb)) _chargerAirbnb();
    if (erreur != null && mounted) {
      afficherMessage(context, erreur, erreur: true);
    }
  }

  Realestate? get _bien =>
      context.read<HomeImmobilierCubit>().state.realestate;

  // ── L'écran ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeImmobilierCubit, HomeImmobilierState>(
      builder: (context, fiche) {
        final bien = fiche.realestate;

        // Les lectures d'appoint attendent de savoir a quelle famille le
        // bien appartient : un bail n'a de sens qu'en longue duree.
        if (bien != null) {
          if (!_airbnbCherche && _estCourteDuree(bien)) {
            _airbnbCherche = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _chargerAirbnb();
            });
          }
          if (!_bailCherche && _estLongueDuree(bien) && peutVoirBaux) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _chercherBail();
            });
          }
          if (!_venteCherchee && _estVente(bien) && peutVoirVentes) {
            _venteCherchee = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _chercherVente();
            });
          }
        }

        return Scaffold(
          backgroundColor: fondAccueil,
          body: BlocBuilder<ApercuBienCubit, ApercuBienState>(
            builder: (context, apercu) => RefreshIndicator(
              onRefresh: _actualiser,
              edgeOffset: MediaQuery.of(context).padding.top + 8,
              color: AppColors.primaryColor,
              child: _corps(fiche, apercu),
            ),
          ),
        );
      },
    );
  }

  Widget _corps(HomeImmobilierState fiche, ApercuBienState etat) {
    final bien = fiche.realestate;

    if (bien == null && fiche.fetchStatus == AppStatus.error) {
      return _echecComplet(fiche.error);
    }
    if (bien == null) {
      return const SqueletteFicheBien(hauteurPhoto: _hauteurPhoto);
    }

    final apercu = etat.apercu;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        _entete(bien, apercu),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bien.estDesactive && bien.desactiveLe != null) ...[
                BandeauBienDesactive(
                  desactiveLe: bien.desactiveLe!,
                  margin: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(rayonAccueil),
                ),
                const SizedBox(height: 14),
              ],
              _carteDuJour(bien, etat),
              const SizedBox(height: 14),
              ..._grilleTuiles(bien, apercu),
              const SizedBox(height: 18),
              _actionPrincipale(bien),
              if (peutChangerActivationBien(bien.estDesactive)) ...[
                const SizedBox(height: 24),
                BoutonDesactivationBien(
                  desactive: bien.estDesactive,
                  onDesactiver: () => _desactiver(bien),
                  onReactiver: () => _reactiver(bien),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// La fiche n'a jamais pu être lue : la page se réduit à un message et
  /// à un bouton — et au retour, qui doit toujours rester possible.
  Widget _echecComplet(String? message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              BoutonRondAccueil(
                icone: Icons.arrow_back,
                libelle: 'Retour',
                onTap: _retour,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CarteErreurResume(
            message: (message ?? '').isEmpty
                ? "Ce bien n'a pas pu être chargé."
                : message,
            onReessayer: () =>
                context.read<HomeImmobilierCubit>().fetchData(),
          ),
        ),
      ],
    );
  }

  // ── Photo et carte d'identité ───────────────────────────────────

  List<Media> _photos(Realestate r) => (r.media ?? const <Media>[])
      .where((m) => (m.url ?? '').trim().isNotEmpty)
      .toList();

  Widget _entete(Realestate r, ApercuBien? apercu) {
    final photos = _photos(r);
    final url = (apercu?.photo ?? '').isNotEmpty
        ? apercu!.photo
        : (photos.isEmpty ? null : photos.first.url);
    final nombre = apercu?.nbPhotos != null && apercu!.nbPhotos > 0
        ? apercu.nbPhotos
        : photos.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _debordCarte),
          child: PhotoDeTete(
            url: url,
            nbPhotos: nombre,
            hauteur: _hauteurPhoto,
            onRetour: _retour,
            onOuvrirGalerie: photos.isEmpty ? null : () => _ouvrirGalerie(r),
            onPartager: peut(AppPermission.shareProperty)
                ? () => PartageBien.partager(context, r)
                : null,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: _carteIdentite(r, apercu),
        ),
      ],
    );
  }

  Widget _carteIdentite(Realestate r, ApercuBien? apercu) {
    final reference = (apercu?.reference ?? '').isNotEmpty
        ? apercu!.reference
        : '$_id';

    final etage = (apercu?.etage ?? '').isNotEmpty
        ? apercu!.etage!
        : (r.etage != null ? '${r.etage}e étage' : null);

    final surTitre = [
      'Réf. $reference',
      if ((etage ?? '').isNotEmpty) etage!,
    ].join(' · ');

    final ville = (apercu?.ville ?? '').isNotEmpty
        ? apercu!.ville!
        : (r.address?.city?.name ?? '');

    final prix = apercu?.prixNuit ?? r.price?.toDouble();
    final unite = _estVente(r)
        ? ''
        : (_estLongueDuree(r) ? ' / mois' : ' / nuit');
    final ligne = [
      if (ville.trim().isNotEmpty) ville.trim(),
      if (prix != null && prix > 0) '${montantAccueil(prix)}$unite',
    ].join(' · ');

    return CarteAccueil(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SurTitre(surTitre),
          const SizedBox(height: 6),
          Text(
            (apercu?.titre ?? '').isNotEmpty
                ? apercu!.titre
                : (r.title ?? 'Bien'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: texteAccueil),
          ),
          if (ligne.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              ligne,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: texteDouxAccueil,
                fontFeatures: chiffresTabulaires,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Aujourd'hui ─────────────────────────────────────────────────

  Widget _carteDuJour(Realestate r, ApercuBienState etat) {
    if (etat.echecTotal) {
      return CarteErreurResume(
        message: etat.erreur,
        onReessayer: () => _apercuCubit.charger(),
      );
    }

    final apercu = etat.apercu;
    final statut = apercu?.etat ?? r.statutJour;
    final sejour = apercu?.sejour;
    final enLecture = etat.chargement && apercu == null;

    final boutons = _boutonsSejour(r);

    return CarteAccueil(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SurTitre("Aujourd'hui"),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: enLecture
                      ? const BlocSquelette(
                          hauteur: 22, largeur: 84, rayon: 11)
                      : (statut == null
                          ? const SizedBox.shrink()
                          : PastillePaiement(
                              libelle: statut.libelle,
                              teinte: StatutBienChip.couleurDe(statut),
                            )),
                ),
              ),
            ],
          ),
          if (enLecture) ...[
            const SizedBox(height: 12),
            const BlocSquelette(hauteur: 12, largeur: 200),
          ] else ...[
            const SizedBox(height: 9),
            Text(
              _ligneDuJour(sejour, statut),
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 13, height: 1.35, color: texteDouxAccueil),
            ),
          ],
          if (boutons.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < boutons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: boutons[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Ce qui se passe dans le bien aujourd'hui, en une ligne.
  String _ligneDuJour(SejourEnCours? sejour, StatutJour? statut) {
    if (sejour != null) {
      final qui = sejour.airbnb
          ? 'Séjour Airbnb'
          : (sejour.client.trim().isEmpty ? 'Client' : sejour.client.trim());
      final quand = [
        if ((sejour.departLe ?? '').isNotEmpty) 'départ le ${sejour.departLe}',
        if ((sejour.heure ?? '').isNotEmpty) 'à ${sejour.heure}',
      ].join(' ');
      return quand.isEmpty ? qui : '$qui · $quand';
    }
    if ((statut?.detail ?? '').isNotEmpty) return statut!.detail!;
    if (statut?.code == StatutJour.disponible) {
      return 'Aucun séjour en cours : le bien est libre.';
    }
    return 'Aucun séjour en cours.';
  }

  /// Prolonger et réduire : ils ne valent que pour une réservation en
  /// cours, et seulement chez nous — un séjour Airbnb se change sur Airbnb.
  List<Widget> _boutonsSejour(Realestate r) {
    final reservation = r.booking;
    if (!_estCourteDuree(r)) return const [];
    if (reservation?.id == null || reservation?.checkout == null) {
      return const [];
    }

    return [
      if (peut(AppPermission.extendReservation))
        SizedBox(
          height: 42,
          child: ElevatedButton(
            onPressed: () => _prolonger(r),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Prolonger',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      if (peut(AppPermission.reduceReservation))
        SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: () => _reduire(r),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.primaryColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Réduire',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
    ];
  }

  // ── La grille des tuiles ────────────────────────────────────────

  List<Widget> _grilleTuiles(Realestate r, ApercuBien? apercu) {
    final tuiles = <Widget>[
      if (!_estVente(r) && peut(AppPermission.viewCalendar))
        TuileBien(
          icone: Icons.calendar_month_outlined,
          titre: 'Calendrier',
          sousTitre: _sousTitreCalendrier(r, apercu),
          teinte: violetCharte,
          onTap: () => _onCalendrier(r.title),
        ),
      if (_estVente(r) && peutVoirVentes)
        TuileBien(
          icone: Icons.assignment_outlined,
          titre: 'Dossier de vente',
          sousTitre: _sousTitreVente,
          teinte: CouleursVente.teinte,
          onTap: _ouvrirDossierVente,
        ),
      TuileBien(
        icone: Icons.info_outline,
        titre: 'Détails du bien',
        sousTitre: 'Photos, équipements',
        teinte: bleuCharte,
        onTap: _onViewDetails,
      ),
      if (_estCourteDuree(r) && peut(AppPermission.viewAirbnb))
        TuileBien(
          pictogramme: const FaIcon(FontAwesomeIcons.airbnb,
              size: 18, color: CouleursAirbnb.rose),
          titre: 'Airbnb',
          sousTitre: _sousTitreAirbnb(apercu),
          teinte: CouleursAirbnb.rose,
          pastille: _relieAirbnb(apercu) ? rougeAccueil : null,
          onTap: () => _onAirbnb(r.title),
        ),
      if (peut(AppPermission.updateProperty))
        TuileBien(
          icone: Icons.edit_outlined,
          titre: 'Modifier',
          sousTitre: 'Assistant en 5 étapes',
          teinte: orangeAccueil,
          onTap: _onEditProperty,
        ),
    ];

    if (tuiles.isEmpty) return const [];

    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 165 / 124,
        children: tuiles,
      ),
    ];
  }

  String _sousTitreCalendrier(Realestate r, ApercuBien? apercu) {
    if (_estLongueDuree(r)) return 'Baux et disponibilités';
    final n = apercu?.sejoursAVenir ?? 0;
    if (n <= 0) return 'Aucun séjour à venir';
    return '${pluriel(n, 'séjour')} à venir';
  }

  bool _relieAirbnb(ApercuBien? apercu) =>
      apercu?.airbnb?.relie ?? _airbnb?.relie ?? false;

  String _sousTitreAirbnb(ApercuBien? apercu) {
    final a = apercu?.airbnb;
    if (a != null) {
      if (!a.relie) return 'Non relié';
      if (a.enErreur) return 'Erreur de synchronisation';
      if (a.synchroniseLe != null) return 'Synchronisé ${ilYA(a.synchroniseLe!)}';
      return 'Relié';
    }
    final lien = _airbnb;
    if (lien == null) return 'Synchroniser le calendrier';
    if (!lien.relie) return 'Non relié';
    if (lien.enErreur) return 'Erreur de synchronisation';
    if (lien.derniereSyncA != null) {
      return 'Synchronisé ${ilYA(lien.derniereSyncA!)}';
    }
    return 'Relié';
  }

  String get _sousTitreVente {
    final d = _dossierVente;
    if (d == null) return 'Mandats et visites';
    final b = d.bien;
    final m = mandatCourant(d);
    final mandat =
        m == null ? 'aucun mandat' : (m.signe ? 'mandat signé' : 'mandat à signer');
    return '${b.libelleStatut} · $mandat';
  }

  // ── L'action principale, en bas de page ─────────────────────────

  Widget _actionPrincipale(Realestate r) {
    if (_estLongueDuree(r)) return _boutonContrat(r);
    if (_estVente(r)) return _blocVente(r);
    if (!peut(AppPermission.createReservation)) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _onAddReservation,
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Ajouter une réservation',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Un bien en vente se suit par son dossier : mandat et visites.
  Widget _blocVente(Realestate r) {
    final dossier = _dossierVente;
    if (dossier != null) {
      return CarteSuiviVente(
        dossier: dossier,
        onOuvrir: _ouvrirDossierVente,
        onCreerMandat: peutCreerMandat ? () => _creerMandat(r.title) : null,
        onAjouterVisite: peutCreerVisite ? _ajouterVisite : null,
      );
    }
    if (!peutCreerMandat) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _creerMandat(r.title),
        icon: const Icon(Icons.note_add_outlined, size: 22),
        label: const Text('Créer un mandat',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: CouleursVente.teinte,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Bien en location longue duree : un contrat remplace la reservation.
  Widget _boutonContrat(Realestate r) {
    final bail = _bailEnCours;
    final String texte;
    final IconData icone;
    VoidCallback? action;
    final enAttente = _rechercheBail || (!_bailCherche && peutVoirBaux);
    if (enAttente) {
      texte = 'Recherche du contrat…';
      icone = Icons.hourglass_empty;
    } else if (bail != null) {
      texte = 'Voir le contrat en cours';
      icone = Icons.description_outlined;
      action = () => _ouvrirBail(bail.id, bail: bail);
    } else if (peutCreerBail) {
      texte = 'Ajouter un contrat';
      icone = Icons.note_add_outlined;
      action = () => _onAjouterContrat(r);
    } else {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bail != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Loué à ${bail.locataire.nom.isEmpty ? 'un locataire' : bail.locataire.nom} · '
              '${periodeBail(bail.dateDebut, bail.dateFin)}',
              style: const TextStyle(
                  fontSize: 12.5,
                  color: texteDouxAccueil,
                  fontWeight: FontWeight.w600),
            ),
          ),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: action,
            icon: enAttente
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(icone, size: 22),
            label: Text(texte,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: CouleursBail.teinte,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  CouleursBail.teinte.withValues(alpha: .6),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Prolonger et réduire le séjour en cours ─────────────────────

  Future<void> _prolonger(Realestate r) async {
    final depuis = r.booking?.checkout;
    final reservation = r.booking?.id;
    if (depuis == null || reservation == null) return;
    final maxDate =
        r.nextCheckin ?? DateTime.now().add(const Duration(days: 365));

    DateTime? choisi;
    double? prix;
    await showDialog(
      context: context,
      builder: (_) => ProlongerReservationDialog(
        from: depuis,
        maxDate: maxDate,
        initialPrice: (r.booking?.nightPrice ?? r.price ?? 0).toDouble(),
        // Les valeurs sont recueillies ici, mais l'envoi attend la
        // fermeture de la fenetre : deux fenetres ne se chevauchent pas.
        onConfirm: (checkout, montant) {
          choisi = checkout;
          prix = montant;
        },
      ),
    );

    if (choisi == null || prix == null || !mounted) return;
    // Le total de la prolongation entre dans la caisse de l'agent : une
    // entree n'a rien a verifier, la caisse s'ouvre d'elle-meme.
    await _envoyer(
      (depot) => depot.extendBooking(choisi!, prix!, reservation),
      succes: 'Réservation prolongée.',
    );
  }

  Future<void> _reduire(Realestate r) async {
    final depart = r.booking?.checkout;
    final reservation = r.booking?.id;
    if (depart == null || reservation == null) return;

    DateTime? choisi;
    double remboursement = 0;
    await showDialog(
      context: context,
      builder: (_) => ShrinkReservationDialog(
        originalCheckout: depart,
        originalPrice: (r.price ?? 0).toDouble(),
        onConfirm: (nouveau, montant) {
          choisi = nouveau;
          remboursement = montant;
        },
      ),
    );

    if (choisi == null || !mounted) return;

    // Un remboursement sort des especes : la caisse doit etre ouverte et
    // les contenir, sans quoi le serveur refuse le mouvement en silence.
    if (remboursement > 0) {
      final prete = await garantirCaisseOuverte(
        context,
        motif: 'le remboursement de cette réservation',
        sortie: remboursement,
      );
      if (!prete || !mounted) return;
    }

    await _envoyer(
      (depot) => depot.shrinkBooking(choisi!, remboursement, reservation),
      succes: 'Réservation réduite.',
    );
  }

  /// Envoie une modification du séjour, puis relit la page.
  Future<void> _envoyer(
    Future<void> Function(Repository depot) action, {
    required String succes,
  }) async {
    try {
      await action(Dependencies.get<Repository>());
    } on OperationMiseEnFileException {
      // Declaration conservee sur le telephone, envoyee au retour du reseau.
    } catch (ex) {
      if (mounted) afficherMessage(context, messageErreur(ex), erreur: true);
      return;
    }
    if (!mounted) return;
    afficherMessage(context, succes);
    context.read<HomeImmobilierCubit>().fetchData();
    await _apercuCubit.rafraichir();
  }

  // ── Navigation ──────────────────────────────────────────────────

  void _retour() {
    final routeur = GoRouter.of(context);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    } else if (routeur.canPop()) {
      routeur.pop();
    }
  }

  void _ouvrirGalerie(Realestate r) {
    final photos = _photos(r);
    if (photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImagesGalery(medias: photos)),
    );
  }

  Future<void> _rafraichirTout() async {
    if (!mounted) return;
    context.read<HomeImmobilierCubit>().fetchData();
    await _apercuCubit.rafraichir();
  }

  Future<void> _onViewDetails() async {
    final modifie = await GoRouter.of(context)
        .push(Routes.immobilierDetails.replaceAll(':id', '$_id'));
    if (!mounted) return;
    // Bien desactive depuis la fiche : on remonte le signal a la liste.
    if (modifie == true) {
      if (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop(true);
        return;
      }
    }
    await _rafraichirTout();
  }

  Future<void> _desactiver(Realestate bien) async {
    final ok = await desactiverBienAvecDialogue(context, bien.id ?? _id);
    if (!ok || !mounted) return;
    // Signal de rafraichissement pour les listes appelantes.
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop(true);
    } else {
      await _rafraichirTout();
    }
  }

  Future<void> _reactiver(Realestate bien) async {
    final reactive = await reactiverBienAvecDialogue(context, bien.id ?? _id,
        titre: bien.title);
    if (reactive != null && mounted) await _rafraichirTout();
  }

  Future<void> _onCalendrier(String? titre) async {
    await GoRouter.of(context).push(Uri(
      path: Routes.calendrierBien.replaceAll(':id', '$_id'),
      queryParameters: (titre ?? '').isEmpty ? null : {'titre': titre},
    ).toString());
    if (mounted) await _apercuCubit.rafraichir();
  }

  Future<void> _onAirbnb(String? titre) async {
    await GoRouter.of(context).push(cheminAirbnbBien(_id, titre: titre));
    if (!mounted) return;
    await _chargerAirbnb();
    if (mounted) await _apercuCubit.rafraichir();
  }

  Future<void> _onAddReservation() async {
    await GoRouter.of(context)
        .push(Routes.addReservation.replaceAll(':id', '$_id'));
    if (mounted) await _rafraichirTout();
  }

  Future<void> _onEditProperty() async {
    await GoRouter.of(context)
        .push(Routes.updateImmobilier.replaceAll(':id', '$_id'));
    if (mounted) await _rafraichirTout();
  }

  Future<void> _ouvrirBail(int id, {Bail? bail, bool nouveau = false}) async {
    await GoRouter.of(context).push(cheminBail(id, nouveau: nouveau), extra: bail);
    // Prolonge, termine ou supprime depuis la fiche : le bouton suit.
    if (mounted) _chercherBail();
  }

  Future<void> _onAjouterContrat(Realestate r) async {
    final photos = _photos(r);
    final adresse = [r.address?.address, r.address?.city?.name]
        .where((x) => (x ?? '').trim().isNotEmpty)
        .join(', ');
    final bien = BienLongueDuree(
      id: _id,
      titre: r.title ?? 'Bien',
      adresse: adresse.isEmpty ? null : adresse,
      photo: photos.isEmpty ? null : photos.first.url,
      loyerPropose: r.price?.toDouble(),
    );
    final cree = await GoRouter.of(context).push<Bail>(Routes.bailForm, extra: bien);
    if (!mounted) return;
    if (cree != null) {
      setState(() => _bailEnCours = cree);
      await _ouvrirBail(cree.id, bail: cree, nouveau: true);
    }
  }

  Future<void> _ouvrirDossierVente({String? onglet}) async {
    await GoRouter.of(context)
        .push(cheminDossierVente(_id, onglet: onglet));
    if (mounted) _chercherVente();
  }

  /// Mandat pre-rempli depuis le bien et son proprietaire.
  Future<void> _creerMandat(String? titre) async {
    await ouvrirCreationMandat(context, _id, titreBien: titre);
    if (mounted) _chercherVente();
  }

  /// Recu de visite, sans passer par le dossier de vente.
  Future<void> _ajouterVisite() async {
    final d = _dossierVente;
    if (d == null) {
      await _ouvrirDossierVente(onglet: 'visites');
      return;
    }
    final cubit = DossierVenteCubit(_id);
    final ok = await ouvrirFormulaireVisite(context, d, cubit);
    await cubit.close();
    if (!mounted) return;
    if (ok) afficherMessage(context, 'Reçu de visite enregistré.');
    _chercherVente();
  }
}
