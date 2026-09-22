import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/custom_button.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Reinitialisation du mot de passe en trois etapes :
///   1. saisie de l'e-mail  -> un code est envoye par WhatsApp
///   2. saisie du code recu
///   3. saisie du nouveau mot de passe
class ForgotPasswordPage extends StatefulWidget {
  static Widget page() => const ForgotPasswordPage();

  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final GlobalKey<FormState> _emailKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordKey = GlobalKey<FormState>();

  int _etape = 0;
  String _otp = "";
  String _telMasque = "";
  bool _enCours = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Repository get _repo => Dependencies.get<Repository>();

  void _erreur(String message) {
    setState(() => _enCours = false);
    showToast(message, context, type: ToastificationType.error);
  }

  String _premiereErreur(ValidatorException ex) {
    final valeurs = ex.errors?.values;
    if (valeurs == null || valeurs.isEmpty) return "Donnees invalides";
    final v = valeurs.first;
    if (v is List && v.isNotEmpty) return v.first.toString();
    return v.toString();
  }

  // ------------------------------------------------ etape 1 : envoi du code
  Future<void> _envoyerCode() async {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    setState(() => _enCours = true);
    try {
      final tel = await _repo.forgetPassword(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _telMasque = tel;
        _etape = 1;
        _enCours = false;
      });
      showToast(
        tel.isEmpty
            ? "Un code vous a ete envoye par WhatsApp"
            : "Code envoye par WhatsApp au $tel",
        context,
        type: ToastificationType.success,
      );
    } on NetworkConnectivityException {
      _erreur("Verifiez votre connexion reseau");
    } on ValidatorException catch (ex) {
      _erreur(_premiereErreur(ex));
    } catch (_) {
      _erreur("Envoi impossible. Contactez un administrateur.");
    }
  }

  // ------------------------------------------------ etape 2 : verification
  Future<void> _verifierCode(String code) async {
    setState(() => _enCours = true);
    try {
      await _repo.checkOtp(_emailController.text.trim(), code);
      if (!mounted) return;
      setState(() {
        _otp = code;
        _etape = 2;
        _enCours = false;
      });
    } on NetworkConnectivityException {
      _erreur("Verifiez votre connexion reseau");
    } on ValidatorException {
      _erreur("Code invalide ou expire");
    } catch (_) {
      _erreur("Verification impossible");
    }
  }

  // ------------------------------------------------ etape 3 : nouveau mdp
  Future<void> _enregistrer() async {
    if (!(_passwordKey.currentState?.validate() ?? false)) return;
    if (_passwordController.text != _confirmController.text) {
      _erreur("Les deux mots de passe ne correspondent pas");
      return;
    }
    setState(() => _enCours = true);
    try {
      await _repo.resetPassword(
        _emailController.text.trim(),
        _otp,
        _passwordController.text,
        _confirmController.text,
      );
      if (!mounted) return;
      setState(() => _enCours = false);
      showToast("Mot de passe modifie avec succes", context,
          type: ToastificationType.success);
      GoRouter.of(context).replace(Routes.login);
    } on NetworkConnectivityException {
      _erreur("Verifiez votre connexion reseau");
    } on ValidatorException catch (ex) {
      _erreur(_premiereErreur(ex));
    } catch (_) {
      _erreur("Modification impossible");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Mot de passe oublie",
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _indicateurEtapes(),
              const SizedBox(height: 28),
              if (_etape == 0) _formulaireEmail(),
              if (_etape == 1) _formulaireCode(),
              if (_etape == 2) _formulaireMotDePasse(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicateurEtapes() {
    return Row(
      children: List.generate(3, (i) {
        final actif = i <= _etape;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: actif ? AppColors.primaryColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _formulaireEmail() {
    return Form(
      key: _emailKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Saisissez votre adresse e-mail. Un code de verification vous sera "
            "envoye par WhatsApp sur le numero associe a votre compte.",
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 24),
          MyFormField(
            label: "Email",
            hint: "Entrez votre adresse e-mail",
            borderColor: Colors.black,
            labelColor: Colors.black,
            activeBorderColor: Colors.black,
            hintColor: Colors.grey,
            controller: _emailController,
            inputType: TextInputType.emailAddress,
            validator: Validator().required().email().make(),
          ),
          const SizedBox(height: 30),
          MyCustomButton(
            name: _enCours ? "Envoi en cours..." : "Envoyer le code",
            onClick: _enCours ? null : _envoyerCode,
            color: AppColors.primaryColor,
            textColor: Colors.white,
            height: 50,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }

  Widget _formulaireCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _telMasque.isEmpty
              ? "Saisissez le code recu par WhatsApp."
              : "Saisissez le code envoye par WhatsApp au $_telMasque.",
          style:
              const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        const SizedBox(height: 24),
        Center(
          child: OtpTextField(
            numberOfFields: 5,
            borderColor: AppColors.primaryColor,
            focusedBorderColor: AppColors.primaryColor,
            showFieldAsBox: true,
            fieldWidth: 48,
            onSubmit: (code) {
              if (!_enCours) _verifierCode(code);
            },
          ),
        ),
        const SizedBox(height: 24),
        if (_enCours) const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _enCours ? null : _envoyerCode,
          child: Text(
            "Renvoyer le code",
            style: TextStyle(color: AppColors.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _formulaireMotDePasse() {
    return Form(
      key: _passwordKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Choisissez un nouveau mot de passe (6 caracteres minimum).",
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 24),
          MyFormField(
            label: "Nouveau mot de passe",
            hint: "Entrez le nouveau mot de passe",
            borderColor: Colors.black,
            labelColor: Colors.black,
            activeBorderColor: Colors.black,
            hintColor: Colors.grey,
            openEyeIcon: const Icon(Icons.remove_red_eye_outlined,
                color: Colors.black),
            closeEyeIcon:
                const Icon(FontAwesomeIcons.eyeSlash, color: Colors.black),
            isPassWord: true,
            controller: _passwordController,
            validator: Validator().required().min(6).make(),
          ),
          const SizedBox(height: 20),
          MyFormField(
            label: "Confirmer le mot de passe",
            hint: "Confirmez le nouveau mot de passe",
            borderColor: Colors.black,
            labelColor: Colors.black,
            activeBorderColor: Colors.black,
            hintColor: Colors.grey,
            openEyeIcon: const Icon(Icons.remove_red_eye_outlined,
                color: Colors.black),
            closeEyeIcon:
                const Icon(FontAwesomeIcons.eyeSlash, color: Colors.black),
            isPassWord: true,
            controller: _confirmController,
            validator: Validator().required().make(),
          ),
          const SizedBox(height: 30),
          MyCustomButton(
            name: _enCours ? "Enregistrement..." : "Enregistrer",
            onClick: _enCours ? null : _enregistrer,
            color: AppColors.primaryColor,
            textColor: Colors.white,
            height: 50,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }
}
