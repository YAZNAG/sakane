import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
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
    super.dispose();
  }

  Realestate _instantane() => saveInformation();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        final features = state.features ?? [];
        final retenus = features.where((f) => f.isSelected ?? false).length;

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
                            '$retenus / ${features.length}',
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final feature in features)
                          PuceEquipementBien(
                            texte: feature.name ?? '',
                            choisi: feature.isSelected ?? false,
                            onTap: () => setState(() {
                              feature.isSelected = !(feature.isSelected ?? false);
                            }),
                          ),
                      ],
                    ),
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
