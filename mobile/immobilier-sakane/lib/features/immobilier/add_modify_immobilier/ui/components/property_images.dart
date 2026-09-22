import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/empty_widget.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../../../components/custom_button.dart';

class PropertyImages extends StatefulWidget {
  void Function()? onFinish;
  void Function()? onPrevious;

  PropertyImages({this.onPrevious, this.onFinish});

  @override
  State<PropertyImages> createState() => _PropertyImagesState();
}

class _PropertyImagesState extends State<PropertyImages> {
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
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

  Realestate _instantane() => updateImages();

  @override
  Widget build(BuildContext context) {
    bool isUpdate =
        BlocProvider
            .of<AddModifyImmBloc>(context)
            .state
            .realestateId != null;
    Realestate realestate = getRealEstate();
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section
                    Container(
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
                            Icons.photo_library,
                            size: 48,
                            color: AppColors.primaryColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Photos de la propriété",
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Ajoutez minimum 2 photos ",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Images counter and info
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
                            Icons.image,
                            size: 20,
                            color: Colors.grey.shade700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "${getTotalImages()} photos sélectionnées",
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Spacer(),
                          if (getTotalImages() >= 2 )
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Valide",
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )

                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Images grid
                    if (getTotalImages() > 0 ) ...[
                      Container(
                        height: 300,
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: getTotalImages() +1,
                          itemBuilder: (context, index) {
                            // Check if this is the add button
                            if (index >= getTotalImages() ) {
                              return GestureDetector(
                                onTap: () => _pickImages(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 32,
                                        color: Colors.grey.shade600,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Ajouter",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Show existing images
                            final remoteImagesCount = realestate.media
                                ?.length ?? 0;
                            if (index < remoteImagesCount) {
                              // Remote image
                              return imageWidget(
                                "remote",
                                media: realestate.media!.elementAt(index),
                              );
                            } else {
                              // Local image
                              return imageWidget(
                                "local",
                                file: _images.elementAt(
                                    index - remoteImagesCount),
                              );
                            }
                          },
                        ),
                      ),
                    ] else
                      ...[
                        // No images state
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Aucune photo ajoutée",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _pickImages,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "Ajouter des photos",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),

            // Fixed bottom buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
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
                      onPressed: state.addModifyStatus == AppStatus.loading
                          ? null
                          : onFinishClick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: state.addModifyStatus == AppStatus.loading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                          : Text(
                        isUpdate ? "Modifier" : "Ajouter",
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
            ),
          ],
        );
      },
    );
  }

  Widget imageWidget(String type, {File? file, Media? media}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: type == "local"
              ? Image.file(File(file!.path), fit: BoxFit.cover)
              : Image.network(
            media!.url!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey.shade400,
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () {
              if (type == "local") {
                _removeImageLocal(file!);
              } else {
                _removeImageRemote(media!);
              }
            },
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {



    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      final newImages = pickedFiles.map((e) => File(e.path)).toList();
        _images.addAll(newImages);
      setState(() {});
    }
  }

  int getTotalImages() {
    Realestate realestate = getRealEstate();
    return ((realestate.media?.length ?? 0) + _images.length);
  }

  void _removeImageLocal(File file) {
    setState(() {
      _images.remove(file);
    });
  }

  void _removeImageRemote(Media media) {
    Realestate realestate = getRealEstate();
    List<int> trashIMages = realestate.trashImages ?? [];
    List<Media> newMedia =
        realestate.media?.where((m) => m.id != media.id).toList() ?? [];
    Realestate nr = realestate.copyWith(
      trashImages: [...trashIMages, media.id!],
      media: newMedia,
    );
    updateRealestate(nr);
  }

  Realestate updateImages() {
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(files: _images);
    updateRealestate(nr);
    return nr;
  }

  void onPreviousClick() {
    updateImages();
    widget.onPrevious?.call();
  }

  void onFinishClick() async {

    if (getTotalImages() >= 2 ) {
      updateImages();
      widget.onFinish?.call();
    } else {
      showToast(
        "Sélectionnez minimum 2 images ",
        second: 3,
        context,
        type: ToastificationType.warning,
      );
    }
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(
      context,
    ).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider
            .of<AddModifyImmBloc>(context)
            .state
            .realestate ??
            Realestate();
    return realestate;
  }

  void remplirFields() {
    Realestate realestate = getRealEstate();
    setState(() {
      _images = realestate.files ?? [];
    });
  }
}
