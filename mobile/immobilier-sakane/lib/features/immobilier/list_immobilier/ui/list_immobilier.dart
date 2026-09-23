import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/bandeau_synchro.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/entete_defilant.dart';
import 'package:immobilier/components/tableaux_export.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/rafraichissement_auto.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/list_immobilier/bloc/realestate_cubit.dart';
import 'package:immobilier/features/immobilier/list_immobilier/ui/components/carte_bien.dart';
import 'package:immobilier/features/immobilier/list_immobilier/ui/components/filtres_biens.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Le nom de la famille tel qu'on le dit dans un sous-titre.
const Map<String, String> _famillesLisibles = {
  'rent-short': 'courte durée',
  'rent-long': 'longue durée',
  'selle': 'vente',
};

/// La liste des biens : chercher, filtrer, ouvrir.
///
/// L'écran tient en trois temps : ce qu'on cherche (la recherche et les
/// puces d'état), ce qu'on obtient (les cartes), et le seul geste qui
/// crée quelque chose (« Ajouter un bien », en bas, toujours à portée
/// de pouce).
class ImmobilierPage extends StatefulWidget {
  /// Filtres appliques a l'ouverture, quand l'ecran est atteint depuis
  /// la navigation par type puis par secteur.
  final String? typeInitial;
  final int? secteurInitial;
  final bool sansSecteur;

  /// Ecran atteint par la loupe : le champ de recherche prend le focus.
  final bool rechercheOuverte;

  const ImmobilierPage({
    super.key,
    this.typeInitial,
    this.secteurInitial,
    this.sansSecteur = false,
    this.rechercheOuverte = false,
  });

  static Widget page({
    String? typeInitial,
    int? secteurInitial,
    bool sansSecteur = false,
    bool rechercheOuverte = false,
  }) =>
      BlocProvider<RealestateCubit>(
        create: (ctx) => RealestateCubit(),
        child: ImmobilierPage(
          typeInitial: typeInitial,
          secteurInitial: secteurInitial,
          sansSecteur: sansSecteur,
          rechercheOuverte: rechercheOuverte,
        ),
      );

  @override
  State<ImmobilierPage> createState() => _ImmobilierPageState();
}

class _ImmobilierPageState extends State<ImmobilierPage>
    with RafraichissementAuto<ImmobilierPage> {
  late final CriteresBiens _criteres = CriteresBiens(
    type: widget.typeInitial ?? 'tous',
    secteurId: widget.secteurInitial,
    sansSecteur: widget.sansSecteur,
  );

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void rafraichir() => fetchData();

  TableauExportable? _tableauExport() {
    final tous = context.read<RealestateCubit>().state.realestates;
    if (tous == null) return null;
    return tableauBiens('Biens immobiliers', _criteres.appliquer(tous).toList());
  }

  /// « 42 biens · courte durée ». La famille n'apparaît que si l'écran a
  /// été ouvert sur l'une d'elles.
  String _sousTitre(RealestateState state) {
    final tous = state.realestates;
    if (tous == null) return 'Chargement…';
    final nombre = _criteres.appliquer(tous).length;
    final famille = _famillesLisibles[_criteres.type];
    final compte = '$nombre bien${nombre > 1 ? 's' : ''}';
    return famille == null ? compte : '$compte · $famille';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RealestateCubit, RealestateState>(
      listener: (context, state) {
        if (state.deleteStatus == AppStatus.success) {
          showToast("Bien supprimé avec succès", context, second: 2);
        } else if (state.deleteStatus == AppStatus.error) {
          showToast("",
              description: state.error ?? "Erreur de suppression",
              type: ToastificationType.error,
              context,
              second: 2);
        }
      },
      builder: (ctx, state) {
        return Scaffold(
          backgroundColor: fondAccueil,
          appBar: appBarClaire(
            titre: 'Biens',
            sousTitre: _sousTitre(state),
            actions: [BoutonExport(tableau: _tableauExport, couleur: texteAccueil)],
          ),
          body: RefreshIndicator(
            onRefresh: () => ctx.read<RealestateCubit>().fetchData(),
            color: AppColors.primaryColor,
            child: _contenu(state),
          ),
          bottomNavigationBar: _barreDuBas(),
        );
      },
    );
  }

  // ── Le corps ─────────────────────────────────────────────────────

  Widget _contenu(RealestateState state) {
    if (state.fetchStatus == AppStatus.loading && state.realestates == null) {
      return const _SqueletteListeBiens();
    }

    if (state.realestates == null) {
      // Rien n'a pu être lu : la carte d'erreur remplace la liste.
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          CarteErreurResume(
            message: state.error ?? "La liste des biens n'a pas pu être lue.",
            onReessayer: fetchData,
          ),
        ],
      );
    }

    final tous = state.realestates!;
    final filtres = _criteres.appliquer(tous);
    final enErreur = state.fetchStatus == AppStatus.error;

    return PageAEnTeteDefilant(
      entete: [
        const BandeauSynchro(),
        if (enErreur)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: CarteErreurResume(
              message: state.error ?? "La liste n'a pas pu être relue.",
              onReessayer: fetchData,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FiltresBiens(
            criteres: _criteres,
            tousLesBiens: tous,
            nombreAffiche: filtres.length,
            onChange: () => setState(() {}),
            rechercheOuverte: widget.rechercheOuverte,
          ),
        ),
      ],
      corps: tous.isEmpty
          ? _aucunBien()
          : filtres.isEmpty
              ? _aucunResultat()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: filtres.length,
                  itemBuilder: (context, index) {
                    final bien = filtres.elementAt(index);
                    return CarteBien(
                      bien: bien,
                      familleCode: _criteres.type == 'tous' ? null : _criteres.type,
                      onTap: _ouvrirBien,
                      // Appui long : désactiver, ou supprimer.
                      onAppuiLong: _actionsPossibles ? _actionsAppuiLong : null,
                    );
                  },
                ),
    );
  }

  /// Aucun bien ne correspond aux critères choisis.
  Widget _aucunResultat() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 30, 12, 24),
      children: [
        const Icon(Icons.search_off_rounded, size: 50, color: Color(0xFFA7B4BB)),
        const SizedBox(height: 12),
        const Text(
          "Aucun bien ne correspond à votre recherche",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w700, color: texteAccueil),
        ),
        const SizedBox(height: 6),
        const Text(
          "Essayez un autre mot, ou effacez les filtres.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: texteDouxAccueil),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _criteres.reinitialiser();
              _criteres.recherche = '';
              _criteres.etat = 'tous';
            }),
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text("Effacer les filtres"),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _aucunBien() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 24),
      children: const [
        Icon(Icons.home_work_outlined, size: 56, color: Color(0xFFA7B4BB)),
        SizedBox(height: 14),
        Text(
          "Aucun bien pour l'instant",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15.5, fontWeight: FontWeight.w800, color: texteAccueil),
        ),
        SizedBox(height: 6),
        Text(
          "Le premier bien ajouté apparaîtra ici.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: texteDouxAccueil),
        ),
      ],
    );
  }

  // ── Le bouton du bas ─────────────────────────────────────────────

  Widget? _barreDuBas() {
    if (!peut(AppPermission.createProperty)) return null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: bordureAccueil)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _ajouterBien,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Ajouter un bien',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Les gestes ───────────────────────────────────────────────────

  void fetchData() {
    BlocProvider.of<RealestateCubit>(context).fetchData();
  }

  void _ajouterBien() async {
    final famille = _criteres.type == 'tous' ? null : _criteres.type;
    final chemin = famille == null
        ? Routes.addImmobilier
        : Uri(path: Routes.addImmobilier, queryParameters: {'type': famille})
            .toString();
    await GoRouter.of(context).push(chemin);
    if (mounted) fetchData();
  }

  void _ouvrirBien(Realestate r) async {
    final modifie = await GoRouter.of(context)
        .push(Routes.homeImmobilier.replaceAll(":id", r.id.toString()));
    if (modifie == true && mounted) fetchData();
  }

  /// Au moins une action possible par appui long sur une carte.
  bool get _actionsPossibles =>
      peutDesactiverBien() || peut(AppPermission.deleteProperty);

  /// Appui long : les gestes qui ne se font pas par mégarde — désactiver
  /// le bien, ou le supprimer — passent par une feuille, jamais par un
  /// bouton posé sur la carte.
  Future<void> _actionsAppuiLong(Realestate r) async {
    if (r.id == null) return;
    final peutSupprimer = peut(AppPermission.deleteProperty);

    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((r.title ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  r.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: texteAccueil),
                ),
              ),
            if (peutDesactiverBien())
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined,
                    color: orangeAccueil),
                title: const Text('Désactiver le bien',
                    style: TextStyle(
                        color: orangeAccueil, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(feuille).pop('desactiver'),
              ),
            if (peutSupprimer)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: rougeAccueil),
                title: const Text('Supprimer le bien',
                    style: TextStyle(
                        color: rougeAccueil, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(feuille).pop('supprimer'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || choix == null) return;

    if (choix == 'desactiver') {
      final desactive = await desactiverBienAvecDialogue(context, r.id!);
      if (desactive && mounted) fetchData();
      return;
    }

    final confirme = await showDialogueQuestion(
        context, "Voulez-vous vraiment supprimer ce bien ?");
    if (confirme == true && mounted) {
      BlocProvider.of<RealestateCubit>(context).deleteRealestate(r);
    }
  }
}

/// L'esquisse de la liste, le temps de la première lecture.
class _SqueletteListeBiens extends StatelessWidget {
  const _SqueletteListeBiens();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const BlocSquelette(hauteur: 46, rayon: 24),
        const SizedBox(height: 12),
        Row(
          children: const [
            BlocSquelette(hauteur: 30, largeur: 84, rayon: 20),
            SizedBox(width: 7),
            BlocSquelette(hauteur: 30, largeur: 110, rayon: 20),
            SizedBox(width: 7),
            BlocSquelette(hauteur: 30, largeur: 96, rayon: 20),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(4, (_) => const _SqueletteCarteBien()),
      ],
    );
  }
}

class _SqueletteCarteBien extends StatelessWidget {
  const _SqueletteCarteBien();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: CarteAccueil(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlocSquelette(hauteur: 88, largeur: 88, rayon: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocSquelette(hauteur: 13, largeur: 150),
                  SizedBox(height: 8),
                  BlocSquelette(hauteur: 10, largeur: 110),
                  SizedBox(height: 10),
                  BlocSquelette(hauteur: 10, largeur: 130),
                  SizedBox(height: 14),
                  BlocSquelette(hauteur: 14, largeur: 96, rayon: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
