import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_images.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/utils/texts.dart';
import 'package:immobilier/features/auth/login/bloc/login_bloc.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:toastification/toastification.dart';
import '../../../../models/manager.dart';

import '../../../../components/custom_button.dart';
import '../../../../components/form_field.dart';
import '../../../../routes.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';

class LoginPage extends StatefulWidget {
  static Widget page() =>
      BlocProvider(create: (context) => LoginBloc(), child: LoginPage());

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-remplissage avec les identifiants memorises lors de la derniere connexion
    final prefs = Dependencies.get<SharedPrefService>();
    emailController.text = prefs.getValue(SharedPrefService.username, "");
    passwordController.text = prefs.getValue(SharedPrefService.password, "");
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: listener,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 60),
                    Image.asset(AppImages.app_logo, height: 170),
                    SizedBox(height: 40),
                    title('Bon retour', fontSize: 28),
                    SizedBox(height: 8),
                    text(
                      'Connectez-vous à votre compte',
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(height: 40),
                    Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[100]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            MyFormField(
                              label: "Email",
                              hint: 'Entrez votre adresse e-mail',
                              borderColor: Colors.black,
                              labelColor: Colors.black,
                              activeBorderColor: Colors.black,
                              hintColor: Colors.grey,
                              controller: emailController,
                              inputType: TextInputType.emailAddress,
                              validator: Validator().required().email().make(),
                            ),
                            SizedBox(height: 20),
                            MyFormField(
                              label: "Mot de passe",
                              hint: 'Entrez votre mot de passe',
                              borderColor: Colors.black,
                              labelColor: Colors.black,
                              activeBorderColor: Colors.black,
                              hintColor: Colors.grey,
                              openEyeIcon: const Icon(
                                Icons.remove_red_eye_outlined,
                                color: Colors.black,
                              ),
                              closeEyeIcon: const Icon(
                                FontAwesomeIcons.eyeSlash,
                                color: Colors.black,
                              ),
                              isPassWord: true,
                              controller: passwordController,
                              validator: Validator().required().make(),
                            ),
                            SizedBox(height: 30),
                            MyCustomButton(
                              name: "Se connecter",
                              onClick: _handleLogin,
                              color: AppColors.primaryColor,
                              textColor: Colors.white,
                              height: 50,
                              borderRadius: 12,
                              fontSize: 16,
                              isLoading: state.loginStatus==AppStatus.loading,
                            ),
                            SizedBox(height: 12),
                            TextButton(
                              onPressed: () => GoRouter.of(context)
                                  .push(Routes.forgotPassword),
                              child: Text(
                                "Mot de passe oublie ?",
                                style: TextStyle(
                                  color: AppColors.primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }



  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      final manager = Manager(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      BlocProvider.of<LoginBloc>(context).add(LoginSubmitted(manager));
    }
  }

  void listener(BuildContext context, LoginState state) {
    if(state.loginStatus==AppStatus.error){
      showToast(state.error??"Error", context,type: ToastificationType.error );
    }else if(state.loginStatus==AppStatus.success){
      showToast(AppStrings.success, context,type: ToastificationType.success,second: 2,whenComplete: (){
        while(GoRouter.of(context).canPop()){
          GoRouter.of(context).pop();
        }
        GoRouter.of(context).replace(Routes.initialiser);
      });
    }
  }
}
