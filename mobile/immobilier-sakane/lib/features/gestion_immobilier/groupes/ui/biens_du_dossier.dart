import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/features/immobilier/list_immobilier/ui/components/realestate_widget.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/brouillons.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/liste_brouillons.dart';
import 'package:immobilier/features/ventes/ui/ventes.dart';
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';

/// Quatrième niveau : les biens d'un dossier.
///
/// L'administrateur peut y déplacer un bien vers un autre dossier, ou
/// l'en sortir. Le rangement se fait donc là où l'on constate qu'il
/// manque, sans avoir à revenir en arrière.
class BiensDuDossierPage extends StatefulWidget {
  final TypeBien type;
  final EtatBien etat;
  final int? dossierId;
  final String nomDossier;

  const BiensDuDossierPage({
    super.key,
    required this.type,
    required this.etat,
    required this.dossierId,
    required this.nomDossier,
  });

  @override
  State<BiensDuDossierPage> createState() => _BiensDuDossierPageState();
}

class _BiensDuDossierPageState extends State<BiensDuDossierPage> {
  TypeBien get type => widget.type;
  EtatBien get etat => widget.etat;
  int? get dossierId => widget.dossierId;
  String get nomDossier => widget.nomDossier;

  /// Longue duree : vrai si le bien a un bail en cours.
  Map<int, bool>? _loues;

  /// Vente : le statut de vente de chaque bien.
  Map<int, BienVente>? _ventes;

  @override
  void initState() {
    super.initState();
    _chargerStatuts();
  }

  /// Le statut propre a la famille (loue / libre, statut de vente) vient
  /// de son module ; sans reponse, la carte n'affiche simplement pas de statut.
  Future<void> _chargerStatuts() async {
    if (!peutVoirBaux) return;
    final depot = Dependencies.get<Repository>();
    try {
      if (type.code == 'rent-long') {
        final biens = await depot.fetchBiensLongueDuree();
        if (mounted) setState(() => _loues = {for (final b in biens) b.id: !b.libre});
      } else if (type.code == 'selle') {
        final biens = await depot.fetchBiensVente();
        if (mounted) setState(() => _ventes = {for (final b in biens) b.id: b});
      }
    } catch (_) {}
  }

  // La gestion des dossiers n'est plus masquee selon le role lu dans
  // l'application : un bouton absent n'explique rien. Le serveur reste
  // seul juge et repond par un message clair a qui n'y a pas droit.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: Text(nomDossier),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "${type.titre} · ${etat.titre}",
              style: TextStyle(
                  fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ),
      ),
      floatingActionButton: !peut(AppPermission.createProperty) ? null : FloatingActionButton.extended(
        // Le bien est cree dans ce dossier, avec la famille du dossier :
        // le mandat d'une vente se cree ensuite depuis la fiche du bien.
        onPressed: () => _ajouterBien(context),
        backgroundColor: type.code == 'selle' ? CouleursVente.teinte : AppColors.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un bien',
            style: TextStyle(color: Colors.white)),
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
          final biens = state.biensDuDossier(type.code, etat, dossierId);
          final vente = type.code == 'selle';
          // Les brouillons du telephone rattaches a ce dossier.
          final brouillons = dossierId == null ? const <BrouillonBien>[] : Brouillons.filtrer(dossierId: dossierId);

          if (biens.isEmpty && brouillons.isEmpty) {
            return _vide(vente);
          }

          return RefreshIndicator(
            onRefresh: () => Future.wait([context.read<GroupesCubit>().charger(), _chargerStatuts()]),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              children: [
                if (brouillons.isNotEmpty) ...[
                  _titreSection(Icons.edit_note, 'Brouillons', brouillons.length),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: MentionBrouillonsLocaux(),
                  ),
                  for (final b in brouillons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CarteBrouillon(
                        brouillon: b,
                        onReprendre: () => _reprendre(context, b),
                        onSupprimer: () async {
                          if (await supprimerBrouillon(context, b) && mounted) setState(() {});
                        },
                      ),
                    ),
                  if (biens.isNotEmpty) _titreSection(Icons.home_work_outlined, vente ? 'Biens à vendre' : 'Biens', biens.length),
                ],
                for (final b in biens)
                  vente && _ventes?[b.id] != null ? _carteVente(context, _ventes![b.id]!, b, state) : _carte(context, b, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _ajouterBien(BuildContext context) async {
    final cubit = context.read<GroupesCubit>();
    await GoRouter.of(context).push(cheminAjoutBien(type: type.code, dossier: dossierId));
    if (!mounted) return;
    cubit.charger();
    _chargerStatuts();
    setState(() {});
  }

  Future<void> _reprendre(BuildContext context, BrouillonBien b) async {
    final cubit = context.read<GroupesCubit>();
    await GoRouter.of(context).push(cheminAjoutBien(brouillon: b.id));
    if (!mounted) return;
    cubit.charger();
    _chargerStatuts();
    setState(() {});
  }

  Future<void> _ouvrirVente(int id, {String? onglet}) async {
    await GoRouter.of(context).push(cheminDossierVente(id, onglet: onglet));
    if (mounted) _chargerStatuts();
  }

  Widget _titreSection(IconData icone, String texte, int nombre) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icone, size: 19, color: CouleursBail.texte),
          const SizedBox(width: 8),
          Text('$texte ($nombre)',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
        ],
      ),
    );
  }

  Widget _vide(bool vente) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(vente ? Icons.sell_outlined : Icons.folder_open_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              etat == EtatBien.tous ? "Ce dossier est vide." : "Ce dossier ne contient aucun bien dans cette vue.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
            ),
            if (vente) ...[
              const SizedBox(height: 6),
              Text(
                "Touchez « Ajouter un bien » : saisissez le bien, son propriétaire et ses photos. "
                "Le mandat (عقد وساطة عقارية) se crée ensuite depuis la fiche du bien, déjà pré-rempli.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Vente : photo, prix, statut, mandat et visites ; les recus de visite a portee de main.
  Widget _carteVente(BuildContext context, BienVente v, Realestate bien, GroupesState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarteBienVente(
        bien: v,
        onTap: () => _ouvrirVente(v.id),
        pied: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => _ouvrirVente(v.id, onglet: 'visites'),
                icon: const Icon(Icons.receipt_long_outlined, size: 19),
                label: Text('Reçus de visite (${v.nbVisites})', maxLines: 1, overflow: TextOverflow.ellipsis),
                style: TextButton.styleFrom(
                  foregroundColor: CouleursVente.teinte,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: CouleursBail.texteDoux),
              color: Colors.white,
              onSelected: (a) => a == 'fiche' ? _ouvrirBien(context, bien) : _agir(context, a, bien, state),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'fiche', child: Text('Fiche du bien')),
                if (_peutRanger) const PopupMenuItem(value: 'deplacer', child: Text('Déplacer')),
                if (dossierId != null && _peutRanger)
                  const PopupMenuItem(
                      value: 'sortir', child: Text('Retirer du dossier', style: TextStyle(color: CouleursBail.retard))),
                if (peutDesactiverBien())
                  const PopupMenuItem(
                      value: 'desactiver',
                      child: Text('Désactiver le bien', style: TextStyle(color: couleurDesactivation))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// La carte reprend celle de la liste des biens : photo, note et
  /// etiquettes. L'agent doit reconnaitre l'appartement d'un coup d'oeil,
  /// pas seulement lire son nom.
  Widget _carte(BuildContext context, Realestate bien, GroupesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RealestateWidget(
          realestate: bien,
          onClick: (b) => _ouvrirBien(context, b),
          // Appui long : « Désactiver le bien »
          onLondClick: peutDesactiverBien() ? (b) => _agir(context, 'appui_long', b, state) : null,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
          child: Row(
            children: [
              if (_libelleEtat(bien) != null) ...[
                Icon(Icons.circle, size: 9, color: _couleurEtat(bien)),
                const SizedBox(width: 6),
                Text(
                  _libelleEtat(bien)!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _couleurEtat(bien)),
                ),
              ],
              const Spacer(),
              if (_peutRanger)
              TextButton.icon(
                  onPressed: () => _agir(context, 'deplacer', bien, state),
                  icon: const Icon(Icons.drive_file_move_outline, size: 17),
                  label: const Text("Déplacer", style: TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              if (dossierId != null && _peutRanger) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _agir(context, 'sortir', bien, state),
                  icon: const Icon(Icons.folder_off_outlined, size: 17),
                  label: const Text("Retirer", style: TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Ranger un bien dans un dossier (ou l'en sortir).
  bool get _peutRanger => peutUn(const [
        AppPermission.updateFolder,
        AppPermission.createProperty,
        AppPermission.updateProperty,
      ]);

  void _agir(BuildContext context, String action, Realestate bien,
      GroupesState state) async {
    final cubit = context.read<GroupesCubit>();

    if (action == 'ouvrir') {
      _ouvrirBien(context, bien);
      return;
    }

    if (action == 'desactiver' || action == 'appui_long') {
      if (bien.id == null) return;
      // Menu ⋮ : dialogue directement ; appui long : feuille d'actions d'abord.
      final Future<bool> demande;
      if (action == 'desactiver') {
        demande = desactiverBienAvecDialogue(context, bien.id!);
      } else {
        demande = actionsBienParAppuiLong(context, bienId: bien.id!, titre: bien.title);
      }
      final ok = await demande;
      if (ok && mounted) {
        cubit.charger();
        _chargerStatuts();
      }
      return;
    }

    if (action == 'sortir') {
      final ok = await showDialogueQuestion(
        context,
        "Retirer « ${bien.title} » du dossier « $nomDossier » ?",
        "Retirer",
        "Annuler",
      );
      if (ok == true && bien.id != null) {
        cubit.deplacerVersDossier([bien.id!], null);
      }
      return;
    }

    if (action == 'deplacer') {
      final choix = await _choisirDossier(context, state, bien);
      if (choix == null || bien.id == null) return;

      // Un dossier d'une autre famille change la catégorie du bien :
      // on le dit avant de le faire.
      final familleActuelle = _familleDe(bien);
      String? familleCible;
      for (final d in state.dossiers ?? const <Dossier>[]) {
        if (choix != -1 && d.id == choix) familleCible = d.typeCode;
      }
      if (familleCible != null &&
          _familles.containsKey(familleCible) &&
          familleCible != familleActuelle) {
        if (!context.mounted) return;
        final ok = await _confirmerChangementFamille(
            context, familleActuelle, familleCible);
        if (ok != true) return;
      }

      cubit.deplacerVersDossier([bien.id!], choix == -1 ? null : choix);
    }
  }

  /// Les trois familles de biens, dans l'ordre d'affichage.
  static const Map<String, String> _familles = {
    'rent-short': 'Location vacances',
    'rent-long': 'Location longue durée',
    'selle': 'Vente',
  };

  String _nomFamille(String? code) => _familles[code] ?? 'Autre catégorie';

  String _familleDe(Realestate bien) => bien.typeTransaction?.value ?? type.code;

  Future<bool?> _confirmerChangementFamille(
      BuildContext context, String? actuelle, String nouvelle) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Changer de catégorie ?",
            style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: Text(
          "Ces biens passeront de « ${_nomFamille(actuelle)} » à "
          "« ${_nomFamille(nouvelle)} ». Ils apparaîtront dans cette catégorie.",
          style: const TextStyle(fontSize: 14, height: 1.35, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Déplacer"),
          ),
        ],
      ),
    );
  }

  /// -1 signifie « aucun dossier ».
  ///
  /// Les dossiers sont regroupés par famille ; celle du bien est signalée,
  /// car choisir un dossier d'une autre famille change sa catégorie.
  Future<int?> _choisirDossier(
      BuildContext context, GroupesState state, Realestate bien) {
    final dossiers = state.dossiers ?? const <Dossier>[];
    final familleActuelle = _familleDe(bien);

    final sections = <MapEntry<String?, List<Dossier>>>[
      for (final code in _familles.keys)
        MapEntry(code, dossiers.where((d) => d.typeCode == code).toList()),
      MapEntry(
          null,
          dossiers
              .where((d) => !_familles.containsKey(d.typeCode))
              .toList()),
    ]..removeWhere((s) => s.value.isEmpty);

    Widget entete(String? code) {
      final actuelle = code != null && code == familleActuelle;
      return Container(
        color: const Color(0xFFF4F5F7),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                (code == null ? "Autres dossiers" : _nomFamille(code))
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .6,
                  color: actuelle ? AppColors.primaryColor : Colors.grey.shade700,
                ),
              ),
            ),
            if (actuelle)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Catégorie actuelle",
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor),
                ),
              ),
          ],
        ),
      );
    }

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  "Déplacer « ${bien.title} » vers…",
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  "Un dossier d'une autre catégorie change aussi la catégorie du bien.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final section in sections) ...[
                      entete(section.key),
                      ...section.value.map((d) {
                        final autreFamille = section.key != null &&
                            section.key != familleActuelle;
                        return ListTile(
                          leading: Icon(Icons.folder_outlined,
                              size: 21,
                              color: autreFamille
                                  ? Colors.grey.shade600
                                  : AppColors.primaryColor),
                          title: Text(d.nom ?? ''),
                          subtitle: Text(
                            autreFamille
                                ? "${d.nombreBiens} bien(s) · passera en « ${_nomFamille(section.key)} »"
                                : "${d.nombreBiens} bien(s)",
                            style: TextStyle(
                                fontSize: 12,
                                color: autreFamille
                                    ? Colors.orange.shade800
                                    : null),
                          ),
                          trailing: bien.dossier?.id == d.id
                              ? const Icon(Icons.check, size: 19)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(d.id),
                        );
                      }),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          const Icon(Icons.folder_off_outlined, size: 21),
                      title: const Text("Aucun dossier"),
                      subtitle: const Text("La catégorie ne change pas",
                          style: TextStyle(fontSize: 12)),
                      onTap: () => Navigator.of(ctx).pop(-1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirBien(BuildContext context, Realestate bien) async {
    if (bien.id == null) return;
    final cubit = context.read<GroupesCubit>();
    final modifie = await GoRouter.of(context)
        .push(Routes.homeImmobilier.replaceFirst(':id', '${bien.id}'));
    // Bien desactive depuis sa page : la liste se recharge.
    if (modifie == true && mounted) {
      cubit.charger();
      _chargerStatuts();
    }
  }

  Color _couleurEtat(Realestate bien) {
    if (type.code == 'rent-long') {
      return _loues?[bien.id] == true ? CouleursBail.teinte : Colors.green.shade700;
    }
    if (type.code == 'selle') return CouleursVente.statut(_ventes?[bien.id]?.statutVente);
    if (bien.booking != null) return Colors.red.shade700;
    if (bien.aNettoyer || bien.enNettoyage) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  /// Null quand le statut propre a la famille n'est pas (encore) connu.
  String? _libelleEtat(Realestate bien) {
    // Reserve / disponible / nettoyage ne valent que pour la courte duree.
    if (type.code == 'rent-long') {
      final loue = _loues?[bien.id];
      return loue == null ? null : (loue ? "Loué" : "Libre");
    }
    if (type.code == 'selle') return _ventes?[bien.id]?.libelleStatut;
    if (bien.booking != null) return "Réservé";
    if (bien.enNettoyage) return "Nettoyage en cours";
    if (bien.aNettoyer) return "À nettoyer";
    return "Disponible";
  }
}
