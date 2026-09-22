import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/cubit/immobilier_detail_cubit.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/routes.dart';


class ImmobilierDetailPage extends StatefulWidget {
  int id;
  ImmobilierDetailPage({required this.id});

  static Widget page(int id) {
    return BlocProvider<ImmobilierDetailCubit>(
      create: (context) => ImmobilierDetailCubit(id)..fetchData(),
      child: ImmobilierDetailPage(id: id),
    );
  }

  @override
  State<ImmobilierDetailPage> createState() => _ImmobilierDetailPageState();
}

class _ImmobilierDetailPageState extends State<ImmobilierDetailPage> {
  PageController _imageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ImmobilierDetailCubit, ImmobilierDetailState>(
      builder: (context, state) {
        // Le bouton de partage vit dans la barre de titre : il lui faut
        // donc la fiche chargée, d'où le bloc qui enveloppe le Scaffold.
        final bien = state.realestate;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              "Détails du Bien",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            actions: [
              if (peut(AppPermission.viewCalendar))
              IconButton(
                onPressed: () => GoRouter.of(context).push(Uri(
                  path: Routes.calendrierBien.replaceAll(":id", widget.id.toString()),
                  queryParameters: (bien?.title ?? '').isEmpty ? null : {'titre': bien!.title!},
                ).toString()),
                icon: Icon(Icons.calendar_month_outlined, color: Colors.white),
                tooltip: "Calendrier",
              ),
              if (bien != null && peut(AppPermission.shareProperty))
                IconButton(
                  onPressed: () => PartageBien.partager(context, bien),
                  icon: Icon(Icons.share, color: Colors.white),
                  tooltip: "Partager la fiche",
                ),
              if (bien != null && peutChangerActivationBien(bien.estDesactive))
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (choix) => choix == 'reactiver' ? _reactiver(bien) : _desactiver(bien),
                  itemBuilder: (_) => [
                    if (bien.estDesactive)
                      PopupMenuItem(
                        value: 'reactiver',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.restore, color: Colors.green.shade700),
                          title: Text("Réactiver le bien"),
                        ),
                      )
                    else
                      PopupMenuItem(
                        value: 'desactiver',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.visibility_off_outlined, color: couleurDesactivation),
                          title: Text("Désactiver le bien"),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          body: _buildContent(state),
        );
      },
    );
  }

  Widget _buildContent(ImmobilierDetailState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(
        child: MyLoadingIndicator(),
      );
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: fetchData,
      );
    }

    if (state.fetchStatus == AppStatus.success && state.realestate != null) {
      Realestate realestate = state.realestate!;
      return _buildSuccessContent(realestate);
    }

    return SizedBox();
  }

  Widget _buildSuccessContent(Realestate realestate) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (realestate.estDesactive) BandeauBienDesactive(desactiveLe: realestate.desactiveLe!),

          // Image Gallery
          _buildImageGallery(realestate),

          // Property Info
          _buildPropertyInfo(realestate),

          // Price and Status
          _buildPriceAndStatus(realestate),

          // Property Details
          _buildPropertyDetails(realestate),

          // Features
          _buildFeatures(realestate),

          // Location
          _buildLocation(realestate),

          // Owner Information
          if (realestate.owner != null) _buildOwnerInfo(realestate),

          // Desactivation : action visible en bas de la fiche (pas seulement dans le menu ⋮)
          if (peutChangerActivationBien(realestate.estDesactive))
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: BoutonDesactivationBien(
                desactive: realestate.estDesactive,
                onDesactiver: () => _desactiver(realestate),
                onReactiver: () => _reactiver(realestate),
              ),
            ),

          // 360 Tour

        ],
      ),
    );
  }

  Widget _buildImageGallery(Realestate realestate) {
    final images = realestate.media ?? [];

    if (images.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade400),
              SizedBox(height: 8),
              Text(
                "Aucune image disponible",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 250,
      child: Stack(
        children: [
          PageView.builder(
            controller: _imageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                // ouvre la galerie plein ecran, navigation entre toutes les photos
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImagesGalery(medias: images, index: index),
                  ),
                ),
                child: Image.network(
                images[index].url!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
                    ),
                  );
                },
                ),
              );
            },
          ),

          // Image indicators
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                      (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentImageIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),

          // Image counter
          if (images.length > 1)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  "${_currentImageIndex + 1}/${images.length}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyInfo(Realestate realestate) {
    return Container(
      padding: EdgeInsets.all(16),
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            realestate.title ?? "Propriété sans titre",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          if (realestate.description != null && realestate.description!.isNotEmpty)
            Text(
              realestate.description!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceAndStatus(Realestate realestate) {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Prix",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "${realestate.price?.toStringAsFixed(0) ?? "Non spécifié"} MAD",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (realestate.status != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(int.parse('0xFF${realestate.status!.color}')).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(int.parse('0xFF${realestate.status!.color}')),
                ),
              ),
              child: Text(
                realestate.status!.name!,
                style: TextStyle(
                  color: Color(int.parse('0xFF${realestate.status!.color}')),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyDetails(Realestate realestate) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Caractéristiques",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          _buildDetailGrid([
            _DetailItem("Surface", "${realestate.surface ?? "N/A"} m²", Icons.square_foot),
            _DetailItem("Chambres", "${realestate.nbRooms ?? "N/A"}", Icons.bed),
            _DetailItem("Salles de bain", "${realestate.nbBathroom ?? "N/A"}", Icons.bathtub),
            _DetailItem("Étages", "${realestate.nbEtages ?? "N/A"}", Icons.layers),
            _DetailItem("Étage", "${realestate.etage ?? "N/A"}", Icons.elevator),
            _DetailItem("Catégorie", realestate.category?.name ?? "N/A", Icons.category),
            _DetailItem("Type", realestate.typeTransaction?.name ?? "N/A", Icons.business),
            _DetailItem("État", realestate.etat?.name ?? "N/A", Icons.construction),
          ]),
          if (realestate.dateConstruction != null) ...[
            SizedBox(height: 16),
            _buildDetailRow(
              "Date de construction",
              "${realestate.dateConstruction?.formattedDateFr}",
              Icons.calendar_today,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailGrid(List<_DetailItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: AppColors.primaryColor),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      item.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryColor),
        SizedBox(width: 12),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(Realestate realestate) {
    if (realestate.features == null || realestate.features!.isEmpty) {
      return SizedBox();
    }

    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Équipements",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: realestate.features!.map((feature) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  feature.name!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation(Realestate realestate) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Localisation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          if (realestate.address != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.red.shade600, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (realestate.address!.address != null)
                        Text(
                          realestate.address!.address!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (realestate.address!.city != null) ...[
                        SizedBox(height: 4),
                        Text(
                          "${realestate.address!.city!.name}, ${realestate.address!.region?.name ?? ""}, ${realestate.address!.region!.country?.name ?? ""}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (realestate.location != null) ...[
              SizedBox(height: 12),
              Text(
                "Coordonnées: ${realestate.location!.latitude?.toStringAsFixed(6)}, ${realestate.location!.longitude?.toStringAsFixed(6)}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOwnerInfo(Realestate realestate) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Propriétaire",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.person, color: AppColors.primaryColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      realestate.owner!.name ?? "Propriétaire",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (realestate.owner!.email != null)
                      Text(
                        realestate.owner!.tel!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
             /* IconButton(
                onPressed: () {
                  // Contact owner functionality
                },
                icon: Icon(Icons.chat_bubble_outline, color: AppColors.primaryColor),
              ),*/
            ],
          ),
        ],
      ),
    );
  }

  Widget _build360Tour(Realestate realestate) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Visite Virtuelle",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
         /* ElevatedButton(
            onPressed: () async {
              if (await canLaunch(realestate.tour360Url!)) {
                await launch(realestate.tour360Url!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  "Voir en 360°",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),*/
        ],
      ),
    );
  }

  void fetchData() {
    BlocProvider.of<ImmobilierDetailCubit>(context).fetchData();
  }

  Future<void> _desactiver(Realestate bien) async {
    final ok = await desactiverBienAvecDialogue(context, bien.id ?? widget.id);
    if (!ok || !mounted) return;
    // Signal de rafraichissement pour les listes appelantes
    if (GoRouter.of(context).canPop()) {
      GoRouter.of(context).pop(true);
    } else {
      fetchData();
    }
  }

  Future<void> _reactiver(Realestate bien) async {
    final reactive = await reactiverBienAvecDialogue(context, bien.id ?? widget.id, titre: bien.title);
    if (reactive != null && mounted) fetchData();
  }
}

class _DetailItem {
  final String label;
  final String value;
  final IconData icon;

  _DetailItem(this.label, this.value, this.icon);
}