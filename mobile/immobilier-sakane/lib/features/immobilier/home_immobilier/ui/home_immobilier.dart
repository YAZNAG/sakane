import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_string.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/features/immobilier/home_immobilier/cubit/home_immobilier_cubit.dart';
import 'package:immobilier/features/ventes/cubit/dossier_vente_cubit.dart';
import 'package:immobilier/features/ventes/ui/components/suivi_vente.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/features/ventes/ui/creer_mandat.dart';
import 'package:immobilier/features/ventes/ui/formulaires_vente.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';



class ImmobilierHomePage extends StatefulWidget {
  final int propertyId;


  ImmobilierHomePage({
    required this.propertyId,
  });

  static Widget page(int id){
    return BlocProvider(
      create: (context)=>HomeImmobilierCubit(id)..fetchData(),
      child: ImmobilierHomePage(propertyId: id),
    );
  }

  @override
  State<ImmobilierHomePage> createState() => _ImmobilierHomePageState();
}

class _ImmobilierHomePageState extends State<ImmobilierHomePage> {
  Manager manager=Dependencies.get<Manager>();

  // Etat de la liaison Airbnb, pour le sous-titre de la carte ; null tant qu'inconnu.
  LienAirbnb? _airbnb;

  @override
  void initState() {
    super.initState();
    _chargerAirbnb();
  }

  Future<void> _chargerAirbnb() async {
    if (!Dependencies.get<Manager>().can(AppPermission.viewAirbnb)) return;
    try {
      final lien = await Dependencies.get<Repository>().fetchAirbnb(widget.propertyId);
      if (mounted) setState(() => _airbnb = lien);
    } catch (_) {
      // Sans reponse, la carte garde son sous-titre generique.
    }
  }

  String get _sousTitreAirbnb {
    final lien = _airbnb;
    if (lien == null) return 'Synchroniser le calendrier avec Airbnb';
    if (!lien.relie) return 'Non relié • synchroniser le calendrier avec Airbnb';
    if (lien.enErreur) return 'Relié • erreur de synchronisation';
    if (lien.derniereSyncA != null) return 'Relié • synchronisé ${ilYA(lien.derniereSyncA!)}';
    return 'Relié';
  }

  // Location longue duree : le bail actif du bien, cherche une fois la fiche chargee.
  Bail? _bailEnCours;
  bool _bailCherche = false;
  bool _rechercheBail = false;

  bool _estLongueDuree(Realestate? r) => r?.typeTransaction?.value == 'rent-long';

  bool _estVente(Realestate? r) => r?.typeTransaction?.value == 'selle';

  /// Courte duree seulement : calendrier des nuits, Airbnb et reservations.
  bool _estCourteDuree(Realestate? r) => !_estLongueDuree(r) && !_estVente(r);

  // Vente : le dossier de vente du bien (statut, mandat), cherche une fois.
  DossierVente? _dossierVente;
  bool _venteCherchee = false;

  Future<void> _chercherVente() async {
    _venteCherchee = true;
    try {
      final d = await Dependencies.get<Repository>().fetchDossierVente(widget.propertyId);
      if (mounted) setState(() => _dossierVente = d);
    } catch (_) {
      // Sans reponse, la carte garde son sous-titre generique.
    }
  }

  String get _sousTitreVente {
    final d = _dossierVente;
    if (d == null) return 'Mandats de vente et visites';
    final b = d.bien;
    final m = mandatCourant(d);
    final mandat = m == null ? 'aucun mandat' : (m.signe ? 'mandat signé' : 'mandat à signer');
    return '${b.libelleStatut} • $mandat • ${b.nbVisites} visite${b.nbVisites > 1 ? 's' : ''}';
  }

  Future<void> _ouvrirDossierVente({String? onglet}) async {
    await GoRouter.of(context).push(cheminDossierVente(widget.propertyId, onglet: onglet));
    if (mounted) _chercherVente();
  }

  /// Mandat pre-rempli depuis le bien et son proprietaire.
  Future<void> _creerMandat(String? titre) async {
    await ouvrirCreationMandat(context, widget.propertyId, titreBien: titre);
    if (mounted) _chercherVente();
  }

  /// Recu de visite, sans passer par le dossier de vente.
  Future<void> _ajouterVisite() async {
    final d = _dossierVente;
    if (d == null) {
      await _ouvrirDossierVente(onglet: 'visites');
      return;
    }
    final cubit = DossierVenteCubit(widget.propertyId);
    final ok = await ouvrirFormulaireVisite(context, d, cubit);
    await cubit.close();
    if (!mounted) return;
    if (ok) afficherMessage(context, 'Reçu de visite enregistré.');
    _chercherVente();
  }

  Future<void> _chercherBail() async {
    if (_rechercheBail) return;
    setState(() {
      _rechercheBail = true;
      _bailCherche = true;
    });
    Bail? trouve;
    try {
      final baux = await Dependencies.get<Repository>().fetchBaux(statut: 'actif', bien: widget.propertyId);
      trouve = baux.isEmpty ? null : baux.first;
    } catch (_) {
      // Sans reponse, on propose la creation : le serveur refusera un bien deja loue.
    }
    if (!mounted) return;
    setState(() {
      _bailEnCours = trouve;
      _rechercheBail = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeImmobilierCubit, HomeImmobilierState>(
      builder: (context, state) {
        // Le partage a besoin de la fiche chargee : le bloc enveloppe
        // donc le Scaffold, pour que la barre de titre y ait acces.
        final bien = state.realestate;
        if (bien != null && !_bailCherche && _estLongueDuree(bien) && peutVoirBaux) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _chercherBail();
          });
        }
        if (bien != null && !_venteCherchee && _estVente(bien) && peutVoirVentes) {
          _venteCherchee = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _chercherVente();
          });
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              "Gestion du Bien",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            actions: [
              if (bien != null && manager.can(AppPermission.shareProperty))
                IconButton(
                  onPressed: () => PartageBien.partager(context, bien),
                  icon: Icon(Icons.share, color: Colors.white),
                  tooltip: "Partager la fiche",
                ),
            ],
          ),
          body: _buildContent(state),
        );
      },
    );
  }

  /// La fiche du bien : photo, nom, adresse, statut et l'essentiel.
  Widget _buildFicheBien(Realestate r) {
    final img = (r.media?.isNotEmpty ?? false) ? r.media!.first.url : null;
    final statut = r.status?.color?.toColor ?? AppColors.primaryColor;
    final adresse = [r.address?.address, r.address?.city?.name]
        .where((x) => (x ?? '').trim().isNotEmpty)
        .join(', ');

    final infos = <Widget>[
      if (r.price != null)
        _info(Icons.payments_outlined,
            '${r.price} MAD${_estVente(r) ? '' : ' / ${_estLongueDuree(r) ? 'mois' : 'nuit'}'}'),
      if ((r.nbRooms ?? 0) > 0)
        _info(Icons.bed_outlined, '${r.nbRooms} chambre${r.nbRooms! > 1 ? 's' : ''}'),
      if ((r.nbBathroom ?? 0) > 0)
        _info(Icons.bathtub_outlined,
            '${r.nbBathroom} salle${r.nbBathroom! > 1 ? 's' : ''} de bain'),
      if ((r.surface ?? 0) > 0) _info(Icons.square_foot, '${r.surface} m²'),
      if (r.etage != null) _info(Icons.stairs_outlined, 'Étage ${r.etage}'),
      if ((r.owner?.name ?? '').isNotEmpty) _info(Icons.person_outline, r.owner!.name!),
      _info(Icons.tag, 'Réf. ${widget.propertyId}'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x1417262E), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 210,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img != null
                      ? Image.network(img,
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageVide())
                      : _imageVide(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                        stops: [0, .45, 1],
                      ),
                    ),
                  ),
                  if (r.status?.name != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: statut, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(r.status!.name!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF17262E))),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title ?? 'Bien',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (adresse.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 15, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(adresse,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: infos),
                  if ((r.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      r.description!.trim(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: Color(0xFF4A5B64)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageVide() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryColor, AppColors.primaryColor.withValues(alpha: .7)],
          ),
        ),
        child: const Icon(Icons.home_work_outlined, size: 56, color: Colors.white70),
      );

  Widget _info(IconData icone, String texte) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 16, color: const Color(0xFF4A5B64)),
            const SizedBox(width: 6),
            Text(texte,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF17262E))),
          ],
        ),
      );

  Widget _actionBien({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8EC)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, color: couleur, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                    const SizedBox(height: 2),
                    Text(sousTitre,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B84))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF98A6AE)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(HomeImmobilierState state) {
    if (state.fetchStatus == AppStatus.error) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Error",
          action: AppStrings.tryAgain,
          actionCLick: () => BlocProvider.of<HomeImmobilierCubit>(context).fetchData(),
        ),
      );
    } else if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.success) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.realestate!.estDesactive)
              BandeauBienDesactive(
                desactiveLe: state.realestate!.desactiveLe!,
                margin: const EdgeInsets.only(bottom: 14),
                borderRadius: BorderRadius.circular(14),
              ),
            _buildFicheBien(state.realestate!),
            const SizedBox(height: 18),
            if (_estVente(state.realestate) && peutVoirVentes) ...[
              _actionBien(
                icone: Icons.assignment_outlined,
                titre: 'Dossier de vente',
                sousTitre: _sousTitreVente,
                couleur: CouleursVente.teinte,
                onTap: _ouvrirDossierVente,
              ),
              const SizedBox(height: 10),
            ],
            // La vente n'a ni nuits ni reservations ; la longue duree garde
            // le calendrier (ses baux y figurent) mais pas Airbnb.
            if (!_estVente(state.realestate) && manager.can(AppPermission.viewCalendar)) ...[
              _actionBien(
                icone: Icons.calendar_month_outlined,
                titre: 'Calendrier',
                sousTitre: _estLongueDuree(state.realestate)
                    ? 'Baux et disponibilités'
                    : 'Réservations, prix des nuits et dates bloquées',
                couleur: const Color(0xFF7B4FD6),
                onTap: () => _onCalendrier(state.realestate?.title),
              ),
              const SizedBox(height: 10),
            ],
            if (_estCourteDuree(state.realestate) && manager.can(AppPermission.viewAirbnb)) ...[
              _actionBien(
                icone: FontAwesomeIcons.airbnb,
                titre: 'Airbnb',
                sousTitre: _sousTitreAirbnb,
                couleur: CouleursAirbnb.rose,
                onTap: () => _onAirbnb(state.realestate?.title),
              ),
              const SizedBox(height: 10),
            ],
            _actionBien(
              icone: Icons.info_outline,
              titre: 'Détails du bien',
              sousTitre: 'Photos, équipements, localisation',
              couleur: const Color(0xFF2C6FB5),
              onTap: _onViewDetails,
            ),
            if (manager.can(AppPermission.updateProperty)) ...[
              const SizedBox(height: 10),
              _actionBien(
                icone: Icons.edit_outlined,
                titre: 'Modifier le bien',
                sousTitre: 'Informations, prix, photos',
                couleur: const Color(0xFFD97E1A),
                onTap: _onEditProperty,
              ),
            ],
            if (_estLongueDuree(state.realestate)) ...[
              const SizedBox(height: 18),
              _boutonContrat(state.realestate!),
            ] else if (_estVente(state.realestate)) ...[
              // Un bien en vente se suit par son dossier : mandat et visites.
              const SizedBox(height: 18),
              if (_dossierVente != null)
                CarteSuiviVente(
                  dossier: _dossierVente!,
                  onOuvrir: () => _ouvrirDossierVente(),
                  onCreerMandat: peutCreerMandat ? () => _creerMandat(state.realestate?.title) : null,
                  onAjouterVisite: peutCreerVisite ? _ajouterVisite : null,
                )
              else if (peutCreerMandat)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _creerMandat(state.realestate?.title),
                    icon: const Icon(Icons.note_add_outlined, size: 22),
                    label: const Text('Créer un mandat',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CouleursVente.teinte,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ] else if (manager.can(AppPermission.createReservation)) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _onAddReservation,
                  icon: const Icon(Icons.event_available, size: 22),
                  label: const Text('Ajouter une réservation',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
            // Desactivation : action explicite en bas de la page du bien.
            if (peutChangerActivationBien(state.realestate!.estDesactive)) ...[
              const SizedBox(height: 26),
              BoutonDesactivationBien(
                desactive: state.realestate!.estDesactive,
                onDesactiver: () => _desactiver(state.realestate!),
                onReactiver: () => _reactiver(state.realestate!),
              ),
            ],
          ],
        ),
      );
    }
    return const SizedBox();
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
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bail != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Loué à ${bail.locataire.nom.isEmpty ? 'un locataire' : bail.locataire.nom} • '
              '${periodeBail(bail.dateDebut, bail.dateFin)}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7B84), fontWeight: FontWeight.w600),
            ),
          ),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: action,
            icon: enAttente
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(icone, size: 22),
            label: Text(texte, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: CouleursBail.teinte,
              foregroundColor: Colors.white,
              disabledBackgroundColor: CouleursBail.teinte.withValues(alpha: .6),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ouvrirBail(int id, {Bail? bail, bool nouveau = false}) async {
    await GoRouter.of(context).push(cheminBail(id, nouveau: nouveau), extra: bail);
    // Prolonge, termine ou supprime depuis la fiche : le bouton suit.
    if (mounted) _chercherBail();
  }

  Future<void> _onAjouterContrat(Realestate r) async {
    final photo = (r.media?.isNotEmpty ?? false) ? r.media!.first.url : null;
    final adresse = [r.address?.address, r.address?.city?.name]
        .where((x) => (x ?? '').trim().isNotEmpty)
        .join(', ');
    final bien = BienLongueDuree(
      id: widget.propertyId,
      titre: r.title ?? 'Bien',
      adresse: adresse.isEmpty ? null : adresse,
      photo: photo,
      loyerPropose: r.price?.toDouble(),
    );
    final cree = await GoRouter.of(context).push<Bail>(Routes.bailForm, extra: bien);
    if (!mounted) return;
    if (cree != null) {
      setState(() => _bailEnCours = cree);
      await _ouvrirBail(cree.id, bail: cree, nouveau: true);
    }
  }

  // Navigation methods
  void _onViewDetails() async {
    final modifie = await GoRouter.of(context).push(Routes.immobilierDetails.replaceAll(":id", widget.propertyId.toString()));
    if (!mounted) return;
    // Bien desactive depuis la fiche : on remonte le signal a la liste
    if (modifie == true) {
      if (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop(true);
      } else {
        fetchData();
      }
    } else if (BlocProvider.of<HomeImmobilierCubit>(context).state.realestate?.estDesactive ?? false) {
      // Peut avoir ete reactive depuis la fiche : le bandeau suit.
      fetchData();
    }
  }

  Future<void> _desactiver(Realestate bien) async {
    final ok = await desactiverBienAvecDialogue(context, bien.id ?? widget.propertyId);
    if (!ok || !mounted) return;
    // Signal de rafraichissement pour les listes appelantes
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop(true);
    } else {
      fetchData();
    }
  }

  Future<void> _reactiver(Realestate bien) async {
    final reactive = await reactiverBienAvecDialogue(context, bien.id ?? widget.propertyId, titre: bien.title);
    if (reactive != null && mounted) fetchData();
  }

  void _onCalendrier(String? titre) {
    GoRouter.of(context).push(Uri(
      path: Routes.calendrierBien.replaceAll(":id", widget.propertyId.toString()),
      queryParameters: (titre ?? '').isEmpty ? null : {'titre': titre},
    ).toString());
  }

  Future<void> _onAirbnb(String? titre) async {
    await GoRouter.of(context).push(cheminAirbnbBien(widget.propertyId, titre: titre));
    if (mounted) _chargerAirbnb();
  }

  void _onAddReservation() {
    GoRouter.of(context).push(Routes.addReservation.replaceAll(":id", widget.propertyId.toString()));
  }

  void _onEditProperty() {
    GoRouter.of(context).push(Routes.updateImmobilier.replaceAll(":id", widget.propertyId.toString()));
  }

  void Function()? fetchData() {
    BlocProvider.of<HomeImmobilierCubit>(context).fetchData();
  }


}