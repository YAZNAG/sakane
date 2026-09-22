import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_string.dart';
import 'package:immobilier/features/platform/announces/cubit/announce_cubit.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/models/media.dart';


class AnnouncesScreen extends StatefulWidget {
  AnnouncesScreen({Key? key}) : super(key: key);

  static Widget page() {
    return BlocProvider<AnnounceCubit>(
      create: (context) => AnnounceCubit()..fetchData(),
      child: AnnouncesScreen(),
    );
  }

  @override
  State<AnnouncesScreen> createState() => _AnnouncesScreenState();
}

class _AnnouncesScreenState extends State<AnnouncesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Gestion des Annonces",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AnnounceCubit, AnnounceState>(
        listener: (context, state) {
          if (state.actionStatus == AppStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Action effectuée avec succès'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state.actionStatus == AppStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error ?? 'Erreur'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(AnnounceState state) {
    if (state.fetchDataStatus == AppStatus.loading) {
      return  Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Erreur",
          action: AppStrings.tryAgain,
          actionCLick: () {
            context.read<AnnounceCubit>().fetchData();
          },
        ),
      );
    } else if (state.fetchDataStatus == AppStatus.success) {
      if (state.annouces == null || state.annouces!.isEmpty) {
        return _buildEmptyState();
      }
      return _buildAnnouncesList(state);
    }
    return const SizedBox();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.announcement_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "Aucune annonce en attente",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Les nouvelles annonces apparaîtront ici",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncesList(AnnounceState state) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            context.read<AnnounceCubit>().fetchData();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.annouces!.length,
            itemBuilder: (context, index) {
              return _buildAnnounceCard(state.annouces![index], state);
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
                      Text('Traitement en cours...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAnnounceCard(Realestate announce, AnnounceState state) {
    String? imageUrl = announce.media?.isNotEmpty == true
        ? announce.media!.first.url
        : null;
    Color statusColor =
        announce.status?.color?.toColor ?? Colors.grey.shade400;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: imageUrl != null
                ? GestureDetector(
                    // ouvre la photo en plein ecran, avec zoom
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ImagesGalery(medias: [Media(url: imageUrl)]),
                      ),
                    ),
                    child: Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildImagePlaceholder(),
            ),
                  )
                : _buildImagePlaceholder(),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announce.title ?? "Sans titre",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        announce.status?.name ?? "En attente",
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Property Info
                _buildInfoRow(
                  Icons.category_outlined,
                  announce.category?.name ?? "-",
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  announce.address?.city?.name ?? "-",
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.square_foot_outlined,
                  "${announce.surface ?? 0} m²",
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.attach_money,
                  "${announce.price ?? 0} MAD",
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    // Details Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          GoRouter.of(context).push(
                            Routes.immobilierDetails.replaceAll(
                              ":id",
                              announce.id.toString(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text("Détails"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Refuse Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.actionStatus == AppStatus.loading || !peut(AppPermission.cancelAnnounce)
                            ? null
                            : () => _showRefuseDialog(announce.id!),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("Refuser"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Accept Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.actionStatus == AppStatus.loading || !peut(AppPermission.activateAnnounce)
                            ? null
                            : () => _showAcceptDialog(announce.id!),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Accepter"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            "Aucune image",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  void _showAcceptDialog(int announceId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Accepter l'annonce"),
          content: const Text(
            "Êtes-vous sûr de vouloir accepter cette annonce ? Elle sera publiée sur la plateforme.",
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
                context.read<AnnounceCubit>().acceptAnnounce(announceId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text("Accepter"),
            ),
          ],
        );
      },
    );
  }

  void _showRefuseDialog(int announceId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Refuser l'annonce"),
          content: const Text(
            "Êtes-vous sûr de vouloir refuser cette annonce ? L'hôte en sera notifié.",
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
                context.read<AnnounceCubit>().refuseAnnounce(announceId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text("Refuser"),
            ),
          ],
        );
      },
    );
  }
}