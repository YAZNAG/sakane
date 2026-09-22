import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_error_dialogue.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/features/users/add_user/cubit/add_user_cubit.dart';
import 'package:immobilier/features/reception_whatsapp/ui/reception_whatsapp.dart';
import 'package:immobilier/models/manager.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import '../../../../components/loading_indicator.dart';

class AddUserScreen extends StatefulWidget {
  int? userId;

  AddUserScreen({this.userId}) ;

  static Widget page({int? id}) {
    return BlocProvider<AddUserCubit>(
      create: (ctx) => AddUserCubit(id: id)..fetchData(),
      child: AddUserScreen(userId: id,),
    );
  }

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isInitialized=false;



  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.userId!=null?"Modification du gestionnaire":"Ajouter un gestionnaire",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocConsumer<AddUserCubit, AddUserState>(
        listener: _listener,
        builder: (context, state) {
          if(state.fetchDataStatus==AppStatus.loading){
            return Center(child: MyLoadingIndicator());
          }else if(state.fetchDataStatus==AppStatus.error){
            return MyErrorWidget(error: state.error??AppStrings.error, action: AppStrings.tryAgain,actionCLick: fetchData,);
          }else if(state.fetchDataStatus==AppStatus.success) {
            if(!_isInitialized && state.id!=null){
              remplierFields(state);
            }
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
                            "Nouveau gestionnaire",
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Ajoutez les informations du gestionnaire",
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

                    // Personal Information Section
                    _buildPersonalInfoSection(state),

                    SizedBox(height: 24),

                    // Account Information Section
                    _buildAccountInfoSection(state),

                    // Reception WhatsApp de ce gestionnaire (admin)
                    if (widget.userId != null && estAdminReceptionWhatsapp) ...[
                      SizedBox(height: 24),
                      TuileReceptionWhatsapp(
                        sousTitre: "Messages WhatsApp que ce gestionnaire reçoit",
                        onTap: () => ouvrirReceptionWhatsapp(
                          context,
                          managerId: widget.userId,
                          nom: "${state.manager?.firstName ?? ''} ${state.manager?.lastName ?? ''}",
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // Security Section
                    _buildSecuritySection(state),

                    SizedBox(height: 32),

                    // Action Buttons
                    _buildActionButtons(state),
                  ],
                ),
              ),
            );
          }
          return SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPersonalInfoSection(AddUserState state) {
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
              Icon(
                Icons.person_outline,
                color: AppColors.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Informations personnelles",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          MyFormField(
            label: "Prénom *",
            hint: "Entrez le prénom",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _firstNameController,
            validator: Validator().required().min(3).make(),
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
            validator: Validator().required().min(3).make(),
          ),

          SizedBox(height: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Role *",
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: state.selectedRole,
                items: state.roles?.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                decoration: _inputDecoration(hint: "Sélectionnez une catégorie"),
                onChanged: onRoleChanged,
                validator: (val) =>
                val == null ? "Veuillez choisir un role" : null,
              ),
            ],
          ),

        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? label}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      );


  Widget _buildAccountInfoSection(AddUserState state) {
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
              Icon(
                Icons.email_outlined,
                color: AppColors.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Informations du compte",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          MyFormField(
            label: "Email *",
            hint: "exemple@email.com",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _emailController,
            inputType: TextInputType.emailAddress,
            validator: Validator().required().email().make(),
            readOnly: widget.userId!=null,
          ),

          SizedBox(height: 8),
          MyFormField(
            label: "Phone *",
            hint: "212670961238",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _phoneController,
            inputType: TextInputType.number,
            validator: Validator().required().make(),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.grey.shade600,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  "L'email sera utilisé comme identifiant de connexion",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(AddUserState state) {
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
              Icon(
                Icons.lock_outline,
                color: AppColors.primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Sécurité",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          MyFormField(
            label: "Mot de passe *",
            hint: "Entrez le mot de passe",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _passwordController,
            isPassWord: true,
            validator: widget.userId==null?Validator().required().min(4).make():null,
            openEyeIcon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.black,
            ),
            closeEyeIcon: const Icon(
              FontAwesomeIcons.eyeSlash,
              color: Colors.black,
            ),
          ),


          SizedBox(height: 16),

          MyFormField(
            label: "Confirmer le mot de passe *",
            hint: "Confirmez le mot de passe",
            labelColor: Colors.black,
            borderColor: Colors.black,
            hintColor: Colors.black54,
            activeBorderColor: Colors.black,
            controller: _confirmPasswordController,
            isPassWord: true,
            validator: widget.userId==null?Validator().required().confirmPass(_passwordController).make():null,
            openEyeIcon: const Icon(
              Icons.remove_red_eye_outlined,
              color: Colors.black,
            ),
            closeEyeIcon: const Icon(
              FontAwesomeIcons.eyeSlash,
              color: Colors.black,
            ),
          ),

          SizedBox(height: 12),

          // Password requirements
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Exigences du mot de passe",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _buildPasswordRequirement("Minimum 4 caractères"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirement(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 24, top: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 14,
            color: AppColors.primaryColor,
          ),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AddUserState state) {
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
            onPressed: state.actionStatus == AppStatus.loading
                ? null
                : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: state.actionStatus == AppStatus.loading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20,color: Colors.white,),
                SizedBox(width: 8),
                Text(
                  widget.userId!=null?"Modifier":"Ajouter",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      Manager manager = Manager(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.isEmpty?null:_passwordController.text,
        phone: _phoneController.text
      );

      if(widget.userId!=null){

        BlocProvider.of<AddUserCubit>(context).updateUser(manager);
      }else{
        BlocProvider.of<AddUserCubit>(context).addUser(manager);
      }
    }
  }

  void _listener(BuildContext context, AddUserState state) {
    if (state.actionStatus == AppStatus.error) {
      // Show validation errors or general error
      if (state.errors != null && state.errors!.isNotEmpty) {
        showDialogueError(context, state.errors!);
      } else {
        showToast(
          "",
          description: state.error ?? AppStrings.error,
          context,
          second: 3,
          type: ToastificationType.error,
        );
      }
    } else if (state.actionStatus == AppStatus.success) {
      showToast(
        AppStrings.success,
        description: "Gestionnaire ajouté avec succès",
        context,
        second: 2,
        type: ToastificationType.success,
        whenComplete: () {
          GoRouter.of(context).pop(state.manager);
        },
      );
    }
  }

  void fetchData() {
    context.read<AddUserCubit>().fetchData();
  }

  void onRoleChanged(String? value) {
    if(value==null)return;
    context.read<AddUserCubit>().onRoleChanged(value);
  }

  void remplierFields(AddUserState state) {
      final manager=state.manager;
    _firstNameController.text=manager?.firstName??"";
    _lastNameController.text=manager?.lastName??"";
    _emailController.text=manager?.email??"";
    _phoneController.text=manager?.phone??"";
    _isInitialized=true;
  }
}