import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/biens_du_dossier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/carte_groupe.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/choix_agents.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/brouillons.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/liste_brouillons.dart';
import 'package:immobilier/features/ventes/ui/components/bandeau_ventes.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';

/// Troisième niveau : les dossiers, pour un type et un état donnés.
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

  TypeBien get type => widget.type;
  EtatBien get etat => widget.etat;

  bool get _vente => type.code == 'selle' && etat == EtatBien.tous;

  bool get _gestionPossible => etat == EtatBien.tous && peut(AppPermission.createFolder);

  /// Au moins une action possible sur un dossier existant.
  bool get _menuDossierPossible => peutUn(const [
        AppPermission.updateFolder,
        AppPermission.assignFolderAgents,
        AppPermission.deleteFolder,
      ]);

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

  /// En-tete de la vente : compteurs par statut, puis brouillons du telephone.
  List<Widget> _enteteVente(BuildContext context) {
    final brouillons = Brouillons.filtrer(type: type.code).length;
    return [
      BandeauVentes(key: _bandeau),
      if (brouillons > 0) ...[
        const SizedBox(height: 10),
        Material(
          color: const Color(0xFFFFF7E0),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.edit_note, color: Color(0xFF8A6100)),
            title: Text(
              brouillons > 1 ? '$brouillons brouillons sur ce téléphone' : '1 brouillon sur ce téléphone',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text('Reprendre un bien commencé', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _brouillons(context),
          ),
        ),
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _videVente(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _actualiser(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          ..._enteteVente(context),
          const SizedBox(height: 30),
          Icon(Icons.create_new_folder_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            "Aucun dossier de vente",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 6),
          Text(
            "Créez un dossier (« Nouveau dossier ») pour ranger vos biens à vendre, "
            "puis ajoutez-y un bien : le mandat se crée ensuite depuis la fiche du bien.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // La gestion des dossiers n'est plus masquee selon le role lu dans
  // l'application : un bouton absent n'explique rien. Le serveur reste
  // seul juge et repond par un message clair a qui n'y a pas droit.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(_vente ? 'Vente de biens' : etat.titre),
        centerTitle: true,
        actions: [
          if (_vente)
            IconButton(
              tooltip: 'Ajouter un bien à vendre',
              onPressed: () => _ajouterBien(context),
              icon: const Icon(Icons.add_home_outlined),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _vente ? 'Dossiers de vente' : type.titre,
              style: TextStyle(
                  fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ),
      ),
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
          if (state.fetchStatus == AppStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final dossiers = state.dossiersDuType(type.code, etat);

          if (dossiers.isEmpty) {
            return _vente ? _videVente(context) : _aucunBien(context);
          }

          final brouillons = _vente ? Brouillons.filtrer(type: type.code) : const <BrouillonBien>[];

          return RefreshIndicator(
            onRefresh: () => _actualiser(context),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  14, 16, 14, _gestionPossible ? 90 : 24),
              children: [
                if (_vente) ..._enteteVente(context),
                _entete(state.compterEtat(type.code, etat), dossiers.length),
                const SizedBox(height: 14),
                ...dossiers.asMap().entries.map((e) {
                  final d = e.value;
                  final nbBrouillons = _vente ? brouillons.where((b) => b.dossierId == d.id && d.id != null).length : 0;
                  return CarteGroupe(
                    nombre: d.nombre,
                    titre: d.nom,
                    sousTitre: _vente
                        ? 'Biens à vendre${nbBrouillons > 0 ? ' · ${pluriel(nbBrouillons, 'brouillon')}' : ''}'
                        : etat.titre,
                    libelleAction: 'Voir les biens',
                    icone: d.id == null
                        ? Icons.folder_off_outlined
                        : Icons.folder_outlined,
                    degrade: _teinte(e.key),
                    onTap: () => _ouvrirDossier(context, d),
                    // Le groupe « Sans dossier » n'est pas un vrai dossier.
                    onMenu: d.id == null || !_menuDossierPossible
                        ? null
                        : () => _actionsDossier(context, d, state),
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _gestionPossible
          ? FloatingActionButton.extended(
              onPressed: () => _creerDossier(context),
              backgroundColor: AppColors.primaryColor,
              icon: const Icon(Icons.create_new_folder_outlined,
                  color: Colors.white),
              label: const Text('Nouveau dossier',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _entete(int total, int nbDossiers) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(etat.icone, size: 22, color: etat.degrade.first),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$total bien${total > 1 ? 's' : ''} dans "
              "$nbDossiers dossier${nbDossiers > 1 ? 's' : ''}",
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aucunBien(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(etat.icone, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              "Aucun bien dans cette catégorie",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              "${etat.titre} — ${type.titre.toLowerCase()}",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _teinte(int index) {
    final base = type.degrade;
    final facteur = (index % 4) * 0.09;
    return [
      Color.lerp(base.first, Colors.black, facteur)!,
      Color.lerp(base.last, Colors.white, facteur * 0.6)!,
    ];
  }

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

  /// Renommer, confier a des agents, ou supprimer si le dossier est vide.
  void _actionsDossier(
      BuildContext context, GroupeDossier dossier, GroupesState state) {
    final cubit = context.read<GroupesCubit>();
    final complet =
        (state.dossiers ?? []).where((d) => d.id == dossier.id).firstOrNull;
    final agents = complet?.agents ?? const <AgentDuDossier>[];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(dossier.nom,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (peut(AppPermission.updateFolder))
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline, size: 21),
              title: const Text("Renommer"),
              onTap: () {
                Navigator.of(feuille).pop();
                _renommer(context, dossier, cubit);
              },
            ),
            if (peut(AppPermission.assignFolderAgents))
            ListTile(
              leading: const Icon(Icons.people_alt_outlined, size: 21),
              title: const Text("Agents autorises"),
              subtitle: Text(
                agents.isEmpty
                    ? "Ouvert a toute l'equipe"
                    : agents.map((a) => a.nom).join(', '),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () async {
                Navigator.of(feuille).pop();
                final choisis = await ChoixAgents.ouvrir(
                  context,
                  nomDossier: dossier.nom,
                  selection:
                      agents.where((a) => a.id != null).map((a) => a.id!).toList(),
                );
                if (choisis != null && dossier.id != null) {
                  cubit.affecterAgents(dossier.id!, choisis);
                }
              },
            ),
            if (peut(AppPermission.deleteFolder))
            ListTile(
              leading: Icon(Icons.delete_outline,
                  size: 21, color: Colors.red.shade700),
              title: Text("Supprimer",
                  style: TextStyle(color: Colors.red.shade700)),
              subtitle: Text(
                dossier.nombre > 0
                    ? "Impossible : ${dossier.nombre} bien(s) a l'interieur"
                    : "Le dossier est vide",
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(feuille).pop();
                _supprimer(context, dossier, cubit);
              },
            ),
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
          description: "Deplacez d'abord ses ${dossier.nombre} bien(s).",
          type: ToastificationType.warning,
          second: 4);
      return;
    }

    final ok = await showDialogueQuestion(
      context,
      "Supprimer le dossier " + dossier.nom + " ?",
      "Supprimer",
      "Annuler",
    );
    if (ok == true && dossier.id != null) {
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

extension _PremierOuNul<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
