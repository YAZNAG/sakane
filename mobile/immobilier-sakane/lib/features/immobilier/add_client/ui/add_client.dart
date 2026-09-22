import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/features/immobilier/add_client/cubit/add_client_cubit.dart';
import 'package:immobilier/models/client.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/services/cin_scanner_service.dart';
import 'package:immobilier/core/services/transcription_arabe.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/repository/repository.dart';
import '../../../../core/utils/show_error_dialogue.dart';
import 'package:immobilier/components/doublons_client.dart';

class AddClientPage extends StatefulWidget {
  static Widget page() {
    return BlocProvider<AddClientCubit>(
      create: (context) => AddClientCubit(),
      child: AddClientPage(),
    );
  }

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameArController = TextEditingController();
  final _lastNameArController = TextEditingController();
  final _telController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _nationaliteController = TextEditingController(text: 'Marocain');

  // Lecture automatique de la CIN (traitement local, hors ligne)
  final CinScannerService _cinScanner = CinScannerService();
  bool _scanEnCours = false;

  /// Photo de la CIN issue du scan, conservee dans les documents du client.
  /// Un nouveau scan remplace la precedente.
  File? _photoCin;

  // Documents
  List<File> _documents = [];

  // ID Type Checkboxes
  bool _isNationalId = false;
  bool _isPassport = false;
  bool _isResidencePermit = false;
  bool _isMarriageCertificate = false;

  //String countryCode="+212";

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameArController.dispose();
    _lastNameArController.dispose();
    _telController.dispose();
    _identityNumberController.dispose();
    _nationaliteController.dispose();
    _cinScanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Ajouter un client",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AddClientCubit, AddClientState>(
        listener: listener,
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person_add,
                          size: 48,
                          color: AppColors.primaryColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Informations du nouveau client",
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Personal Information Section
                  _buildPersonalInfoSection(),

                  SizedBox(height: 24),

                  // Contact Information Section
                  _buildContactInfoSection(),

                  SizedBox(height: 24),

                  // ID Type Section
                  _buildIdTypeSection(),

                  SizedBox(height: 24),

                  // Documents Section
                  _buildDocumentsSection(),

                  SizedBox(height: 32),

                  // Action Buttons
                  _buildActionButtons(state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informations personnelles",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),

          _buildScanCinButton(),

          SizedBox(height: 20),

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
    );
  }

  Widget _buildContactInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informations de contact",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),

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
           /* leading: CountryCodePicker(
              onChanged: _onCountryChange,
              initialSelection: countryCode,
              favorite: const ['+212', 'MA', '+1', 'US', '+44', 'GB'],
              showCountryOnly: false,
              showOnlyCountryWhenClosed: false,
              alignLeft: false,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontSize: 16,
                color: Color(0xFF2D3436),
                fontWeight: FontWeight.w500,
              ),
              dialogTextStyle: const TextStyle(
                fontSize: 16,
                color: Color(0xFF2D3436),
              ),
              hideSearch: true,
              dialogSize: Size(
                MediaQuery.of(context).size.width * 0.9,
                MediaQuery.of(context).size.height * 0.7,
              ),
              flagDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
            ),*/
          ),
        ],
      ),
    );
  }

  Widget _buildIdTypeSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Type de pièce d'identité fournie",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Sélectionnez le(s) type(s) de document(s)",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          SizedBox(height: 16),

          // National ID
          CheckboxListTile(
            value: _isNationalId,
            onChanged: (value) {
              setState(() {
                _isNationalId = value ?? false;
              });
            },
            title: Text(
              "Carte d'identité nationale",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          // Passport
          CheckboxListTile(
            value: _isPassport,
            onChanged: (value) {
              setState(() {
                _isPassport = value ?? false;
              });
            },
            title: Text(
              "Passeport",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          // Residence Permit
          CheckboxListTile(
            value: _isResidencePermit,
            onChanged: (value) {
              setState(() {
                _isResidencePermit = value ?? false;
              });
            },
            title: Text(
              "Permis de séjour",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          // Marriage Certificate
          CheckboxListTile(
            value: _isMarriageCertificate,
            onChanged: (value) {
              setState(() {
                _isMarriageCertificate = value ?? false;
              });
            },
            title: Text(
              "Certificat de mariage",
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Documents",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              /*Spacer(),
              Text(
                "${_documents.length}/3",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),*/
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Ajoutez les documents (CIN, passeport, etc.)",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          SizedBox(height: 16),

          // Documents Grid
          if (_documents.isNotEmpty || _documents.length < 3) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _documents.length + 1,
              itemBuilder: (context, index) {
                if (index < _documents.length) {
                  // Show existing document
                  return _buildDocumentItem(_documents[index], index);
                } else {
                  // Show add button
                  return _buildAddDocumentButton();
                }
              },
            ),
          ] else ...[
            // Empty state
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Aucun document ajouté",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showImageSourceDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "Ajouter un document",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentItem(File document, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              document,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeDocument(index),
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
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
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
              size: 24,
              color: Colors.grey.shade600,
            ),
            SizedBox(height: 4),
            Text(
              "Ajouter",
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(AddClientState state) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              "Annuler",
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
            onPressed: state.addStatus == AppStatus.loading
                ? null
                : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.addStatus == AppStatus.loading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
              "Ajouter le client",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourceDialog() {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Text(
                  "Choisir une source",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                SizedBox(height: 20),

                // Camera option
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, color: AppColors.primaryColor),
                  ),
                  title: Text(
                    "Prendre une photo",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text("Utiliser l'appareil photo"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),

                // Gallery option
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: Colors.green.shade700,
                    ),
                  ),
                  title: Text(
                    "Choisir depuis la galerie",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text("Sélectionner une image existante"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),

                SizedBox(height: 20),

                // Cancel button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Annuler",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {

      if(source==ImageSource.camera){
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if(pickedFile!=null){
          setState(() {
            _documents.add(File(pickedFile.path));
          });
        }
      }else{
        final List<XFile> files=await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        for(XFile f in files){
          _documents.add(File(f.path));
        }
        setState(() {

        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection de l'image"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeDocument(int index) {
    setState(() {
      if (_photoCin != null && _documents[index] == _photoCin) {
        _photoCin = null;
      }
      _documents.removeAt(index);
    });
  }

  List<String> _getSelectedIdTypes() {
    List<String> types = [];
    if (_isNationalId) types.add("National ID");
    if (_isPassport) types.add("Passport");
    if (_isResidencePermit) types.add("Residence Permit");
    if (_isMarriageCertificate) types.add("Marriage Certificate");
    return types;
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {

      Client client = Client(
        email: _emailController.text,
        tel: _telController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        firstNameAr: _firstNameArController.text.trim().isEmpty
            ? null
            : _firstNameArController.text.trim(),
        lastNameAr: _lastNameArController.text.trim().isEmpty
            ? null
            : _lastNameArController.text.trim(),
        identityNumber: _identityNumberController.text.isEmpty ? null : _identityNumberController.text,
        // Tout client a une nationalite : vide, elle reste « Marocain ».
        nationalite: _nationaliteController.text.trim().isEmpty ? 'Marocain' : _nationaliteController.text.trim(),
        documents: _documents,
        documentsProvided: _getSelectedIdTypes(),
      );

      // Un client deja connu (meme telephone, CIN ou nom) : on propose
      // son dossier plutot que d'en creer un doublon.
      final choix = await verifierClientExistant(
        context,
        tel: _telController.text,
        cin: _identityNumberController.text,
        prenom: _firstNameController.text,
        nom: _lastNameController.text,
      );
      if (choix == null || !mounted) return;
      if (choix.existant != null) {
        GoRouter.of(context).pop(choix.existant);
        return;
      }
      BlocProvider.of<AddClientCubit>(context).addClient(client);
    }
  }

  void listener(BuildContext context, AddClientState state) {
    if (state.addStatus == AppStatus.error) {
      if(state.errors!=null){
        showDialogueError(context, state.errors!);
      }else{
        showToast(
          "",
          description:state.error ?? AppStrings.error,
          context,
          second: 3,
          type: ToastificationType.error,
        );
      }
    } else if (state.addStatus == AppStatus.success) {
      showToast(
        AppStrings.success,
        context,
        second: 2,
        type: ToastificationType.success,
        whenComplete: () {
          GoRouter.of(context).pop(state.client);
        },
      );
    }
  }



  /// Bouton de lecture automatique de la carte d'identite.
  Widget _buildScanCinButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _scanEnCours ? null : _scannerCin,
        icon: _scanEnCours
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.document_scanner_outlined),
        label: Text(
          _scanEnCours ? "Lecture en cours..." : "Scanner la CIN",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          side: BorderSide(color: AppColors.primaryColor),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// Prend une photo de la CIN puis en extrait le numero, le prenom et le nom.
  Future<void> _scannerCin() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Scanner la carte d'identité",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("Prendre une photo"),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("Choisir dans la galerie"),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    // 2400 px suffisent pour lire la carte : au-dela, la lecture est
    // plus lente sans etre meilleure, et la photo jointe au dossier du
    // client s'alourdit pour rien.
    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (photo == null) return;

    setState(() => _scanEnCours = true);
    try {
      final fichier = File(photo.path);
      final resultat = await _avecMemoire(await _cinScanner.scan(fichier));
      if (!mounted) return;

      // La photo de la CIN est conservee dans le dossier du client,
      // que la lecture ait abouti ou non.
      _enregistrerPhotoCin(fichier);

      if (!resultat.hasData) {
        showToast(
          "Photo enregistrée, mais aucune information n'a pu être lue. "
          "Saisissez les champs manuellement ou rescannez.",
          context,
          type: ToastificationType.warning,
        );
        return;
      }
      await _confirmerDonneesCin(resultat);
    } catch (e) {
      if (mounted) {
        showToast("La lecture a échoué. Réessayez.", context,
            type: ToastificationType.error);
      }
    } finally {
      if (mounted) setState(() => _scanEnCours = false);
    }
  }

  /// Affine l'arabe proposé avec la mémoire de l'agence : l'écriture déjà
  /// enregistrée pour ces noms chez d'autres clients. Sans réponse du
  /// serveur, la transcription faite sur le téléphone reste telle quelle.
  Future<CinScanResult> _avecMemoire(CinScanResult r) async {
    if ((r.firstName ?? '').isEmpty && (r.lastName ?? '').isEmpty) return r;
    final (prenom, nom) = await Dependencies.get<Repository>()
        .nomsArabes(r.firstName, r.lastName);
    if (prenom == null && nom == null) return r;
    return r.avecArabe(
      TranscriptionArabe.proposer(r.firstName, memoire: prenom),
      TranscriptionArabe.proposer(r.lastName, memoire: nom),
    );
  }

  /// Ajoute la photo de CIN aux documents du client.
  /// Un nouveau scan remplace la photo precedente plutot que d'en accumuler.
  void _enregistrerPhotoCin(File photo) {
    setState(() {
      if (_photoCin != null) {
        _documents.remove(_photoCin);
      }
      _photoCin = photo;
      if (_documents.length < 3) {
        _documents.add(photo);
      } else {
        // la liste est pleine : on remplace le dernier document
        _documents[_documents.length - 1] = photo;
      }
      _isNationalId = true;
    });
  }

  /// Affiche les valeurs lues pour verification avant de remplir le formulaire.
  Future<void> _confirmerDonneesCin(CinScanResult r) async {
    final prenom = TextEditingController(text: r.firstName ?? '');
    final nom = TextEditingController(text: r.lastName ?? '');
    final cin = TextEditingController(text: r.cin ?? '');
    final prenomAr = TextEditingController(text: r.firstNameAr ?? '');
    final nomAr = TextEditingController(text: r.lastNameAr ?? '');

    // L'arabe est déduit du nom en français. Si l'agent corrige le
    // français, l'arabe suit — tant qu'il ne l'a pas modifié à la main.
    void suivre(TextEditingController latin, TextEditingController arabe) {
      var auto = arabe.text;
      latin.addListener(() {
        if (arabe.text != auto) return; // corrigé à la main : on n'y touche plus
        final propose = TranscriptionArabe.proposer(latin.text) ?? '';
        if (propose == auto) return;
        auto = propose;
        arabe.text = propose;
      });
    }

    suivre(prenom, prenomAr);
    suivre(nom, nomAr);

    final valider = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.primaryColor),
            const SizedBox(width: 8),
            const Expanded(child: Text("Vérifiez les informations")),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${r.foundCount} champ(s) reconnu(s). Corrigez si nécessaire avant de valider.",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: prenom,
                decoration: const InputDecoration(
                  labelText: "Prénom",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nom,
                decoration: const InputDecoration(
                  labelText: "Nom",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cin,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "Numéro CIN",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // L'arabe est deduit du nom en francais : une proposition,
              // que l'agent verifie.
              TextField(
                controller: prenomAr,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: "Prénom en arabe",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomAr,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: "Nom en arabe",
                  helperText: "Écrit d'après le nom en français : vérifiez.",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Utiliser", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (valider == true) {
      setState(() {
        if (prenom.text.trim().isNotEmpty) {
          _firstNameController.text = prenom.text.trim();
        }
        if (nom.text.trim().isNotEmpty) {
          _lastNameController.text = nom.text.trim();
        }
        if (cin.text.trim().isNotEmpty) {
          _identityNumberController.text = cin.text.trim().toUpperCase();
          _isNationalId = true;
        }
        if (prenomAr.text.trim().isNotEmpty) {
          _firstNameArController.text = prenomAr.text.trim();
        }
        if (nomAr.text.trim().isNotEmpty) {
          _lastNameArController.text = nomAr.text.trim();
        }
      });
      if (mounted) {
        showToast("Informations reportées dans le formulaire", context,
            type: ToastificationType.success);
      }
    }

    prenom.dispose();
    nom.dispose();
    cin.dispose();
    prenomAr.dispose();
    nomAr.dispose();
  }

}