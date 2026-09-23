import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/components/statut_bien_chip.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart'
    show BoutonsContact;
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/cubit/immobilier_detail_cubit.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/detail_bien_commun.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/features/immobilier/home_immobilier/ui/components/fiche_bien_commun.dart'
    show SurTitre;
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:url_launcher/url_launcher.dart';

/// La fiche « Détails du bien ».
///
/// Elle répond à la question de celui qui la lit : de quel bien s'agit-il,
/// à quoi ressemble-t-il, où est-il, et à qui appartient-il ? Les photos
/// d'abord, puis l'identité (référence, prix, titre, ville), puis les
/// chiffres, la description, les équipements, la carte et le propriétaire.
///
/// La gestion du bien — calendrier, réservations, ménage — vit ailleurs :
/// ici le menu ⋮ n'ouvre que le calendrier, le partage et la
/// désactivation.
class ImmobilierDetailPage extends StatefulWidget {
  final int id;

  const ImmobilierDetailPage({super.key, required this.id});

  static Widget page(int id) {
    return BlocProvider<ImmobilierDetailCubit>(
      create: (context) => ImmobilierDetailCubit(id)..fetchData(),
      child: ImmobilierDetailPage(id: id),
    );
  }

  @override
  State<ImmobilierDetailPage> createState() => _ImmobilierDetailPageState();
}

class _ImmobilierDetailPageState extends State<ImmobilierDetailPage> {
  static const double _hauteurPhoto = 250;

  /// La description et la liste d'équipements s'ouvrent à la demande :
  /// la fiche reste courte tant qu'on ne lui demande pas le détail.
  bool _descriptionOuverte = false;
  bool _equipementsOuverts = false;

  /// Au-delà, les équipements sont repliés derrière une puce « + n ».
  static const int _equipementsVisibles = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondAccueil,
      body: BlocBuilder<ImmobilierDetailCubit, ImmobilierDetailState>(
        builder: (context, state) => _corps(state),
      ),
    );
  }

  // ── L'état de la lecture ────────────────────────────────────────

  Widget _corps(ImmobilierDetailState state) {
    final bien = state.realestate;

    if (bien == null && state.fetchStatus == AppStatus.error) {
      return _echec(state.error);
    }
    if (bien == null) {
      return const SqueletteDetailBien(hauteurPhoto: _hauteurPhoto);
    }
    return _fiche(bien);
  }

  /// La fiche n'a jamais pu être lue : un message discret, un bouton, et
  /// le retour — qui doit toujours rester possible.
  Widget _echec(String? message) {
    return ListView(
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
            onReessayer: _relire,
          ),
        ),
      ],
    );
  }

  Widget _fiche(Realestate bien) {
    final sections = <Widget>[
      _carteIdentite(bien),
      if (bien.estDesactive && bien.desactiveLe != null)
        BandeauBienDesactive(
          desactiveLe: bien.desactiveLe!,
          margin: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(rayonAccueil),
        ),
      ..._description(bien),
      ..._equipements(bien),
      ..._localisation(bien),
      ..._proprietaire(bien),
      ..._visite360(bien),
    ];

    final chiffres = _chiffres(bien);

    return RefreshIndicator(
      onRefresh: _actualiser,
      edgeOffset: MediaQuery.of(context).padding.top + 8,
      color: AppColors.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          _carrousel(bien),
          const SizedBox(height: 14),
          if (chiffres.isNotEmpty) ...[
            RangeeChiffres(cartes: chiffres),
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  sections[i],
                ],
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
      ),
    );
  }

  // ── Photos ──────────────────────────────────────────────────────

  List<Media> _photos(Realestate bien) => (bien.media ?? const <Media>[])
      .where((m) => (m.pleineTaille ?? '').isNotEmpty)
      .toList();

  Widget _carrousel(Realestate bien) {
    final photos = _photos(bien);
    return CarrouselPhotos(
      photos: photos,
      hauteur: _hauteurPhoto,
      onRetour: _retour,
      onPartager: peut(AppPermission.shareProperty)
          ? () => _partager(bien)
          : null,
      menu: _menu(bien),
      onOuvrirGalerie: photos.isEmpty
          ? null
          : (index) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImagesGalery(medias: photos, index: index),
              ),
            ),
    );
  }

  /// Le menu ⋮ : calendrier, partage, désactivation. Null quand aucune de
  /// ces actions n'est ouverte à l'utilisateur.
  Widget? _menu(Realestate bien) {
    final calendrier = peut(AppPermission.viewCalendar);
    final partage = peut(AppPermission.shareProperty);
    final activation = peutChangerActivationBien(bien.estDesactive);
    if (!calendrier && !partage && !activation) return null;

    return PopupMenuButton<String>(
      tooltip: 'Autres actions',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (choix) {
        switch (choix) {
          case 'calendrier':
            _ouvrirCalendrier(bien);
          case 'partager':
            _partager(bien);
          case 'desactiver':
            _desactiver(bien);
          case 'reactiver':
            _reactiver(bien);
        }
      },
      itemBuilder: (_) => [
        if (calendrier)
          const PopupMenuItem(
            value: 'calendrier',
            child: _LigneMenu(
              icone: Icons.calendar_month_outlined,
              libelle: 'Calendrier',
            ),
          ),
        if (partage)
          const PopupMenuItem(
            value: 'partager',
            child: _LigneMenu(
              icone: Icons.share_outlined,
              libelle: 'Partager la fiche',
            ),
          ),
        if (activation)
          PopupMenuItem(
            value: bien.estDesactive ? 'reactiver' : 'desactiver',
            child: _LigneMenu(
              icone: bien.estDesactive
                  ? Icons.restore
                  : Icons.visibility_off_outlined,
              libelle: bien.estDesactive
                  ? 'Réactiver le bien'
                  : 'Désactiver le bien',
              teinte: bien.estDesactive ? vertAccueil : couleurDesactivation,
            ),
          ),
      ],
      // Le bouton rond blanc lui-meme sert de cible : la pastille de 40 px
      // se touche, l'icone seule non.
      child: const CercleFlottant(
        enfant: Icon(Icons.more_vert, size: 19, color: texteAccueil),
      ),
    );
  }

  // ── Identité ────────────────────────────────────────────────────

  bool _estLongueDuree(Realestate b) => b.typeTransaction?.value == 'rent-long';

  bool _estVente(Realestate b) => b.typeTransaction?.value == 'selle';

  Widget _carteIdentite(Realestate bien) {
    final reference = bien.referenceLisible;
    final prix = bien.price?.toDouble();
    final unite = _estVente(bien)
        ? null
        : (_estLongueDuree(bien) ? '/ mois' : '/ nuit');

    final ville = bien.address?.city?.name?.trim() ?? '';
    final etage = _libelleEtage(bien.etage);
    final ligne = [
      if (ville.isNotEmpty) ville,
      if (etage != null) etage,
    ].join(' · ');

    final statut = bien.statutJour;

    return CarteAccueil(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: SurTitre(
                    reference.isEmpty ? 'Bien' : 'Réf. $reference',
                  ),
                ),
              ),
              if (prix != null && prix > 0) ...[
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      montantAccueil(prix),
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: texteAccueil,
                        fontFeatures: chiffresTabulaires,
                      ),
                    ),
                    if (unite != null)
                      Text(
                        unite,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: texteDouxAccueil,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (bien.title ?? '').trim().isEmpty ? 'Bien' : bien.title!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: texteAccueil,
            ),
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
          if (statut != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: StatutBienChip(statut: statut, compact: true),
            ),
          ],
        ],
      ),
    );
  }

  /// « 3e étage », « Rez-de-chaussée », ou rien quand l'étage manque.
  String? _libelleEtage(int? etage) {
    if (etage == null) return null;
    if (etage == 0) return 'Rez-de-chaussée';
    return '${etage}e étage';
  }

  // ── Chiffres ────────────────────────────────────────────────────

  /// Seuls les chiffres renseignés ont leur carte : une carte « N/A » ne
  /// dit rien de plus qu'une carte absente.
  List<CarteChiffre> _chiffres(Realestate bien) {
    final cartes = <CarteChiffre>[];

    final surface = bien.surface;
    if (surface != null && surface > 0) {
      cartes.add(
        CarteChiffre(
          valeur: _nombre(surface),
          libelle: 'm²',
          icone: Icons.square_foot,
        ),
      );
    }

    final chambres = bien.nbRooms ?? 0;
    if (chambres > 0) {
      cartes.add(
        CarteChiffre(
          valeur: '$chambres',
          libelle: chambres > 1 ? 'chambres' : 'chambre',
          icone: Icons.bed_outlined,
        ),
      );
    }

    final sdb = bien.nbBathroom ?? 0;
    if (sdb > 0) {
      cartes.add(
        CarteChiffre(
          valeur: '$sdb',
          libelle: sdb > 1 ? 'salles de bain' : 'salle de bain',
          icone: Icons.bathtub_outlined,
        ),
      );
    }

    final construction = bien.dateConstruction;
    if (construction != null) {
      cartes.add(
        CarteChiffre(
          valeur: '${construction.year}',
          libelle: 'année',
          icone: Icons.calendar_today_outlined,
        ),
      );
    }

    return cartes;
  }

  /// « 86 », « 86,5 » : le zéro décimal ne s'écrit pas.
  String _nombre(num valeur) {
    if (valeur == valeur.roundToDouble()) return valeur.round().toString();
    return valeur.toString().replaceAll('.', ',');
  }

  // ── Description ─────────────────────────────────────────────────

  List<Widget> _description(Realestate bien) {
    final texte = bien.description?.trim() ?? '';
    if (texte.isEmpty) return const [];

    return [
      CarteAccueil(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const TitreSectionDetail('Description'),
            const SizedBox(height: 8),
            Text(
              texte,
              maxLines: _descriptionOuverte ? null : 3,
              overflow: _descriptionOuverte ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: texteDouxAccueil,
              ),
            ),
            // Le lien n'est proposé que si le texte dépasse : sur trois
            // lignes, « Lire la suite » n'ouvrirait rien.
            if (_descriptionOuverte || _depasse(texte))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(
                    () => _descriptionOuverte = !_descriptionOuverte,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _descriptionOuverte ? 'Réduire' : 'Lire la suite',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  /// Approximation de « ce texte tient-il en trois lignes ? » : trois
  /// lignes d'un téléphone étroit portent environ 120 caractères.
  bool _depasse(String texte) =>
      texte.length > 120 || texte.split('\n').length > 3;

  // ── Équipements ─────────────────────────────────────────────────

  List<Widget> _equipements(Realestate bien) {
    final noms = (bien.features ?? [])
        .map((f) => f.name?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (noms.isEmpty) return const [];

    final replie = !_equipementsOuverts && noms.length > _equipementsVisibles;
    final montres = replie ? noms.take(_equipementsVisibles).toList() : noms;
    final restants = noms.length - montres.length;

    return [
      CarteAccueil(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const TitreSectionDetail('Équipements'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final nom in montres) PuceEquipement(nom),
                if (restants > 0)
                  PuceEquipement(
                    '+ $restants',
                    accentuee: true,
                    onTap: () => setState(() => _equipementsOuverts = true),
                  )
                else if (_equipementsOuverts &&
                    noms.length > _equipementsVisibles)
                  PuceEquipement(
                    'Réduire',
                    accentuee: true,
                    onTap: () => setState(() => _equipementsOuverts = false),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ── Localisation ────────────────────────────────────────────────

  List<Widget> _localisation(Realestate bien) {
    final rue = bien.address?.address?.trim() ?? '';
    final ville = bien.address?.city?.name?.trim() ?? '';
    final secteur = bien.secteur?.name?.trim() ?? '';
    final lien = PartageBien.carte(bien);

    // Ni adresse ni position : la section n'aurait rien à montrer.
    if (rue.isEmpty && ville.isEmpty && secteur.isEmpty && lien.isEmpty) {
      return const [];
    }

    final sousLigne = [
      if (ville.isNotEmpty) ville,
      if (secteur.isNotEmpty) secteur,
    ].join(' · ');

    return [
      CarteAccueil(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const TitreSectionDetail('Localisation'),
            if (rue.isNotEmpty || sousLigne.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (rue.isNotEmpty)
                Text(
                  rue,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: texteAccueil,
                  ),
                ),
              if (sousLigne.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  sousLigne,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: texteDouxAccueil,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            MiniCarte(
              latitude: bien.location?.latitude?.toDouble(),
              longitude: bien.location?.longitude?.toDouble(),
              onOuvrirMaps: lien.isEmpty ? null : () => _ouvrir(lien),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Propriétaire ────────────────────────────────────────────────

  List<Widget> _proprietaire(Realestate bien) {
    final owner = bien.owner;
    if (owner == null) return const [];

    final nom = (owner.name ?? '').trim();
    if (nom.isEmpty && (owner.tel ?? '').trim().isEmpty) return const [];

    return [
      CarteAccueil(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Text(
                _initiales(nom),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SurTitre('Propriétaire'),
                  const SizedBox(height: 3),
                  Text(
                    nom.isEmpty ? 'Propriétaire' : nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: texteAccueil,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            BoutonsContact(tel: owner.tel),
          ],
        ),
      ),
    ];
  }

  /// « Youssef Amrani » → « YA ».
  String _initiales(String nom) {
    final mots = nom
        .split(RegExp(r'\s+'))
        .where((m) => m.trim().isNotEmpty)
        .toList();
    if (mots.isEmpty) return '?';
    if (mots.length == 1) {
      return mots.first.substring(0, 1).toUpperCase();
    }
    return '${mots.first.substring(0, 1)}${mots[1].substring(0, 1)}'
        .toUpperCase();
  }

  // ── Visite 360° ─────────────────────────────────────────────────

  List<Widget> _visite360(Realestate bien) {
    final lien = bien.tour360Url?.trim() ?? '';
    if (lien.isEmpty) return const [];

    return [
      CarteAccueil(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.view_in_ar,
                size: 19,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Visite 360°',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: texteAccueil,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ouvrir la visite virtuelle du bien',
                    style: TextStyle(fontSize: 12, color: texteDouxAccueil),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ouvrir la visite 360°',
              onPressed: () => _ouvrir(lien),
              icon: const Icon(
                Icons.open_in_new,
                size: 20,
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Actions ─────────────────────────────────────────────────────

  void _retour() {
    final routeur = GoRouter.of(context);
    if (routeur.canPop()) {
      routeur.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _relire() => context.read<ImmobilierDetailCubit>().fetchData();

  Future<void> _actualiser() async => _relire();

  void _partager(Realestate bien) => PartageBien.partager(context, bien);

  void _ouvrirCalendrier(Realestate bien) {
    final titre = (bien.title ?? '').trim();
    GoRouter.of(context).push(
      Uri(
        path: Routes.calendrierBien.replaceAll(':id', widget.id.toString()),
        queryParameters: titre.isEmpty ? null : {'titre': titre},
      ).toString(),
    );
  }

  Future<void> _ouvrir(String lien) async {
    final uri = Uri.tryParse(lien);
    final messager = ScaffoldMessenger.maybeOf(context);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception();
    } catch (_) {
      messager?.showSnackBar(
        const SnackBar(
          content: Text("Le lien n'a pas pu être ouvert sur cet appareil."),
        ),
      );
    }
  }

  Future<void> _desactiver(Realestate bien) async {
    final ok = await desactiverBienAvecDialogue(context, bien.id ?? widget.id);
    if (!ok || !mounted) return;
    // Signal de rafraichissement pour les listes appelantes.
    final routeur = GoRouter.of(context);
    if (routeur.canPop()) {
      routeur.pop(true);
    } else {
      _relire();
    }
  }

  Future<void> _reactiver(Realestate bien) async {
    final reactive = await reactiverBienAvecDialogue(
      context,
      bien.id ?? widget.id,
      titre: bien.title,
    );
    if (reactive != null && mounted) _relire();
  }
}

/// Une ligne du menu ⋮ : une icône, un libellé.
class _LigneMenu extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final Color? teinte;

  const _LigneMenu({required this.icone, required this.libelle, this.teinte});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 19, color: teinte ?? texteAccueil),
        const SizedBox(width: 12),
        Text(
          libelle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: teinte ?? texteAccueil,
          ),
        ),
      ],
    );
  }
}
