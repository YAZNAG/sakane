import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/immobilier/rapports/rapports_list/cubit/rapport_cubit.dart';
import 'package:immobilier/models/rapport.dart';

import '../../../../../routes.dart';

class RapportListPage extends StatefulWidget {
  const RapportListPage({Key? key}) : super(key: key);

  static Widget page(int id) {
    return BlocProvider<RapportCubit>(
      create: (ctx) => RapportCubit(id)..fetchData(),
      child: RapportListPage(),
    );
  }

  @override
  State<RapportListPage> createState() => _RapportListPageState();
}

class _RapportListPageState extends State<RapportListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Rapports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocBuilder<RapportCubit, RapportState>(
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
      floatingActionButton: !peut(AppPermission.createReport) ? null : FloatingActionButton(
        onPressed:_onAddRapport,
        backgroundColor: AppColors.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),

      ),
    );
  }

  Widget _buildContent(RapportState state) {
    if (state.fetchDataStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return Center(
        child: MyErrorWidget(
          error: state.error ?? "Erreur",
          action: AppStrings.tryAgain,
          actionCLick: () {
            context.read<RapportCubit>().fetchData();
          },
        ),
      );
    } else if (state.fetchDataStatus == AppStatus.success) {
      if (state.rapports == null || state.rapports!.isEmpty) {
        return _buildEmptyState();
      }
      return RefreshIndicator(
        onRefresh: () async {
          context.read<RapportCubit>().fetchData();
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.rapports!.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildRapportCard(state.rapports![index]);
          },
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildRapportCard(Rapport rapport) {
    final imageCount = rapport.images?.length ?? 0;
    final hasImages = imageCount > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description,
                    color: Colors.indigo.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rapport.name ?? "Sans titre",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rapport.date?.formattedDateFr ?? "-",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (rapport.description != null &&
                    rapport.description!.isNotEmpty) ...[
                  Text(
                    "Description",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rapport.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],

                // Images Preview Section
                if (hasImages) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$imageCount image${imageCount > 1 ? 's' : ''}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageCount > 4 ? 4 : imageCount,
                      separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 3 && imageCount > 4) {
                          return _buildMoreImagesOverlay(rapport,imageCount - 3);
                        }
                        return _buildImageThumbnail(
                          rapport,
                          index
                        );
                      },
                    ),
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Aucune image",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
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

  Widget _buildImageThumbnail(Rapport rapport,int index) {
    String url=rapport.images!.elementAt(index).url!;
    return GestureDetector(
      onTap: (){
        Navigator.push(context,
            MaterialPageRoute(builder: (ctx)=>ImagesGalery(medias: rapport.images!,index: index,))
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.grey.shade500,
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMoreImagesOverlay(Rapport rapport,int remainingCount) {
    return InkWell(
      onTap: (){
        Navigator.push(context,
            MaterialPageRoute(builder: (ctx)=>ImagesGalery(medias: rapport.images!,))
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "+$remainingCount",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 60,
              color: Colors.indigo.shade300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun rapport",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Commencez par créer votre premier rapport",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),

        ],
      ),
    );
  }

  void _onAddRapport() async{
    final state=context.read<RapportCubit>().state;
    int id=state.id!;
    await GoRouter.of(context).push(Routes.addRapport.replaceFirst(":id", id.toString()));
    context.read<RapportCubit>().fetchData();
  }
}