import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_error_dialogue.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/immobilier/reclamations/add_reclamation/cubit/add_reclamation_cubit.dart';
import 'package:immobilier/models/reclamation.dart';
import 'package:toastification/toastification.dart';

class AddReclamationPage extends StatefulWidget {
  const AddReclamationPage({Key? key}) : super(key: key);

  static Widget page(int realestateId) {
    return BlocProvider<AddReclamationCubit>(
      create: (_) => AddReclamationCubit(realestateId),
      child: const AddReclamationPage(),
    );
  }

  @override
  State<AddReclamationPage> createState() => _AddReclamationPageState();
}

class _AddReclamationPageState extends State<AddReclamationPage> {
  final _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> _images = [];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Nouvelle réclamation",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AddReclamationCubit, AddReclamationState>(
        listener: _listener,
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildNoteSection(),
                const SizedBox(height: 20),
                _buildImagesSection(),
                const SizedBox(height: 32),
                _buildActions(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.report_problem_outlined, size: 40, color: Colors.orange.shade700),
          ),
          const SizedBox(height: 12),
          Text(
            "Signaler un problème",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "Prenez une photo de l'équipement défaillant et décrivez le problème",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Description du problème",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "Optionnel — ex: le WiFi ne fonctionne pas, le climatiseur est en panne...",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          MyFormField(
            label: "",
            hint: "Décrivez le problème...",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _noteController,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Photos *",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Spacer(),
              Text(
                "${_images.length} photo${_images.length > 1 ? 's' : ''}",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Prenez une photo de l'équipement défaillant (min. 1 requise)",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),

          if (_images.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _images.length,
              itemBuilder: (_, i) => _buildImageThumb(_images[i], i),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text("Ajouter une photo"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: BorderSide(color: AppColors.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          if (_images.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Veuillez ajouter au moins une photo",
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageThumb(File image, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(image, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(AddReclamationState state) {
    final isLoading = state.addStatus == AppStatus.loading;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("Annuler",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Text("Envoyer la réclamation",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Text("Choisir une source",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt, color: AppColors.primaryColor),
                ),
                title: const Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Utiliser l'appareil photo"),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.photo_library, color: Colors.green.shade700),
                ),
                title: const Text("Choisir depuis la galerie", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text("Sélectionner plusieurs photos"),
                onTap: () { Navigator.pop(context); _pickMultiple(); },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Annuler", style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source, imageQuality: 80);
    if (file != null) setState(() => _images.add(File(file.path)));
  }

  Future<void> _pickMultiple() async {
    final List<XFile> files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) setState(() => _images.addAll(files.map((f) => File(f.path))));
  }

  void _submit() {
    if (_images.isEmpty) {
      showToast("", description: "Veuillez ajouter au moins une photo", context,
          type: ToastificationType.warning, second: 2);
      return;
    }
    final reclamation = Reclamation(
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      files: _images,
    );
    context.read<AddReclamationCubit>().createReclamation(reclamation);
  }

  void _listener(BuildContext context, AddReclamationState state) {
    if (state.addStatus == AppStatus.success) {
      showToast("Réclamation envoyée avec succès", context,
          second: 2, whenComplete: () => Navigator.of(context).pop(true));
    } else if (state.addStatus == AppStatus.error) {
      if (state.errors != null) {
        showDialogueError(context, state.errors!);
      } else {
        showToast("", description: state.error ?? "Erreur", context,
            type: ToastificationType.error, second: 2);
      }
    }
  }
}
