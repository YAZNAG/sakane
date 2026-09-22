import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/features/immobilier/add_owner/cubit/add_owner_cubit.dart';
import 'package:immobilier/models/owner.dart';
import 'package:toastification/toastification.dart';

import '../../../../components/form_field.dart';
import '../../../../core/utils/show_error_dialogue.dart';
import 'package:immobilier/core/constants/app_colors.dart';
class AddModifyOwnerPage extends StatefulWidget {
  final Owner? owner;
  AddModifyOwnerPage({this.owner});

  static Widget page({Owner? owner}) {
    return BlocProvider(
      create: (context) => AddOwnerCubit(),
      child: AddModifyOwnerPage(owner: owner),
    );
  }

  @override
  State<AddModifyOwnerPage> createState() => _AddModifyOwnerPageState();
}

class _AddModifyOwnerPageState extends State<AddModifyOwnerPage> {
  late bool isUpdate;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    isUpdate = widget.owner != null;
    if (isUpdate) {
      _nameController.text    = widget.owner!.name    ?? '';
      _emailController.text   = widget.owner!.email   ?? '';
      _phoneController.text   = widget.owner!.tel     ?? '';
      _addressController.text = widget.owner!.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isUpdate ? "Modifier un propriétaire" : "Ajouter un propriétaire",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AddOwnerCubit, AddOwnerState>(
        listener: listener,
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
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
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
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
                          isUpdate
                              ? "Modifier les informations du propriétaire"
                              : "Ajouter un nouveau propriétaire",
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

                  // Form fields
                  MyFormField(
                    label: "Nom complet *",
                    hint: "Entrez le nom complet",
                    controller: _nameController,
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    inputType: TextInputType.name,
                    validator: Validator().required().min(4).max(25).make(),
                  ),

                  SizedBox(height: 16),

                  MyFormField(
                    label: "Email ",
                    hint: "exemple@email.com",
                    controller: _emailController,
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    inputType: TextInputType.emailAddress,
                    validator: Validator().email().make(),
                  ),

                  SizedBox(height: 16),

                  MyFormField(
                    label: "Téléphone *",
                    hint: "0612453739",
                    controller: _phoneController,
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    inputType: TextInputType.phone,
                    validator: Validator().required().number().make(),
                  ),

                  SizedBox(height: 16),

                  MyFormField(
                    label: "Adresse *",
                    hint: "Entrez l'adresse complète",
                    controller: _addressController,
                    labelColor: Colors.black,
                    borderColor: Colors.black,
                    hintColor: Colors.black54,
                    activeBorderColor: Colors.black,
                    inputType: TextInputType.streetAddress,
                    isLarge: true,
                    validator: Validator().required().make(),
                  ),

                  SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => GoRouter.of(context).pop(),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final owner = Owner(
        id:      widget.owner?.id,
        name:    _nameController.text,
        email:   _emailController.text.isNotEmpty ? _emailController.text : null,
        tel:     _phoneController.text,
        address: _addressController.text,
      );
      if (isUpdate) {
        BlocProvider.of<AddOwnerCubit>(context).updateOwner(owner);
      } else {
        BlocProvider.of<AddOwnerCubit>(context).addOwner(owner);
      }
    }
  }

  void listener(BuildContext context, AddOwnerState state) {
    if(state.addStatus==AppStatus.error){
      if(state.errors!=null){
        showDialogueError(context, state.errors!);
      }else{
        showToast("", context,description: state.error??"Error",type: ToastificationType.error,second: 3);
      }
    }else if(state.addStatus==AppStatus.success){
      GoRouter.of(context).pop(state.owner);
    }
  }
}
