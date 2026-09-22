import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_error_dialogue.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/features/clients/edit_client/cubit/edit_client_cubit.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/media.dart';
import 'package:toastification/toastification.dart';

class EditClientPage extends StatefulWidget {
  final Client client;

  const EditClientPage({Key? key, required this.client}) : super(key: key);

  static Widget page(Client client) {
    return BlocProvider<EditClientCubit>(
      create: (_) => EditClientCubit(),
      child: EditClientPage(client: client),
    );
  }

  @override
  State<EditClientPage> createState() => _EditClientPageState();
}

class _EditClientPageState extends State<EditClientPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _firstNameArController;
  late final TextEditingController _lastNameArController;
  late final TextEditingController _emailController;
  late final TextEditingController _telController;
  late final TextEditingController _identityNumberController;
  late final TextEditingController _nationaliteController;

  late List<Media> _existingDocs;
  final List<File> _newDocuments = [];
  late bool _isNationalId;
  late bool _isPassport;
  late bool _isResidencePermit;
  late bool _isMarriageCertificate;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _firstNameController = TextEditingController(text: c.firstName ?? '');
    _lastNameController = TextEditingController(text: c.lastName ?? '');
    _firstNameArController = TextEditingController(text: c.firstNameAr ?? '');
    _lastNameArController = TextEditingController(text: c.lastNameAr ?? '');
    _emailController = TextEditingController(text: c.email ?? '');
    _telController = TextEditingController(text: c.tel ?? '');
    _identityNumberController = TextEditingController(text: c.identityNumber ?? '');
    _nationaliteController = TextEditingController(text: (c.nationalite ?? '').trim().isEmpty ? 'Marocain' : c.nationalite);

    _existingDocs = List<Media>.from(c.docs ?? []);

    final provided = c.documentsProvided ?? [];
    _isNationalId = provided.contains('National ID');
    _isPassport = provided.contains('Passport');
    _isResidencePermit = provided.contains('Residence Permit');
    _isMarriageCertificate = provided.contains('Marriage Certificate');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameArController.dispose();
    _lastNameArController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _identityNumberController.dispose();
    _nationaliteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Modifier le client",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<EditClientCubit, EditClientState>(
        listener: _listener,
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: "Informations personnelles",
                    children: [
                      MyFormField(
                        label: "Prénom *",
                        hint: "Entrez le prénom",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _firstNameController,
                        validator: Validator().required().min(2).make(),
                      ),
                      SizedBox(height: 16),
                      MyFormField(
                        label: "Nom *",
                        hint: "Entrez le nom",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _lastNameController,
                        validator: Validator().required().min(2).make(),
                      ),

                      SizedBox(height: 16),

                      // Les noms arabes figurent sur la CIN et sur les documents
                      // destines aux autorites. Facultatifs : la lecture arabe
                      // n'aboutit pas toujours, et l'agent peut les saisir plus tard.
                      MyFormField(
                        label: "Pr\u00e9nom en arabe",
                        hint: "\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0634\u062E\u0635\u064A",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _firstNameArController,
                      ),

                      SizedBox(height: 16),

                      MyFormField(
                        label: "Nom en arabe",
                        hint: "\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0639\u0627\u0626\u0644\u064A",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _lastNameArController,
                      ),
                      SizedBox(height: 16),
                      MyFormField(
                        label: "Numéro d'identité",
                        hint: "CIN, passeport, permis...",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _identityNumberController,
                      ),

                      SizedBox(height: 16),

                      MyFormField(
                        label: "Nationalité",
                        hint: "ex. Marocain, Français…",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _nationaliteController,
                        maxLenght: 60,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildSection(
                    title: "Informations de contact",
                    children: [
                      MyFormField(
                        label: "Email",
                        hint: "exemple@email.com",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _emailController,
                        inputType: TextInputType.emailAddress,
                        validator: Validator().email().make(),
                      ),
                      SizedBox(height: 16),
                      MyFormField(
                        label: "Téléphone *",
                        hint: "+212612345678",
                        labelColor: Colors.black,
                        borderColor: Colors.black,
                        hintColor: Colors.black54,
                        activeBorderColor: Colors.black,
                        controller: _telController,
                        inputType: TextInputType.phone,
                        validator: Validator().required().integer().min(10).make(),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildSection(
                    title: "Type de pièce d'identité fournie",
                    subtitle: "Sélectionnez le(s) type(s) de document(s)",
                    children: [
                      CheckboxListTile(
                        value: _isNationalId,
                        onChanged: (v) => setState(() => _isNationalId = v ?? false),
                        title: Text("Carte d'identité nationale", style: TextStyle(fontSize: 15, color: Colors.black87)),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primaryColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _isPassport,
                        onChanged: (v) => setState(() => _isPassport = v ?? false),
                        title: Text("Passeport", style: TextStyle(fontSize: 15, color: Colors.black87)),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primaryColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _isResidencePermit,
                        onChanged: (v) => setState(() => _isResidencePermit = v ?? false),
                        title: Text("Permis de séjour", style: TextStyle(fontSize: 15, color: Colors.black87)),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primaryColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      CheckboxListTile(
                        value: _isMarriageCertificate,
                        onChanged: (v) => setState(() => _isMarriageCertificate = v ?? false),
                        title: Text("Certificat de mariage", style: TextStyle(fontSize: 15, color: Colors.black87)),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primaryColor,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildSection(
                    title: "Documents",
                    subtitle: "Ajoutez de nouveaux documents (les anciens sont conservés)",
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _existingDocs.length + _newDocuments.length + 1,
                        itemBuilder: (context, index) {
                          if (index < _existingDocs.length) {
                            return _buildExistingDocItem(_existingDocs[index]);
                          }
                          final newIndex = index - _existingDocs.length;
                          if (newIndex < _newDocuments.length) {
                            return _buildNewDocItem(newIndex);
                          }
                          return _buildAddDocumentButton();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 32),
                  _buildActionButtons(state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({required String title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          if (subtitle != null) ...[
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildExistingDocItem(Media doc) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: doc.url ?? '',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorWidget: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildNewDocItem(int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(_newDocuments[index], width: double.infinity, height: double.infinity, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => setState(() => _newDocuments.removeAt(index)),
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red.shade600, shape: BoxShape.circle),
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(4)),
            child: Text("Nouveau", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildAddDocumentButton() {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 24, color: Colors.grey.shade600),
            SizedBox(height: 4),
            Text("Ajouter", style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(EditClientState state) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => GoRouter.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("Annuler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: state.updateStatus == AppStatus.loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: state.updateStatus == AppStatus.loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : Text("Enregistrer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Text("Choisir une source", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.camera_alt, color: AppColors.primaryColor),
                ),
                title: Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.photo_library, color: Colors.green.shade700),
                ),
                title: Text("Choisir depuis la galerie", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024, maxHeight: 1024);
      if (file != null) setState(() => _newDocuments.add(File(file.path)));
    } else {
      final List<XFile> files = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1024, maxHeight: 1024);
      setState(() { for (final f in files) _newDocuments.add(File(f.path)); });
    }
  }

  List<String> _getSelectedIdTypes() {
    List<String> types = [];
    if (_isNationalId) types.add("National ID");
    if (_isPassport) types.add("Passport");
    if (_isResidencePermit) types.add("Residence Permit");
    if (_isMarriageCertificate) types.add("Marriage Certificate");
    return types;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final updated = Client(
      id: widget.client.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      firstNameAr: _firstNameArController.text.trim().isEmpty
          ? null
          : _firstNameArController.text.trim(),
      lastNameAr: _lastNameArController.text.trim().isEmpty
          ? null
          : _lastNameArController.text.trim(),
      email: _emailController.text,
      tel: _telController.text,
      identityNumber: _identityNumberController.text.isEmpty ? null : _identityNumberController.text,
      // Tout client a une nationalite : vide, elle reste « Marocain ».
      nationalite: _nationaliteController.text.trim().isEmpty ? 'Marocain' : _nationaliteController.text.trim(),
      documents: _newDocuments,
      documentsProvided: _getSelectedIdTypes(),
    );
    BlocProvider.of<EditClientCubit>(context).updateClient(updated);
  }

  void _listener(BuildContext context, EditClientState state) {
    if (state.updateStatus == AppStatus.error) {
      if (state.errors != null) {
        showDialogueError(context, state.errors!);
      } else {
        showToast("", description: state.error ?? AppStrings.error, context, second: 3, type: ToastificationType.error);
      }
    } else if (state.updateStatus == AppStatus.success) {
      showToast(
        AppStrings.success,
        context,
        second: 2,
        type: ToastificationType.success,
        whenComplete: () => GoRouter.of(context).pop(state.client),
      );
    }
  }
}
