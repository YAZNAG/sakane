import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/caracteristiques_bien.dart';
import 'package:immobilier/models/formulaire_bien.dart';
import '../../../../../models/etat.dart';
import '../../../../../models/realestate.dart';
import '../../bloc/add_modify_imm_bloc.dart';

/// Étape 3 — Détails.
///
/// La surface, l'état, les pièces, les étages et l'année de construction :
/// ce qu'un client demande avant de venir voir.
class PropertyDetails extends StatefulWidget {
  final void Function()? onNext;
  final void Function()? onPrevious;
  final void Function()? onBrouillon;

  const PropertyDetails({super.key, this.onPrevious, this.onNext, this.onBrouillon});

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  final _formKey = GlobalKey<FormState>();
  final _defilement = ScrollController();

  final _surfaceCle = GlobalKey<FormFieldState<String>>();
  final _etatCle = GlobalKey<FormFieldState<Etat>>();
  final _chambresCle = GlobalKey<FormFieldState<String>>();
  final _bainsCle = GlobalKey<FormFieldState<String>>();
  final _etagesCle = GlobalKey<FormFieldState<String>>();
  final _etageCle = GlobalKey<FormFieldState<String>>();

  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _nbEtagesController = TextEditingController();
  final _surfaceController = TextEditingController();
  final _constructionDateController = TextEditingController();
  final _etageController = TextEditingController();
  late final AddModifyImmBloc _bloc;

  /// Ce qui ne se demande qu'à ce type de bien : salons, titre foncier,
  /// façade... Le serveur dit quels champs poser pour le type choisi.
  Map<String, dynamic> _caracteristiques = {};

  /// Les champs chiffrés n'acceptent que des chiffres.
  static final List<TextInputFormatter> _chiffres = [
    FilteringTextInputFormatter.digitsOnly,
  ];

  @override
  void initState() {
    super.initState();
    // Le brouillon lit la saisie de l'etape affichee.
    _bloc = BlocProvider.of<AddModifyImmBloc>(context);
    _bloc.instantaneEtape = _instantane;
    _caracteristiques = {...(_bloc.state.realestate?.caracteristiques ?? {})};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remplirFields();
    });
  }

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    _defilement.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _nbEtagesController.dispose();
    _surfaceController.dispose();
    _constructionDateController.dispose();
    _etageController.dispose();
    super.dispose();
  }

  /// Sans validation : un nombre mal saisi est simplement ignore.
  Realestate _instantane() {
    int? entier(TextEditingController c) => int.tryParse(c.text.trim());
    final realestate = getRealEstate();
    realestate.nbBathroom = entier(_bathroomsController);
    realestate.nbEtages = entier(_nbEtagesController);
    realestate.nbRooms = entier(_roomsController);
    realestate.surface = entier(_surfaceController) ??
        num.tryParse(_surfaceController.text.trim().replaceAll(',', '.'));
    realestate.etage = entier(_etageController);
    realestate.caracteristiques = {..._caracteristiques};
    final nr = realestate.copyWith();
    updateRealestate(nr);
    return nr;
  }

  String? get _codeType => _bloc.state.realestate?.category?.value;

  FormulaireBien? get _formulaire => _bloc.state.formulaire;

  /// Sans catalogue — serveur ancien, réseau coupé au chargement — tous
  /// les champs restent proposés : mieux vaut un champ de trop qu'un
  /// champ manquant.
  List<String> get _communs =>
      _formulaire?.communsPour(_codeType) ?? FormulaireBien.tousLesCommuns;

  bool _demande(String champ) => _communs.contains(champ);

  bool get _espaces => _demande('chambres') || _demande('salles_bain');

  bool get _etagesDemandes => _demande('etages') || _demande('etage');

  List<ChampCaracteristique> get _champsDuType =>
      _formulaire?.champsPour(_codeType) ?? const [];

  String get _nomDuType {
    final code = _codeType;
    if (code == null) return '';
    for (final t in _formulaire?.types ?? const <TypeBienFormulaire>[]) {
      if (t.code == code) return t.nom;
    }
    return '';
  }

  /// « 3 » ou rien : un nombre entier, jamais négatif.
  String? _entierFacultatif(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null) return 'Entrez un nombre entier.';
    if (n < 0) return 'Nombre incorrect.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: CorpsEtapeBien(
                  defilement: _defilement,
                  enfants: [
                    const TitreGroupeBien('Caractéristiques générales'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ChampTexteBien(
                            cle: _surfaceCle,
                            libelle: 'Surface',
                            indication: '0',
                            controller: _surfaceController,
                            clavier: TextInputType.number,
                            formats: _chiffres,
                            unite: 'm²',
                            validateur: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return 'Indiquez la surface.';
                              final n = int.tryParse(t);
                              if (n == null) return 'Entrez un nombre entier.';
                              if (n <= 0) return 'La surface doit être supérieure à 0.';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChampListeBien<Etat>(
                            cle: _etatCle,
                            libelle: 'État',
                            indication: 'Choisir',
                            valeur: parmiListeBien(state.etats, state.realestate?.etat),
                            choix: (state.etats ?? [])
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e.name ?? '',
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChange: onEtatChanged,
                            validateur: (v) => v == null ? "Choisissez l'état du bien." : null,
                          ),
                        ),
                      ],
                    ),
                    if (_demande('date_construction')) const SizedBox(height: 16),
                    if (_demande('date_construction')) ChampTexteBien(
                      libelle: 'Date de construction',
                      indication: 'Choisir une date',
                      controller: _constructionDateController,
                      lectureSeule: true,
                      onTap: _pickDate,
                      // L'icône aussi ouvre le calendrier : le champ est en
                      // lecture seule, on ne tape que dessus.
                      icone: GestureDetector(
                        onTap: _pickDate,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.calendar_month_outlined,
                              size: 19, color: texteDouxAccueil),
                        ),
                      ),
                    ),
                    // Un terrain n'a ni chambre ni salle de bain ; un local
                    // n'a pas de chambres mais bien un étage. Le serveur
                    // dit, pour chaque type, ce qui a un sens.
                    if (_espaces) ...[
                      const SizedBox(height: 24),
                      const TitreGroupeBien('Distribution des espaces'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_demande('chambres'))
                            Expanded(
                              child: ChampTexteBien(
                                cle: _chambresCle,
                                libelle: 'Chambres',
                                indication: '0',
                                controller: _roomsController,
                                clavier: TextInputType.number,
                                formats: _chiffres,
                                validateur: _entierFacultatif,
                              ),
                            ),
                          if (_demande('chambres') && _demande('salles_bain'))
                            const SizedBox(width: 12),
                          if (_demande('salles_bain'))
                            Expanded(
                              child: ChampTexteBien(
                                cle: _bainsCle,
                                libelle: 'Salles de bain',
                                indication: '0',
                                controller: _bathroomsController,
                                clavier: TextInputType.number,
                                formats: _chiffres,
                                validateur: _entierFacultatif,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (_etagesDemandes) ...[
                      const SizedBox(height: 24),
                      const TitreGroupeBien('Étages'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_demande('etages'))
                            Expanded(
                              child: ChampTexteBien(
                                cle: _etagesCle,
                                libelle: "Nombre d'étages",
                                indication: '0',
                                controller: _nbEtagesController,
                                clavier: TextInputType.number,
                                formats: _chiffres,
                                validateur: _entierFacultatif,
                              ),
                            ),
                          if (_demande('etages') && _demande('etage'))
                            const SizedBox(width: 12),
                          if (_demande('etage'))
                            Expanded(
                              child: ChampTexteBien(
                                cle: _etageCle,
                                libelle: 'Étage du bien',
                                indication: '0',
                                controller: _etageController,
                                clavier: TextInputType.number,
                                formats: _chiffres,
                                validateur: _entierFacultatif,
                              ),
                            ),
                        ],
                      ),
                    ],
                    // Ce qui n'appartient qu'à ce type de bien.
                    if (_champsDuType.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      TitreGroupeBien(titreCaracteristiques(_nomDuType)),
                      ChampsCaracteristiques(
                        champs: _champsDuType,
                        valeurs: _caracteristiques,
                        onChange: (valeurs) => _caracteristiques = valeurs,
                      ),
                    ],
                  ],
                ),
              ),
              BarreActionsBien(
                libelleSuivant: suivantsEtapesBien[2],
                onSuivant: onNextClick,
                onPrecedent: onPreviousClick,
                onBrouillon: widget.onBrouillon,
              ),
            ],
          ),
        );
      },
    );
  }

  void onNextClick() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      allerAuPremierFautifBien([
        _surfaceCle,
        _etatCle,
        _chambresCle,
        _bainsCle,
        _etagesCle,
        _etageCle,
      ]);
      return;
    }
    saveInformation();
    widget.onNext?.call();
  }

  /// Le retour ne bloque pas sur une erreur : la saisie est gardée telle
  /// qu'elle est, et l'agent revient la corriger.
  void onPreviousClick() {
    _instantane();
    widget.onPrevious?.call();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate:
            BlocProvider.of<AddModifyImmBloc>(context).state.realestate?.dateConstruction ??
                DateTime(2015),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        initialEntryMode: DatePickerEntryMode.calendarOnly);

    if (picked != null && mounted) {
      Realestate realestate = getRealEstate();
      Realestate nr = realestate.copyWith(dateConstruction: picked);
      updateRealestate(nr);
      setState(() {
        _constructionDateController.text = picked.formattedDateFr;
      });
    }
  }

  void onEtatChanged(Etat? value) {
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(etat: value);
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

  void remplirFields() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate;
    if (realestate != null) {
      _surfaceController.text = realestate.surface?.toString() ?? "";
      _bathroomsController.text = realestate.nbBathroom?.toString() ?? "";
      _nbEtagesController.text = realestate.nbEtages?.toString() ?? "";
      _roomsController.text = realestate.nbRooms?.toString() ?? "";
      _constructionDateController.text =
          realestate.dateConstruction?.formattedDateFr ?? "";
      _etageController.text = realestate.etage?.toString() ?? "";
      _caracteristiques = {...(realestate.caracteristiques ?? {})};
      setState(() {});
    }
  }

  void saveInformation() {
    Realestate realestate = getRealEstate();
    int? entier(TextEditingController c) =>
        c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
    // Un champ que le type ne demande pas ne garde pas une ancienne
    // valeur : elle se lirait plus tard sur la fiche sans avoir de sens.
    realestate.nbBathroom = _demande('salles_bain') ? entier(_bathroomsController) : null;
    realestate.nbEtages = _demande('etages') ? entier(_nbEtagesController) : null;
    realestate.nbRooms = _demande('chambres') ? entier(_roomsController) : null;
    realestate.surface = entier(_surfaceController);
    realestate.etage = _demande('etage') ? entier(_etageController) : null;
    realestate.caracteristiques = {..._caracteristiques};

    updateRealestate(realestate.copyWith());
  }
}
