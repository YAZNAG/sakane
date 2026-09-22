import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/platform/sliders/cubit/slider_cubit.dart';
import 'package:immobilier/models/slider.dart';
import 'package:toastification/toastification.dart';

import '../../../../core/utils/show_error_dialogue.dart';
import '../../../../routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';


class SlidersScreen extends StatefulWidget {
  SlidersScreen({Key? key}) : super(key: key);

  static Widget page() {
    return BlocProvider<SliderCubit>(
      create: (ctx) => SliderCubit()..fetchData(),
      child: SlidersScreen(),
    );
  }

  @override
  State<SlidersScreen> createState() => _SlidersScreenState();
}

class _SlidersScreenState extends State<SlidersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Gestion des Sliders",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<SliderCubit, SliderState>(
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Slider activé avec succès'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state.actionStatus == AppStatus.error) {
            if(state.errors!=null){
              showDialogueError(context, state.errors!);
            }else{
              showToast("",
                  context,
                  description: state.error??AppStrings.error,
                  type: ToastificationType.error);
            }
          }
        },
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
      floatingActionButton: !peut(AppPermission.createSlider) ? null : FloatingActionButton(
          onPressed: onAddSlider,
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add,color: Colors.white,),
      ),
    );
  }

  Widget _buildContent(SliderState state) {
    if (state.fetchDataStatus == AppStatus.loading) {
      return  Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Erreur",
          action: AppStrings.tryAgain,
          actionCLick: () {
            context.read<SliderCubit>().fetchData();
          },
        ),
      );
    } else if (state.fetchDataStatus == AppStatus.success) {
      if (state.sliders == null || state.sliders!.isEmpty) {
        return _buildEmptyState();
      }
      return _buildSlidersList(state);
    }
    return const SizedBox();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun slider disponible",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Créez un nouveau slider pour commencer",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersList(SliderState state) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            context.read<SliderCubit>().fetchData();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.sliders!.length,
            itemBuilder: (context, index) {
              return _buildSliderCard(state.sliders![index], state);
            },
          ),
        ),
        if (state.actionStatus == AppStatus.loading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child:  Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MyLoadingIndicator(),
                      SizedBox(height: 16),
                      Text('Activation en cours...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSliderCard(SliderModel slider, SliderState state) {
    bool isActive = slider.isActive ?? false;
    int imageCount = slider.images?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: AppColors.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            slider.name ?? "Sans nom",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Actif",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (slider.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          slider.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: AppColors.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$imageCount",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Images Preview Section
          if (imageCount > 0)
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: imageCount,
                itemBuilder: (context, index) {
                  return _buildImagePreview(
                    slider.images![index].url ?? "",
                    index,
                  );
                },
              ),
            )
          else
            Container(
              height: 120,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Aucune image",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Info Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ID: ${slider.id}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActive
                              ? "Affiché sur le site web"
                              : "Non affiché",
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Activate Button
                if (!isActive && peut(AppPermission.activateSlider))
                  ElevatedButton.icon(
                    onPressed: state.actionStatus == AppStatus.loading
                        ? null
                        : () => _showActivateDialog(slider.id!),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text("Activer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade600),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility,
                          color: Colors.green.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "En ligne",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String imageUrl, int index) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 160,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 160,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.grey.shade500,
                    size: 40,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${index + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActivateDialog(int sliderId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Activer le slider"),
          content: const Text(
            "Êtes-vous sûr de vouloir activer ce slider ? Le slider actuellement actif sera désactivé automatiquement.",
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SliderCubit>().activateSlider(sliderId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text("Activer"),
            ),
          ],
        );
      },
    );
  }

  void onAddSlider() async{
   await  GoRouter.of(context).push(Routes.addSlider);
   BlocProvider.of<SliderCubit>(context).fetchData();
  }
}