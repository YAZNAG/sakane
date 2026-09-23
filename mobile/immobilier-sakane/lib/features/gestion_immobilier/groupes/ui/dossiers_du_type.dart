import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/nom_agence.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/apparence_dossier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/biens_du_dossier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/carte_dossier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/choix_agents.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/brouillons.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/liste_brouillons.dart';
import 'package:immobilier/features/ventes/ui/components/bandeau_ventes.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Le rang d'une étape de saisie, pour l'annoncer au reprenant.
const Map<String, int> _rangDesEtapes = {
  'mandat': 1,
  'signature': 1,
  'base': 1,
  'location': 2,
  'details': 3,
  'features': 4,
  'images': 5,
};

/// Troisième niveau : les dossiers, pour un type et un état donnés.
///
/// Un dossier est un repère de rangement — un immeuble, une résidence —
/// et la grille en montre autant que possible d'un seul regard : on
/// cherche un dossier par sa forme avant de lire son nom.
///
/// La création et la suppression de dossiers ne sont proposées que
/// depuis « Tous les biens » : c'est la vue d'ensemble, la seule où le
/// classement se décide sans risque d'oublier un bien filtré.
///
/// La vente arrive directement ici : ses statuts s'affichent en tete,
/// comme compteurs, au-dessus des dossiers.
class DossiersDuTypePage extends StatefulWidget {
  final TypeBien type;
  final EtatBien etat;

  const DossiersDuTypePage({
    super.key,
    required this.type,
    required this.etat,
  });

  @override
  State<DossiersDuTypePage> createState() => _DossiersDuTypePageState();
}

class _DossiersDuTypePageState extends State<DossiersDuTypePage> {
  final GlobalKey<BandeauVentesState> _bandeau = GlobalKey();
  final TextEditingController _champ = TextEditingController();

  /// La loupe ouvre le champ ; le champ filtre les dossiers par leur nom.
  bool _recherche = false;
  String _terme = '';

  TypeBien get type => widget.type;
  EtatBien get etat => widget.etat;

  bool get _vente => type.code == 'selle' && etat == EtatBien.tous;

  bool get _gestionPossible =>
      etat == EtatBien.tous && peut(AppPermission.createFolder);

  bool get _ajoutPossible => peut(AppPermission.createProperty);

  /// Au moins une action possible sur un dossier existant.
  bool get _menuDossierPossible => peutUn(const [
        AppPermission.updateFolder,
        AppPermission.assignFolderAgents,
        AppPermission.deleteFolder,
      ]);

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _actualiser(BuildContext context) => Future.wait([
        context.read<GroupesCubit>().charger(),
        if (_bandeau.currentState != null) _bandeau.currentState!.recharger(),
      ]);

  /// Ajout d'un bien hors dossier, ou reprise d'un brouillon de vente.
  Future<void> _ajouterBien(BuildContext context) async {
    final cubit = context.read<GroupesCubit>();
    await GoRouter.of(context).push(cheminAjoutBien(type: type.code));
    if (mounted) {
      cubit.charger();
      setState(() {});
    }
  }

  Future<void> _brouillons(BuildContext context) async {
    final cubit = context.read<GroupesCubit>();
    final routeur = GoRouter.of(context);
    final b = await ouvrirBrouillons(context, type: type.code);
    if (!mounted) return;
    setState(() {});
    if (b == null) return;
    await routeur.push(cheminAjoutBien(brouillon: b.id));
    if (mounted) {
      cubit.charger();
      setState(() {});
    }
  }

  // ── La barre de titre ────────────────────────────────────────────

  /// Le sous-titre dit où l'on est : la nature des dossiers et l'agence,
  /// ou l'état parcouru quand l'écran est atteint par un filtre.
  String get _sousTitre {
    if (etat != EtatBien.tous) return '${etat.titre} · ${type.titre}';
    final agence = NomAgence.connu;
    final base = _vente ? 'Dossiers de vente' : 'Immeubles et résidences';
    return agence.isEmpty ? base : '$base · $agence';
  }

  AppBar _barre() {
    if (_recherche) {
      return appBarClaire(
        titre: '',
        retour: IconButton(
          icon: const Icon(Icons.arrow_back, color: texteAccueil),
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
                hintText: 'Nom du dossier…',
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
      titre: 'Dossiers',
      sousTitre: _sousTitre,
      actions: [
        IconButton(
          tooltip: 'Chercher un dossier',
          onPressed: () => setState(() => _recherche = true),
          icon: const Icon(Icons.search_rounded, color: texteAccueil),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondAccueil,
      appBar: _barre(),
      body: BlocConsumer<GroupesCubit, GroupesState>(
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success) {
            final changees = state.categorieChangee ?? 0;
            showToast(state.message ?? "Enregistré", context,
                second: changees > 0 ? 3 : 2,
                description: changees > 0 ? "Catégorie modifiée" : null);
          } else if (state.actionStatus == AppStatus.error) {
            showToast("", context,
                description: state.error ?? "L'opération n'a pas abouti",
                type: ToastificationType.error,
                second: 3);
          }
        },
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading && state.biens == null) {
            return const _SqueletteDossiers();
          }

          if (state.biens == null) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: [
                CarteErreurResume(
                  message: state.error ?? "Les dossiers n'ont pas pu être lus.",
                  onReessayer: () => context.read<GroupesCubit>().charger(),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () => _actualiser(context),
            color: AppColors.primaryColor,
            child: _corps(context, state),
          );
        },
      ),
      bottomNavigationBar: _barreDuBas(context),
    );
  }

  // ── Le corps ─────────────────────────────────────────────────────

  Widget _corps(BuildContext context, GroupesState state) {
    final tous = state.dossiersDuType(type.code, etat);

    // « Hors dossier » se présente à part, en fin de grille.
    final horsDossier = tous.where((d) => d.id == null).firstOrNull;
    var dossiers = tous.where((d) => d.id != null).toList();
    if (_terme.isNotEmpty) {
      final q = _terme.toLowerCase();
      dossiers =
          dossiers.where((d) => d.nom.toLowerCase().contains(q)).toList();
    }

    final brouillons = Brouillons.filtrer(type: type.code);
    final enErreur = state.fetchStatus == AppStatus.error;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          14, 14, 14, (_gestionPossible || _ajoutPossible) ? 14 : 24),
      children: [
        if (enErreur) ...[
          CarteErreurResume(
            message: state.error ?? "Les dossiers n'ont pas pu être relus.",
            onReessayer: () => context.read<GroupesCubit>().charger(),
          ),
          const SizedBox(height: 12),
        ],
        if (_vente) ...[
          BandeauVentes(key: _bandeau),
          const SizedBox(height: 12),
        ],
        if (brouillons.isNotEmpty) ...[
          _bandeauBrouillons(context, brouillons),
          const SizedBox(height: 12),
        ],
        if (dossiers.isEmpty && horsDossier == null)
          _aucunDossier()
        else ...[
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 167 / 148,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...dossiers.map((d) {
                final complet =
                    (state.dossiers ?? []).where((x) => x.id == d.id).firstOrNull;
                return CarteDossier(
                  dossierId: d.id,
                  nom: d.nom,
                  nombreBiens: d.nombre,
                  nombreAgents: complet?.agents.length ?? 0,
                  onTap: () => _ouvrirDossier(context, d),
                  onMenu: _menuDossierPossible
                      ? () => _actionsDossier(context, d, state)
                      : null,
                );
              }),
              if (horsDossier != null)
                CarteDossier(
                  nom: 'Hors dossier',
                  nombreBiens: horsDossier.nombre,
                  horsDossier: true,
                  onTap: () => _ouvrirDossier(context, horsDossier),
                ),
            ],
          ),
          if (_terme.isNotEmpty && dossiers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                "Aucun dossier ne porte ce nom.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: texteDouxAccueil),
              ),
            ),
        ],
        if (_menuDossierPossible) ...[
          const SizedBox(height: 14),
          _carteAide(),
        ],
      ],
    );
  }

  /// « 2 brouillons · dernier le 21 sep 2026 à l'étape 3 ».
  Widget _bandeauBrouillons(
      BuildContext context, List<BrouillonBien> brouillons) {
    final dernier = brouillons.first;
    final etape = _rangDesEtapes[dernier.etape] ?? 1;
    final jour = DateTime(
        dernier.modifieLe.year, dernier.modifieLe.month, dernier.modifieLe.day);
    final quand = jour == aujourdhui() ? "aujourd'hui" : 'le ${dateMoyenne(jour)}';

    return Material(
      color: const Color(0xFFFFF4E5),
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: InkWell(
        onTap: () => _brouillons(context),
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(rayonAccueil),
            border: Border.all(color: const Color(0xFFF3DEBE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 22, color: orangeAccueil),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reprendre un bien commencé',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8A5100)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pluriel(brouillons.length, 'brouillon')} · '
                      "dernier $quand à l'étape $etape",
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF8A6100),
                        fontFeatures: chiffresTabulaires,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8A6100)),
            ],
          ),
        ),
      ),
    );
  }

  /// Ce que le menu ⋮ propose : dit une fois, en bas, plutôt que deviné.
  Widget _carteAide() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F5),
        borderRadius: BorderRadius.circular(rayonAccueil),
        border: Border.all(color: bordureAccueil),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, size: 18, color: texteDouxAccueil),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Le menu ⋮ d'un dossier : renommer, icône et couleur, "
              "agents autorisés, défaire le dossier.",
              style:
                  TextStyle(fontSize: 12, height: 1.35, color: texteDouxAccueil),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aucunDossier() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
      child: Column(
        children: [
          const Icon(Icons.create_new_folder_outlined,
              size: 52, color: Color(0xFFA7B4BB)),
          const SizedBox(height: 14),
          Text(
            _vente ? "Aucun dossier de vente" : "Aucun dossier",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w800, color: texteAccueil),
          ),
          const SizedBox(height: 6),
          const Text(
            "Créez un dossier pour ranger vos biens — un immeuble, une "
            "résidence — puis ajoutez-y un bien.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: texteDouxAccueil),
          ),
        ],
      ),
    );
  }

  // ── Les deux boutons du bas ──────────────────────────────────────

  Widget? _barreDuBas(BuildContext context) {
    if (!_gestionPossible && !_ajoutPossible) return null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: bordureAccueil)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              if (_gestionPossible)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => _creerDossier(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        side: const BorderSide(color: AppColors.primaryColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Nouveau dossier',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              if (_gestionPossible && _ajoutPossible) const SizedBox(width: 10),
              if (_ajoutPossible)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => _ajouterBien(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Ajouter un bien',
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Les gestes ───────────────────────────────────────────────────

  void _ouvrirDossier(BuildContext context, GroupeDossier dossier) async {
    final cubit = context.read<GroupesCubit>();

    if (etat == EtatBien.tous) {
      // Vue d'ensemble : c'est la qu'on range, deplace et retire.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: BiensDuDossierPage(
            type: type,
            etat: etat,
            dossierId: dossier.id,
            nomDossier: dossier.nom,
          ),
        ),
      ));
      // Les brouillons ont pu changer dans le dossier.
      if (mounted) setState(() {});
      if (_vente) _bandeau.currentState?.recharger();
      return;
    }

    // Les autres etats ouvrent l'ecran par statut, limite a ce dossier :
    // l'agent y retrouve les actions de terrain.
    await GoRouter.of(context).push(
      Uri(
        path: Routes.immobilierByStatus.replaceFirst(':status', etat.statut),
        queryParameters: {
          'type': type.code,
          'dossier': dossier.id?.toString() ?? 'aucun',
        },
      ).toString(),
    );
    if (context.mounted) cubit.charger();
  }

  /// Renommer, changer son repère, le confier à des agents, ou le défaire.
  void _actionsDossier(
      BuildContext context, GroupeDossier dossier, GroupesState state) {
    final cubit = context.read<GroupesCubit>();
    final complet =
        (state.dossiers ?? []).where((d) => d.id == dossier.id).firstOrNull;
    final agents = complet?.agents ?? const <AgentDuDossier>[];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Icon(ApparencesDossiers.de(dossier.id).icone,
                      size: 20, color: ApparencesDossiers.de(dossier.id).couleur),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(dossier.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: texteAccueil)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: bordureAccueil),
            if (peut(AppPermission.updateFolder))
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline, size: 21),
                title: const Text("Renommer"),
                onTap: () {
                  Navigator.of(feuille).pop();
                  _renommer(context, dossier, cubit);
                },
              ),
            ListTile(
              leading: const Icon(Icons.palette_outlined, size: 21),
              title: const Text("Icône et couleur"),
              subtitle: const Text("Repère gardé sur ce téléphone",
                  style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.of(feuille).pop();
                if (dossier.id == null) return;
                final change = await ApparencesDossiers.choisir(
                  context,
                  dossierId: dossier.id!,
                  nom: dossier.nom,
                );
                if (change && mounted) setState(() {});
              },
            ),
            if (peut(AppPermission.assignFolderAgents))
              ListTile(
                leading: const Icon(Icons.people_alt_outlined, size: 21),
                title: const Text("Agents autorisés"),
                subtitle: Text(
                  agents.isEmpty
                      ? "Ouvert à toute l'équipe"
                      : agents.map((a) => a.nom).join(', '),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  Navigator.of(feuille).pop();
                  final choisis = await ChoixAgents.ouvrir(
                    context,
                    nomDossier: dossier.nom,
                    selection: agents
                        .where((a) => a.id != null)
                        .map((a) => a.id!)
                        .toList(),
                  );
                  if (choisis != null && dossier.id != null) {
                    cubit.affecterAgents(dossier.id!, choisis);
                  }
                },
              ),
            if (peut(AppPermission.deleteFolder))
              ListTile(
                leading: const Icon(Icons.folder_off_outlined,
                    size: 21, color: rougeAccueil),
                title: const Text("Défaire le dossier",
                    style: TextStyle(color: rougeAccueil)),
                subtitle: Text(
                  dossier.nombre > 0
                      ? "Impossible : ${dossier.nombre} bien(s) à l'intérieur"
                      : "Le dossier est vide",
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.of(feuille).pop();
                  _supprimer(context, dossier, cubit);
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _renommer(
      BuildContext context, GroupeDossier dossier, GroupesCubit cubit) async {
    final nom = TextEditingController(text: dossier.nom);
    final valide = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Renommer le dossier"),
        content: TextField(
          controller: nom,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: "Nom du dossier"),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text("Renommer")),
        ],
      ),
    );

    final nouveau = nom.text.trim();
    if (valide == true && nouveau.isNotEmpty && nouveau != dossier.nom) {
      cubit.renommerDossier(dossier.id!, nouveau);
    }
  }

  void _supprimer(
      BuildContext context, GroupeDossier dossier, GroupesCubit cubit) async {
    // Le serveur refuse de toute facon : autant l'expliquer tout de suite.
    if (dossier.nombre > 0) {
      showToast("Dossier non vide", context,
          description: "Déplacez d'abord ses ${dossier.nombre} bien(s).",
          type: ToastificationType.warning,
          second: 4);
      return;
    }

    final ok = await showDialogueQuestion(
      context,
      "Défaire le dossier « ${dossier.nom} » ?",
      "Défaire",
      "Annuler",
    );
    if (ok == true && dossier.id != null) {
      // Le repère local n'a plus de dossier à désigner.
      ApparencesDossiers.oublier(dossier.id!);
      cubit.supprimerDossier(dossier.id!, dossier.nom);
    }
  }

  void _creerDossier(BuildContext context) async {
    final cubit = context.read<GroupesCubit>();
    final nom = TextEditingController();
    final description = TextEditingController();

    final valide = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Nouveau dossier"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nom,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Nom du dossier",
                hintText: "Ex : Immeuble Founty",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                labelText: "Description (facultatif)",
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Ce dossier appartiendra à « ${type.titre} » et "
              "n'apparaîtra pas dans les autres catégories.",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Créer"),
          ),
        ],
      ),
    );

    if (valide == true && nom.text.trim().isNotEmpty) {
      cubit.creerDossier(
        nom.text.trim(),
        description: description.text.trim(),
        typeCode: type.code,
      );
    }
  }
}

/// L'esquisse de la grille, le temps de la première lecture.
class _SqueletteDossiers extends StatelessWidget {
  const _SqueletteDossiers();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const BlocSquelette(hauteur: 64, rayon: rayonAccueil),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 167 / 148,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
              6, (_) => const BlocSquelette(hauteur: 148, rayon: rayonAccueil)),
        ),
      ],
    );
  }
}

extension _PremierOuNul<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
