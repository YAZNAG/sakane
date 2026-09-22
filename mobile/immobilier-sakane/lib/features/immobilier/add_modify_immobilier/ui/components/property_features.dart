import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/custom_button.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/models/feature.dart';

import '../../../../../models/realestate.dart';
import 'package:immobilier/core/constants/app_colors.dart';
class PropertyFeatures extends StatefulWidget {
  void Function()? onNext;
  void Function()? onPrevious;

  PropertyFeatures({this.onPrevious, this.onNext});

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

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
            /*  Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.featured_play_list,
                      size: 48,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Équipements et services",
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Sélectionnez les équipements disponibles dans la propriété",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),*/

              SizedBox(height: 24),

              // Features selection area
              if (features.isNotEmpty) ...[
                // Selection summary
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "${features.where((f) => f.isSelected ?? false).length} équipement(s) sélectionné(s)",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Features grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    final feature = features[index];
                    final isSelected = feature.isSelected ?? false;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          feature.isSelected = !(feature.isSelected ?? false);
                        });
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.shade50 : Colors.white,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryColor : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Selection indicator
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryColor : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? AppColors.primaryColor : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                      : null,
                                ),
                                SizedBox(width: 8),
                                // Feature name
                                Expanded(
                                  child: Text(
                                    feature.name ?? "",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.blue.shade900 : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            if ((feature.description ?? "").isNotEmpty) ...[
                              SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  feature.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                // No features available
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Aucun équipement disponible",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPreviousClick,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Précédent",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNextClick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Suivant",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        bool isSelected = state.realestate?.features?.any((f) => f.id == feature.id) ?? false;
        feature.isSelected = isSelected;
      });
      setState(() {

      });
    }
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate = BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }

  Realestate saveInformation() {
    final features = BlocProvider.of<AddModifyImmBloc>(context).state.features;
    List<Feature> selectedFeatures = features?.where((f) => (f.isSelected ?? false)).toList() ?? [];
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(features: selectedFeatures);
    updateRealestate(nr);
    return nr;
  }
}