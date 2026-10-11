import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/caracteristiques_bien.dart';
import 'package:immobilier/models/feature.dart';

import '../../../../../models/realestate.dart';

/// Étape 4 — Équipements.
///
/// Des puces à cocher : l'agent touche ce que le bien possède. Rien n'est
/// obligatoire, mais un bien bien équipé se loue mieux.
class PropertyFeatures extends StatefulWidget {
  final void Function()? onNext;
  final void Function()? onPrevious;
  final void Function()? onBrouillon;

  const PropertyFeatures({super.key, this.onPrevious, this.onNext, this.onBrouillon});

  @override
  State<PropertyFeatures> createState() => _PropertyFeaturesState();
}

class _PropertyFeaturesState extends State<PropertyFeatures> {
  late final AddModifyImmBloc _bloc;
  final _recherche = TextEditingController();

  /// Les familles dépliées. La première s'ouvre d'elle-même.
  final Set<String> _ouvertes = {};
  bool _premiereOuverte = false;

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
    _recherche.dispose();
    super.dispose();
  }

  String? get _codeType => _bloc.state.realestate?.category?.value;

  /// Les équipements proposés : ceux du type choisi, et ceux déjà cochés —
  /// qui doivent rester visibles pour pouvoir être décochés.
  List<Feature> _proposes(List<Feature> tous) => tous
      .where((f) =>
          (f.concerne(_codeType) || (f.isSelected ?? false)) &&
          correspondRecherche(f.name, _recherche.text))
      .toList();

  /// Les familles, dans l'ordre du serveur, avec leurs équipements.
  List<FamilleAffichee> _familles(List<Feature> proposes) {
    final ordre = <String>[];
    final libelles = <String, String>{};
    for (final g in (_bloc.state.formulaire?.groupes ?? const [])) {
      ordre.add(g.code);
      libelles[g.code] = g.libelle;
    }
    if (ordre.isEmpty) {
      ordre.addAll(famillesEquipementsParDefaut.keys);
      libelles.addAll(famillesEquipementsParDefaut);
    }

    final parCode = <String, List<Feature>>{};
    for (final f in proposes) {
      parCode.putIfAbsent(f.groupe ?? 'autres', () => []).add(f);
    }
    for (final liste in parCode.values) {
      liste.sort((a, b) => (a.ordre ?? 999).compareTo(b.ordre ?? 999));
    }

    final familles = <FamilleAffichee>[];
    for (final code in ordre) {
      final liste = parCode.remove(code);
      if (liste == null || liste.isEmpty) continue;
      familles.add(FamilleAffichee(
        code: code,
        libelle: libelles[code] ?? famillesEquipementsParDefaut[code] ?? 'Équipements',
        ids: liste.map((f) => f.id ?? 0).toList(),
      ));
    }
    // Ce qui ne rejoint aucune famille connue ne disparaît pas.
    for (final entree in parCode.entries) {
      if (entree.value.isEmpty) continue;
      familles.add(FamilleAffichee(
        code: entree.key,
        libelle: famillesEquipementsParDefaut[entree.key] ?? 'Autres équipements',
        ids: entree.value.map((f) => f.id ?? 0).toList(),
      ));
    }
    return familles;
  }

  Realestate _instantane() => saveInformation();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        final features = state.features ?? [];
        final retenus = features.where((f) => f.isSelected ?? false).length;
        final proposes = _proposes(features);
        final familles = _familles(proposes);
        if (!_premiereOuverte && familles.isNotEmpty) {
          _premiereOuverte = true;
          _ouvertes.add(familles.first.code);
        }

        return Column(
          children: [
            Expanded(
              child: CorpsEtapeBien(
                enfants: [
                  if (features.isEmpty)
                    const CarteAccueil(
                      padding: EdgeInsets.fromLTRB(16, 28, 16, 28),
                      child: Column(
                        children: [
                          Icon(Icons.featured_play_list_outlined,
                              size: 34, color: texteDouxAccueil),
                          SizedBox(height: 12),
                          Text(
                            'Aucun équipement à proposer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13.5, color: texteDouxAccueil),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        const Expanded(
                          child: LibelleChampBien('Équipements du bien'),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: retenus == 0 ? bordureAccueil : fondPrincipaleBien,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$retenus / ${proposes.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: retenus == 0 ? texteDouxAccueil : principaleBien,
                              fontFeatures: chiffresTabulaires,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Le catalogue en compte plus de soixante : une
                    // recherche, puis une famille a la fois.
                    ChampTexteBien(
                      libelle: 'Rechercher',
                      indication: 'Balcon, ascenseur, piscine...',
                      controller: _recherche,
                      onChange: (_) => setState(() {}),
                      icone: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.search, size: 19, color: texteDouxAccueil),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (familles.isEmpty)
                      CarteAccueil(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off,
                                size: 30, color: texteDouxAccueil),
                            const SizedBox(height: 10),
                            Text(
                              _recherche.text.trim().isEmpty
                                  ? "Aucun équipement pour ce type de bien."
                                  : "Aucun équipement ne correspond à cette recherche.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13.5, color: texteDouxAccueil),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final famille in familles)
                        _famille(famille, features),
                  ],
                ],
              ),
            ),
            BarreActionsBien(
              libelleSuivant: suivantsEtapesBien[3],
              onSuivant: onNextClick,
              onPrecedent: onPreviousClick,
              onBrouillon: widget.onBrouillon,
            ),
          ],
        );
      },
    );
  }

  /// Une famille : son nom, le nombre de cases cochees, et ses puces.
  Widget _famille(FamilleAffichee famille, List<Feature> tous) {
    final dedans = tous.where((f) => famille.ids.contains(f.id)).toList();
    final choisis = dedans.where((f) => f.isSelected ?? false).length;
    // Une recherche en cours ouvre tout : on cherche pour trouver.
    final ouverte = _ouvertes.contains(famille.code) ||
        _recherche.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CarteAccueil(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() {
                if (_ouvertes.contains(famille.code)) {
                  _ouvertes.remove(famille.code);
                } else {
                  _ouvertes.add(famille.code);
                }
              }),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: const BoxDecoration(color: fondFamilleEquipement),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        famille.libelle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: texteAccueil,
                        ),
                      ),
                    ),
                    if (choisis > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: fondPrincipaleBien,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$choisis',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: principaleBien,
                            fontFeatures: chiffresTabulaires,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: ouverte ? .5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more,
                          size: 22, color: texteDouxAccueil),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: !ouverte
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final feature in dedans)
                            PuceEquipementBien(
                              texte: feature.name ?? '',
                              choisi: feature.isSelected ?? false,
                              onTap: () => setState(() {
                                feature.isSelected = !(feature.isSelected ?? false);
                              }),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void onPreviousClick() {
    saveInformation();
    widget.onPrevious?.call();
  }

  void onNextClick() {
    saveInformation();
    widget.onNext?.call();
  }

  void remplirFields() {
    final state = BlocProvider.of<AddModifyImmBloc>(context).state;
    if (state.realestate?.features?.isNotEmpty ?? false) {
      state.features?.forEach((feature) {
        bool isSelected =
            state.realestate?.features?.any((f) => f.id == feature.id) ?? false;
        feature.isSelected = isSelected;
      });
      setState(() {});
    }
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }

  Realestate saveInformation() {
    final features = BlocProvider.of<AddModifyImmBloc>(context).state.features;
    List<Feature> selectedFeatures =
        features?.where((f) => (f.isSelected ?? false)).toList() ?? [];
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(features: selectedFeatures);
    updateRealestate(nr);
    return nr;
  }
}
