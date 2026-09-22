import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_error_dialogue.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/brouillons.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/base_information.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/liste_brouillons.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/location.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/property_details.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/property_features.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/property_images.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../../components/error_widget.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/enums/app_status.dart';
import '../bloc/add_modify_imm_bloc.dart';

/// Une phase de l'indicateur de progression, et les etapes qu'elle couvre.
class _Phase {
  final String libelle;
  final IconData icone;
  final List<String> etapes;

  const _Phase(this.libelle, this.icone, this.etapes);
}

class AddModifyImmobilierPage extends StatefulWidget {
  final int? id;

  /// Brouillon repris (ajout seulement).
  final BrouillonBien? brouillon;

  /// Famille preselectionnee (rent-short, rent-long, selle).
  final String? typeInitial;

  const AddModifyImmobilierPage(this.id, {super.key, this.brouillon, this.typeInitial});

  /// [type] et [dossier] : l'ajout lance depuis un dossier ; [brouillon] : id du brouillon a reprendre.
  static Widget page({int? id, String? type, int? dossier, String? brouillon}) {
    final b = id == null && brouillon != null ? Brouillons.lire(brouillon) : null;
    return BlocProvider(
      create: (context) => AddModifyImmBloc(
        id: id,
        typeInitial: b == null ? type : null,
        dossierInitial: b == null ? dossier : null,
        brouillon: b,
      )..add(FetchData()),
      child: AddModifyImmobilierPage(id, brouillon: b, typeInitial: type),
    );
  }

  @override
  State<AddModifyImmobilierPage> createState() =>
      _AddModifyImmobilierPageState();
}

class _AddModifyImmobilierPageState extends State<AddModifyImmobilierPage> {
  static const List<String> _etapesBien = ['base', 'location', 'details', 'features', 'images'];

  late String _etape;

  /// Id du brouillon en cours (repris, ou enregistre pendant la saisie).
  String? _brouillonId;

  /// Autorise a quitter sans poser la question du brouillon.
  bool _quitter = false;

  bool get isUpdate => widget.id != null;

  AddModifyImmBloc get _bloc => context.read<AddModifyImmBloc>();

  @override
  void initState() {
    super.initState();
    final b = widget.brouillon;
    _brouillonId = b?.id;
    // Les anciens brouillons de vente pouvaient s'arreter au mandat :
    // l'ajout d'un bien n'a plus d'etape de mandat.
    final etape = b?.etape;
    _etape = etape != null && _etapesBien.contains(etape) ? etape : 'base';
  }

  bool _estVente(AddModifyImmState s) => !isUpdate && s.realestate?.typeTransaction?.value == 'selle';

  List<String> _etapes(AddModifyImmState s) => _etapesBien;

  /// L'etape affichee, ramenee a une etape du parcours.
  String _etapeCourante(AddModifyImmState s) => _etapesBien.contains(_etape) ? _etape : 'base';

  static const List<_Phase> _phases = [
    _Phase('Infos', Icons.info_outline, ['base']),
    _Phase('Localisation', Icons.location_on_outlined, ['location']),
    _Phase('Détails', Icons.home_work_outlined, ['details']),
    _Phase('Équipements', Icons.featured_play_list_outlined, ['features']),
    _Phase('Photos', Icons.photo_library_outlined, ['images']),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddModifyImmBloc, AddModifyImmState>(
      listener: listener,
      builder: (context, state) {
        final pret = state.fetchData == AppStatus.success;
        return PopScope(
          canPop: isUpdate || _quitter || !pret || !_aDesDonnees(state),
          onPopInvokedWithResult: (aQuitte, _) {
            if (!aQuitte) _demanderAvantDeQuitter();
          },
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Text(
                isUpdate ? "Modifier un bien" : (_estVente(state) ? "Ajouter un bien à vendre" : "Ajouter un bien"),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              centerTitle: true,
              elevation: 0,
              foregroundColor: Colors.white,
              backgroundColor: _estVente(state) ? CouleursVente.teinte : AppColors.primaryColor,
              actions: [
                if (!isUpdate && pret) ...[
                  IconButton(
                    tooltip: 'Enregistrer comme brouillon',
                    onPressed: _enregistrerBrouillon,
                    icon: const Icon(Icons.save_outlined, color: Colors.white),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: Colors.white,
                    onSelected: (a) {
                      if (a == 'brouillon') _enregistrerBrouillon();
                      if (a == 'mes') _mesBrouillons();
                      if (a == 'supprimer') _supprimerBrouillonEnCours();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'brouillon', child: Text('Enregistrer comme brouillon')),
                      const PopupMenuItem(value: 'mes', child: Text('Mes brouillons')),
                      if (_brouillonId != null)
                        const PopupMenuItem(
                          value: 'supprimer',
                          child: Text('Supprimer le brouillon', style: TextStyle(color: CouleursBail.retard)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            body: _buildContent(state),
          ),
        );
      },
    );
  }

  /// Vrai des qu'il y a quelque chose a perdre en quittant.
  bool _aDesDonnees(AddModifyImmState s) {
    final r = s.realestate;
    return (r?.title ?? '').isNotEmpty ||
        (r?.description ?? '').isNotEmpty ||
        (r?.files ?? const []).isNotEmpty ||
        _etape != _etapes(s).first;
  }

  void listener(BuildContext context, AddModifyImmState state) {
    final cree = state.realestate;
    if (state.addModifyStatus == AppStatus.success && !isUpdate) {
      _quitter = true;
      final brouillon = _brouillonId;
      if (brouillon != null) Brouillons.supprimer(brouillon);
      final vente = cree?.typeTransaction?.value == 'selle';
      if (vente && cree?.id != null) {
        _apresAjoutVente(context, cree!.id!);
      } else {
        showToast(AppStrings.success, context, second: 2, whenComplete: () {
          GoRouter.of(context).pop();
        });
      }
    } else if (state.addModifyStatus == AppStatus.success) {
      showToast(AppStrings.success, context, second: 2, whenComplete: () {
        GoRouter.of(context).pop();
      });
    } else if (state.addModifyStatus == AppStatus.error) {
      if (state.errors != null) {
        showDialogueError(context, state.errors!);
      } else {
        showToast("",
            description: state.error ?? "Error",
            type: ToastificationType.error,
            context,
            second: 2);
      }
    }
  }

  /// Bien en vente cree : il est range dans son dossier. Le mandat se cree
  /// ensuite depuis la fiche du bien ; on propose d'y aller tout de suite.
  Future<void> _apresAjoutVente(BuildContext context, int id) async {
    final routeur = GoRouter.of(context);
    // Un ancien brouillon pouvait porter un mandat deja prepare : on le lie.
    final mandat = widget.brouillon?.mandatId;
    if (mandat != null) {
      try {
        await Dependencies.get<Repository>().lierMandatVente(mandat, id);
      } catch (_) {
        // Le mandat reste libre ; un nouveau mandat pourra etre cree depuis le bien.
      }
      if (!context.mounted) return;
    }
    if (!peutCreerMandat || mandat != null) {
      afficherMessage(context, 'Bien ajouté à son dossier.');
      routeur.pop();
      if (mandat != null) routeur.push(cheminDossierVente(id));
      return;
    }
    final choix = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.check_circle_outline, color: CouleursVente.aVendre, size: 40),
        title: const Text("Bien ajouté", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          "Le bien est enregistré dans son dossier. Vous pouvez maintenant créer son mandat de vente "
          "(عقد وساطة عقارية) : les données du bien et du propriétaire sont déjà pré-remplies.",
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Plus tard")),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.note_add_outlined, size: 18),
            label: const Text("Créer le mandat"),
            style: ElevatedButton.styleFrom(backgroundColor: CouleursVente.teinte, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    routeur.pop();
    if (choix == true) routeur.push(cheminDossierVente(id, nouveauMandat: true));
  }

  // ── Brouillons ───────────────────────────────────────────────────

  Future<BrouillonBien?> _sauverBrouillon() async {
    final r = _bloc.instantaneEtape?.call() ?? _bloc.state.realestate ?? Realestate();
    try {
      final b = await Brouillons.enregistrer(
        id: _brouillonId,
        bien: r,
        etape: _etapeCourante(_bloc.state),
      );
      _brouillonId = b.id;
      return b;
    } catch (_) {
      if (mounted) afficherMessage(context, "Le brouillon n'a pas pu être enregistré.", erreur: true);
      return null;
    }
  }

  Future<void> _enregistrerBrouillon() async {
    final b = await _sauverBrouillon();
    if (b == null || !mounted) return;
    setState(() {});
    afficherMessage(context, 'Brouillon enregistré sur ce téléphone. Retrouvez-le dans « Mes brouillons »'
        '${b.dossierId != null ? ' et dans son dossier' : ''}.');
  }

  Future<void> _mesBrouillons() async {
    final b = await ouvrirBrouillons(context);
    if (b == null || !mounted) return;
    if (b.id == _brouillonId) return;
    _quitter = true;
    GoRouter.of(context).pushReplacement(cheminAjoutBien(brouillon: b.id));
  }

  Future<void> _supprimerBrouillonEnCours() async {
    final b = _brouillonId == null ? null : Brouillons.lire(_brouillonId!);
    if (b == null) {
      setState(() => _brouillonId = null);
      return;
    }
    if (await supprimerBrouillon(context, b) && mounted) {
      setState(() => _brouillonId = null);
      afficherMessage(context, 'Brouillon supprimé.');
    }
  }

  /// Retour arriere avec une saisie en cours : brouillon, quitter, ou rester.
  Future<void> _demanderAvantDeQuitter() async {
    final choix = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Quitter l'ajout ?", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          "Enregistrez un brouillon pour reprendre plus tard exactement où vous en êtes. "
          "Il reste sur ce téléphone.",
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('rester'), child: const Text("Continuer la saisie")),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('quitter'),
            style: TextButton.styleFrom(foregroundColor: CouleursBail.retard),
            child: const Text("Quitter sans enregistrer"),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop('brouillon'),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text("Enregistrer le brouillon"),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (!mounted || choix == null || choix == 'rester') return;
    if (choix == 'brouillon') {
      final b = await _sauverBrouillon();
      if (b == null || !mounted) return;
      afficherMessage(context, 'Brouillon enregistré sur ce téléphone.');
    }
    setState(() => _quitter = true);
    if (mounted) Navigator.of(context).pop();
  }

  // ── Affichage ────────────────────────────────────────────────────

  Widget _buildContent(AddModifyImmState state) {
    if (state.fetchData == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchData == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: fetchData,
      );
    } else if (state.fetchData == AppStatus.success) {
      final enregistrement = state.addModifyStatus == AppStatus.loading;
      return Column(
        children: [
          _entete(state, enregistrement),
          if (_brouillonId != null && !isUpdate) _bandeauBrouillon(),
          if (_brouillonId == null && !isUpdate && _etapeCourante(state) == _etapes(state).first)
            _bandeauMesBrouillons(),
          Expanded(child: _buildForm(state)),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _bandeauBrouillon() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7E0),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: const Row(
        children: [
          Icon(Icons.edit_note, size: 18, color: Color(0xFF8A6100)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Brouillon — gardé sur ce téléphone',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF8A6100))),
          ),
        ],
      ),
    );
  }

  /// Au debut de la saisie : rappel des brouillons en attente sur ce telephone.
  Widget _bandeauMesBrouillons() {
    final n = Brouillons.tous().length;
    if (n == 0) return const SizedBox();
    return Material(
      color: const Color(0xFFFFF7E0),
      child: InkWell(
        onTap: _mesBrouillons,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.edit_note, size: 20, color: Color(0xFF8A6100)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n > 1 ? '$n brouillons sur ce téléphone' : '1 brouillon sur ce téléphone',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8A6100)),
                ),
              ),
              const Text('Mes brouillons',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF8A6100))),
              const Icon(Icons.chevron_right, color: Color(0xFF8A6100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entete(AddModifyImmState state, bool enregistrement) {
    final etape = _etapeCourante(state);
    final phases = _phases;
    final vente = _estVente(state);
    final teinte = vente ? CouleursVente.teinte : AppColors.primaryColor;
    var active = phases.indexWhere((p) => p.etapes.contains(etape));
    if (enregistrement && phases.last.etapes.isEmpty) active = phases.length - 1;
    final phase = phases[active < 0 ? 0 : active];
    final sousEtapes = phase.etapes.length;
    final rang = phase.etapes.indexOf(etape) + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(phases.length, (i) {
              final fait = i < active;
              final actif = i == active;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0 ? Colors.transparent : (i <= active ? Colors.green.shade600 : Colors.grey.shade300),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: fait ? Colors.green.shade600 : (actif ? teinte : Colors.grey.shade300),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fait ? Icons.check : phases[i].icone,
                            size: 16,
                            color: fait || actif ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == phases.length - 1
                                ? Colors.transparent
                                : (i < active ? Colors.green.shade600 : Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      phases[i].libelle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.15,
                        fontWeight: actif ? FontWeight.w800 : FontWeight.w500,
                        color: actif ? teinte : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: teinte.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "Étape ${_etapes(state).indexOf(etape) + 1}/${_etapes(state).length}",
                  style: TextStyle(color: teinte, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sousEtapes > 1 ? "${_titre(etape)} ($rang/$sousEtapes)" : _titre(etape),
                  style: const TextStyle(color: Colors.black87, fontSize: 16.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AddModifyImmState state) {
    switch (_etapeCourante(state)) {
      case 'location':
        return PropertyLocation(onNext: next, onPrevious: previous);
      case 'details':
        return PropertyDetails(onPrevious: previous, onNext: next);
      case 'features':
        return PropertyFeatures(onPrevious: previous, onNext: next);
      case 'images':
        return PropertyImages(onPrevious: previous, onFinish: onFinish);
      default:
        return BaseInformation(onNext: next);
    }
  }

  String _titre(String etape) {
    switch (etape) {
      case 'base':
        return "Informations de base";
      case 'location':
        return "Localisation";
      case 'details':
        return "Détails de la propriété";
      case 'features':
        return "Équipements et services";
      default:
        return "Photos de la propriété";
    }
  }

  void fetchData() {
    BlocProvider.of<AddModifyImmBloc>(context).add(FetchData());
  }

  void next() {
    final etapes = _etapes(_bloc.state);
    final i = etapes.indexOf(_etapeCourante(_bloc.state));
    if (i >= 0 && i < etapes.length - 1) setState(() => _etape = etapes[i + 1]);
  }

  void previous() {
    final etapes = _etapes(_bloc.state);
    final i = etapes.indexOf(_etapeCourante(_bloc.state));
    if (i <= 0) return;
    setState(() => _etape = etapes[i - 1]);
  }

  void onFinish() {
    if (isUpdate) {
      BlocProvider.of<AddModifyImmBloc>(context).add(UpdateImmobilier());
    } else {
      BlocProvider.of<AddModifyImmBloc>(context).add(AddRealestate());
    }
  }
}
