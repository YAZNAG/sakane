import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/components/validation_error.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/features/immobilier/add_contract/cubit/add_contract_cubit.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/contract.dart';
import 'package:immobilier/models/owner.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';

class AddContractScreen extends StatefulWidget {
  AddContractScreen({Key? key}) : super(key: key);

  static Widget page(int id) => BlocProvider<AddContractCubit>(
    create: (ctx) => AddContractCubit(id)..fetchData(),
    child: AddContractScreen(),
  );

  @override
  State<AddContractScreen> createState() => _AddContractScreenState();
}

class _AddContractScreenState extends State<AddContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  final _noteController = TextEditingController();
  final _signedDateController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _partyController = TextEditingController();

  // Data
  DateTime? _signedDate;
  DateTime? _expirationDate;
  Owner? _selectedOwner;
  Client? _selectedClient;
  String _partyType = 'owner'; // 'owner' or 'client'
  List<File> _documents = [];

  @override
  void dispose() {
    _noteController.dispose();
    _signedDateController.dispose();
    _expirationDateController.dispose();
    _partyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Ajouter un contrat",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AddContractCubit, AddContractState>(
        listener: _listener,
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(AddContractState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: () => BlocProvider.of<AddContractCubit>(context).fetchData(),
      );
    } else if (state.fetchStatus == AppStatus.success) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              SizedBox(height: 24),
              _buildDatesSection(state),
              SizedBox(height: 24),
              _buildPartySection(state),
              SizedBox(height: 24),
              _buildNoteSection(state),
              SizedBox(height: 24),
              _buildDocumentsSection(),
              SizedBox(height: 32),
              _buildSubmitButton(state),
            ],
          ),
        ),
      );
    }
    return SizedBox();
  }

  Widget _buildHeaderSection() {
    return Container(
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
          Icon(Icons.description, size: 48, color: AppColors.primaryColor),
          SizedBox(height: 8),
          Text(
            "Nouveau contrat de location",
            style: TextStyle(
              color: AppColors.primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection(AddContractState state) {
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
            "Dates du contrat",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),

          MyFormField(
            label: "Date de signature *",
            hint: "Sélectionnez la date de signature",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _signedDateController,
            readOnly: true,
            onTap: () => _pickSignedDate(),
            suffix: Icon(Icons.calendar_today, size: 20, color: Colors.grey),
            validator: Validator().required().make(),
          ),

          SizedBox(height: 16),

          MyFormField(
            label: "Date d'expiration *",
            hint: "Sélectionnez la date d'expiration",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _expirationDateController,
            readOnly: true,
            onTap: () => _pickExpirationDate(),
            suffix: Icon(Icons.calendar_today, size: 20, color: Colors.grey),
            validator: Validator().required().make(),
          ),

          if (_signedDate != null && _expirationDate != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    "Durée: ${_expirationDate!.difference(_signedDate!).inDays} jours",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w500,
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

  Widget _buildPartySection(AddContractState state) {
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
            "Partie contractante",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Sélectionnez un propriétaire OU un client",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 20),

          // Party type selector
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: Text("Propriétaire", style: TextStyle(fontSize: 14)),
                  value: 'owner',
                  groupValue: _partyType,
                  onChanged: (value) {
                    setState(() {
                      _partyType = value!;
                      _selectedClient = null;
                      _partyController.clear();
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text("Client", style: TextStyle(fontSize: 14)),
                  value: 'client',
                  groupValue: _partyType,
                  onChanged: (value) {
                    setState(() {
                      _partyType = value!;
                      _selectedOwner = null;
                      _partyController.clear();
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          MyFormField(
            label: _partyType == 'owner' ? "Propriétaire" : "Client",
            hint: _partyType == 'owner' ? "Sélectionnez un propriétaire" : "Sélectionnez un client",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _partyController,
            readOnly: true,
            onTap: () => _partyType == 'owner' ? _selectOwner(state) : _selectClient(state),
            suffix: Icon(Icons.arrow_drop_down, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(AddContractState state) {
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
            "Note",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),

          MyFormField(
            label: "Note / Description",
            hint: "Entrez des informations supplémentaires",
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
              Spacer(),
              Text(
                "${_documents.length} fichier${_documents.length > 1 ? 's' : ''}",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Formats acceptés: JPEG, PNG, PDF",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),

          if (_documents.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _documents.length,
              separatorBuilder: (context, index) => SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildDocumentItem(_documents[index], index);
              },
            ),
            SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showImageSourceDialog,
              icon: Icon(Icons.add),
              label: Text("Ajouter un document"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: BorderSide(color: AppColors.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(File document, int index) {
    final fileName = document.path.split('/').last;
    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png');

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isImage ? Colors.blue.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isImage ? Icons.image : Icons.picture_as_pdf,
              color: isImage ? AppColors.primaryColor : Colors.orange.shade700,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  "Document ${index + 1}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removeDocument(index),
            icon: Icon(Icons.delete, color: Colors.red.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AddContractState state) {
    final isLoading = state.addStatus == AppStatus.loading;

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
            onPressed: isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Text(
              "Créer le contrat",
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

  void _listener(BuildContext context, AddContractState state) {
    if (state.addStatus == AppStatus.success) {
      showToast(
        "Contrat créé avec succès",
        context,
        second: 2,
        whenComplete: () => Navigator.of(context).pop(),
      );
    } else if (state.addStatus == AppStatus.error) {
      if(state.errors!=null){
        showDialog(
            context: context,
            builder: (ctx)=>ValidationErrorWidget(error: state.errors!)
        );
      }else{
        showToast(
          "",
          description: state.error ?? "Error",
          type: ToastificationType.error,
          context,
          second: 2,
        );
      }
    }
  }

  Future<void> _pickSignedDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _signedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _signedDate = picked;
        _signedDateController.text = picked.formattedDateFr;
      });
    }
  }

  Future<void> _pickExpirationDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(Duration(days: 365)),
      firstDate: _signedDate ?? DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() {
        _expirationDate = picked;
        _expirationDateController.text = picked.formattedDateFr;
      });
    }
  }

  void _selectOwner(AddContractState state) {
    final owners = state.owners ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Sélectionner un propriétaire",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: owners.isEmpty
                        ? Center(child: Text("Aucun propriétaire disponible"))
                        : ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: owners.length,
                      separatorBuilder: (context, index) => Divider(),
                      itemBuilder: (context, index) {
                        final owner = owners[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(Icons.person, color: AppColors.primaryColor),
                          ),
                          title: Text(owner.name ?? "N/A"),
                          subtitle: Text(owner.tel ?? ""),
                          onTap: () {
                            setState(() {
                              _selectedOwner = owner;
                              _partyController.text = owner.name ?? "";
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectClient(AddContractState state) {
    final clients = state.clients ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Sélectionner un client",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: clients.isEmpty
                        ? Center(child: Text("Aucun client disponible"))
                        : ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: clients.length,
                      separatorBuilder: (context, index) => Divider(),
                      itemBuilder: (context, index) {
                        final client = clients[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(Icons.account_circle, color: Colors.green.shade700),
                          ),
                          title: Text(client.fullName),
                          subtitle: Text(client.type ?? ""),
                          onTap: () {
                            setState(() {
                              _selectedClient = client;
                              _partyController.text = client.fullName;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, color: AppColors.primaryColor),
                  ),
                  title: Text("Prendre une photo", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("Utiliser l'appareil photo"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.photo_library, color: Colors.green.shade700),
                  ),
                  title: Text("Choisir depuis la galerie", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text("Sélectionner un fichier existant"),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument(ImageSource.gallery);
                  },
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Annuler", style: TextStyle(color: Colors.grey.shade600)),
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

  Future<void> _pickDocument(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _documents.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection du document"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_signedDate == null || _expirationDate == null) {
        showToast(
          "",
          description: "Veuillez sélectionner les dates requises",
          type: ToastificationType.warning,
          context,
          second: 2,
        );
        return;
      }

      final contract = Contract(
        signedDate: _signedDate,
        expirationDate: _expirationDate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        owner: _selectedOwner,
        client: _selectedClient,
        files: _documents,
      );

      BlocProvider.of<AddContractCubit>(context).addContract(contract);
    }
  }
}