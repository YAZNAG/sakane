import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/features/ventes/ui/components/mandat_outils.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';

import '../../../../../models/category.dart';
import '../../../../../models/owner.dart';
import '../../../../../models/type_transaction.dart';

/// Étape 1 — Informations générales.
///
/// Le titre, la description, la famille du bien, son prix, sa catégorie et
/// son propriétaire : de quoi reconnaître le bien avant de le situer.
class BaseInformation extends StatefulWidget {
  final void Function()? onNext;

  /// Null en modification : un bien déjà créé n'a pas de brouillon.
  final void Function()? onBrouillon;

  const BaseInformation({super.key, this.onNext, this.onBrouillon});

  @override
  State<BaseInformation> createState() => _BaseInformationState();
}

class _BaseInformationState extends State<BaseInformation> {
  static const int _maxDescription = 500;

  final _formKey = GlobalKey<FormState>();
  final _defilement = ScrollController();

  final _titreCle = GlobalKey<FormFieldState<String>>();
  final _descriptionCle = GlobalKey<FormFieldState<String>>();
  final _typeCle = GlobalKey<FormFieldState<TypeTransaction>>();
  final _prixCle = GlobalKey<FormFieldState<String>>();
  final _categorieCle = GlobalKey<FormFieldState<Category>>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _virtualUrlController = TextEditingController();

  late final AddModifyImmBloc _bloc;

  @override
  void initState() {
    super.initState();
    // Le brouillon lit la saisie de l'etape affichee.
    _bloc = BlocProvider.of<AddModifyImmBloc>(context);
    _bloc.instantaneEtape = _instantane;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remplirFields();
    });
  }

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    _defilement.dispose();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _virtualUrlController.dispose();
    super.dispose();
  }

  /// La saisie en cours, sans validation.
  Realestate _instantane() {
    Realestate realestate = getRealEstate();
    realestate.tour360Url =
        _virtualUrlController.text.isNotEmpty ? _virtualUrlController.text : null;
    Realestate nr = realestate.copyWith(
      title: _titleController.text,
      description: _descController.text,
      price: double.tryParse(_priceController.text.trim().replaceAll(',', '.')),
    );
    updateRealestate(nr);
    return nr;
  }

  // ── Libellés qui suivent la famille du bien ──────────────────────

  /// « Prix par nuit » en courte durée, « Loyer mensuel » en longue durée,
  /// « Prix de vente » à la vente.
  String _libellePrix(TypeTransaction? type) {
    switch (type?.value) {
      case 'rent-long':
        return 'Loyer mensuel';
      case 'selle':
        return 'Prix de vente';
      case 'rent-short':
        return 'Prix par nuit';
      default:
        return 'Prix';
    }
  }

  static const Map<String, String> _libellesCourts = {
    'rent-short': 'Courte durée',
    'rent-long': 'Longue durée',
    'selle': 'Vente',
  };

  /// Les trois familles, dans l'ordre de la maquette. Seules celles que le
  /// serveur renvoie sont proposées.
  List<ChoixSegmenteBien<TypeTransaction>> _choixTransaction(
      List<TypeTransaction>? types) {
    final liste = types ?? const <TypeTransaction>[];
    final choix = <ChoixSegmenteBien<TypeTransaction>>[];
    for (final valeur in _libellesCourts.keys) {
      for (final t in liste) {
        if (t.value == valeur) {
          choix.add(ChoixSegmenteBien(t, _libellesCourts[valeur]!));
        }
      }
    }
    // Une famille inconnue garde le nom donné par le serveur.
    for (final t in liste) {
      if (!_libellesCourts.containsKey(t.value)) {
        choix.add(ChoixSegmenteBien(t, t.name ?? '—'));
      }
    }
    return choix;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        final bien = state.realestate;
        final type = bien?.typeTransaction;
        final ecrits = _descController.text.characters.length;

        return Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: CorpsEtapeBien(
                  defilement: _defilement,
                  enfants: [
                    ChampTexteBien(
                      cle: _titreCle,
                      libelle: 'Titre du bien',
                      indication: 'Ex : Appartement vue mer, Founty',
                      controller: _titleController,
                      casse: TextCapitalization.sentences,
                      validateur: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Donnez un titre au bien.';
                        if (t.length < 3) return 'Au moins 3 caractères.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    ChampTexteBien(
                      cle: _descriptionCle,
                      libelle: 'Description',
                      indication: 'Ce qu\'un client doit savoir du bien…',
                      controller: _descController,
                      lignes: 5,
                      maxCaracteres: _maxDescription,
                      casse: TextCapitalization.sentences,
                      onChange: (_) => setState(() {}),
                      mention: '$ecrits / $_maxDescription caractères',
                      validateur: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Décrivez le bien.';
                        if (t.length < 10) return 'Au moins 10 caractères.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    ChampSegmenteBien<TypeTransaction>(
                      cle: _typeCle,
                      libelle: 'Type de transaction',
                      choix: _choixTransaction(state.typeTransaction),
                      valeur: type,
                      onChange: onTypeTransactionChanged,
                      validateur: (_) =>
                          type == null ? 'Choisissez le type de transaction.' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ChampTexteBien(
                            cle: _prixCle,
                            libelle: _libellePrix(type),
                            indication: '0',
                            controller: _priceController,
                            clavier: const TextInputType.numberWithOptions(decimal: true),
                            formats: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            unite: 'MAD',
                            validateur: (v) {
                              final t = (v ?? '').trim().replaceAll(',', '.');
                              if (t.isEmpty) return 'Indiquez un montant.';
                              final montant = double.tryParse(t);
                              if (montant == null) return 'Montant incorrect.';
                              if (montant <= 0) return 'Le montant doit être supérieur à 0.';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChampListeBien<Category>(
                            cle: _categorieCle,
                            libelle: 'Catégorie',
                            indication: 'Choisir',
                            valeur: parmiListeBien(state.categories, bien?.category),
                            choix: (state.categories ?? [])
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name ?? '',
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChange: onCategoryChanged,
                            validateur: (v) => v == null ? 'Choisissez une catégorie.' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _proprietaire(state),
                    const SizedBox(height: 16),

                    ChampTexteBien(
                      libelle: 'Lien de la visite 360° (facultatif)',
                      indication: 'https://…',
                      controller: _virtualUrlController,
                      clavier: TextInputType.url,
                    ),
                  ],
                ),
              ),
              BarreActionsBien(
                libelleSuivant: suivantsEtapesBien[0],
                onSuivant: onSuivantClick,
                onBrouillon: widget.onBrouillon,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Le propriétaire ──────────────────────────────────────────────

  /// La carte du propriétaire retenu, ou l'invitation à le choisir, puis le
  /// lien vers la création d'une nouvelle fiche.
  Widget _proprietaire(AddModifyImmState state) {
    final owner = state.realestate?.owner;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LibelleChampBien('Propriétaire'),
        CarteAccueil(
          padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: fondPrincipaleBien,
                  shape: BoxShape.circle,
                ),
                child: owner == null
                    ? const Icon(Icons.person_outline, size: 20, color: principaleBien)
                    : Text(
                        initialesBien(owner.name),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: principaleBien,
                        ),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      owner?.name?.trim().isNotEmpty == true
                          ? owner!.name!
                          : 'Aucun propriétaire',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: texteAccueil,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owner == null
                          ? 'Facultatif — vous pourrez l\'ajouter plus tard.'
                          : (telephoneMasqueBien(owner.tel).isEmpty
                              ? 'Téléphone non renseigné'
                              : telephoneMasqueBien(owner.tel)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: texteDouxAccueil,
                        fontFeatures: chiffresTabulaires,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChangerProprietaire,
                style: TextButton.styleFrom(
                  foregroundColor: principaleBien,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  owner == null ? 'Choisir' : 'Changer',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAddOwner,
            icon: const Icon(Icons.add, size: 17),
            label: const Text(
              'Nouveau propriétaire',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: principaleBien,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        ),
      ],
    );
  }

  /// Ouvre la liste des propriétaires déjà enregistrés. Rien n'est changé
  /// si l'agent referme la feuille sans choisir.
  Future<void> onChangerProprietaire() async {
    final owner = await choisirProprietaire(context);
    if (owner == null || !mounted) return;
    BlocProvider.of<AddModifyImmBloc>(context).add(AddOwner(owner));
  }

  void onAddOwner() async {
    var result = await GoRouter.of(context).push(Routes.addOwner);
    if (result is Owner && mounted) {
      BlocProvider.of<AddModifyImmBloc>(context).add(AddOwner(result));
    }
  }

  // ── Passage à l'étape suivante ───────────────────────────────────

  void onSuivantClick() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      allerAuPremierFautifBien([
        _titreCle,
        _descriptionCle,
        _typeCle,
        _prixCle,
        _categorieCle,
      ]);
      return;
    }
    Realestate realestate = getRealEstate();
    realestate.tour360Url =
        _virtualUrlController.text.isNotEmpty ? _virtualUrlController.text : null;
    Realestate nr = realestate.copyWith(
      title: _titleController.text,
      description: _descController.text,
      price: double.tryParse(_priceController.text.trim().replaceAll(',', '.')),
    );
    updateRealestate(nr);
    widget.onNext?.call();
  }

  void remplirFields() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
    if (realestate != null) {
      _titleController.text = realestate.title ?? "";
      _descController.text = realestate.description ?? "";
      _priceController.text = realestate.price?.toString() ?? "";
      _virtualUrlController.text = realestate.tour360Url ?? "";
      setState(() {});
    }
  }

  void onCategoryChanged(Category? value) {
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(category: value);
    updateRealestate(nr);
  }

  void onTypeTransactionChanged(TypeTransaction? value) {
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(typeTransaction: value);
    updateRealestate(nr);
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }
}
