import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_images.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/services/comptes_memorises_service.dart';
import 'package:immobilier/core/services/service_biometrie.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/auth/login/bloc/login_bloc.dart';
import 'package:immobilier/core/validator/validator.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/compte_memorise.dart';
import 'package:toastification/toastification.dart';
import '../../../../models/manager.dart';

import '../../../../components/custom_button.dart';
import '../../../../components/form_field.dart';
import '../../../../routes.dart';
import 'components/feuille_comptes.dart';
import 'components/style_connexion.dart';

/// L'ecran de connexion.
///
/// Il s'ouvre sur le dernier compte utilise : sa pastille, son prenom, et
/// un seul champ a remplir. Le formulaire complet — identifiant et mot de
/// passe — n'apparait que la premiere fois, ou quand on demande
/// explicitement un autre compte.
class LoginPage extends StatefulWidget {
  static Widget page() =>
      BlocProvider(create: (context) => LoginBloc(), child: const LoginPage());

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController identifiantController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final ComptesMemorisesService _comptesService;

  List<CompteMemorise> _comptes = const [];
  CompteMemorise? _compteActif;

  /// Vrai quand l'identifiant doit etre saisi : aucun compte memorise, ou
  /// « utiliser un autre compte ».
  bool _formulaireComplet = true;

  TypeBiometrie _typeBio = TypeBiometrie.aucune;
  bool _jetonPresent = false;
  bool _controleBioEnCours = false;
  bool _motDePasseRempli = false;

  @override
  void initState() {
    super.initState();
    _comptesService = ComptesMemorisesService();
    _comptes = _comptesService.lire();
    _compteActif = _comptes.isEmpty ? null : _comptes.first;
    _formulaireComplet = _compteActif == null;
    identifiantController.text = _compteActif?.identifiant ?? "";
    _preparerBiometrie();
  }

  @override
  void dispose() {
    identifiantController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Le bouton de deverrouillage n'existe que si l'appareil sait reconnaitre
  /// son porteur ET qu'un jeton attend pour le compte affiche. Sans les deux,
  /// il ouvrirait une fenetre qui ne mene a rien.
  bool get _biometrieProposable =>
      !_formulaireComplet &&
      _compteActif != null &&
      _typeBio != TypeBiometrie.aucune &&
      _jetonPresent;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginBloc, LoginState>(
      listener: listener,
      builder: (context, state) {
        final enCours = state.loginStatus == AppStatus.loading;
        return Scaffold(
          backgroundColor: fondConnexion,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, contraintes) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    // La carte se centre quand il y a de la place, et l'ecran
                    // defile quand le clavier prend la moitie de la hauteur.
                    constraints:
                        BoxConstraints(minHeight: contraintes.maxHeight - 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(AppImages.app_logo, height: 96),
                        const SizedBox(height: 18),
                        Form(key: _formKey, child: _carte(enCours)),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _carte(bool enCours) {
    return CarteConnexion(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _entete(),
          if (_formulaireComplet) ..._formulaireIdentifiant() else ..._accueil(),
          MyFormField(
            label: "Mot de passe",
            hint: 'Entrez votre mot de passe',
            borderColor: bordureConnexion,
            labelColor: texteConnexion,
            activeBorderColor: AppColors.primaryColor,
            hintColor: texteDouxConnexion,
            fillColor: Colors.white,
            isWithBorder: true,
            borderRadius: rayonChampConnexion,
            fontSizeLabel: 13.5,
            fontSizeHint: 13,
            openEyeIcon: const Icon(
              Icons.remove_red_eye_outlined,
              color: texteDouxConnexion,
            ),
            closeEyeIcon: const Icon(
              FontAwesomeIcons.eyeSlash,
              size: 18,
              color: texteDouxConnexion,
            ),
            isPassWord: true,
            controller: passwordController,
            onChange: (valeur) {
              final rempli = valeur.trim().isNotEmpty;
              if (rempli != _motDePasseRempli) {
                setState(() => _motDePasseRempli = rempli);
              }
            },
            validator: Validator().required().make(),
          ),
          const SizedBox(height: 22),
          MyCustomButton(
            name: "Connexion",
            onClick: _handleLogin,
            // Tant que le mot de passe est vide, le bouton reste la mais ne
            // fait rien : la maquette le veut visible, pas trompeur.
            color: _motDePasseRempli
                ? AppColors.primaryColor
                : AppColors.primaryColor.withValues(alpha: 0.35),
            textColor: Colors.white,
            height: 50,
            borderRadius: rayonChampConnexion,
            fontSize: 16,
            elevation: 0,
            horizontalMargin: 0,
            isDisabled: !_motDePasseRempli,
            isLoading: enCours,
          ),
          if (_biometrieProposable) ..._blocBiometrie(enCours),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: () => GoRouter.of(context).push(Routes.forgotPassword),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                "Identifiant ou mot de passe oublié",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.primaryColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Le bouton « changer de compte », en haut a droite de la carte. Il ne
  /// sert a rien quand aucun compte n'est memorise.
  Widget _entete() {
    if (_comptes.isEmpty) return const SizedBox(height: 6);
    return Align(
      alignment: Alignment.centerRight,
      child: BoutonRondConnexion(
        libelle: "Changer de compte",
        onTap: _ouvrirFeuilleComptes,
        child: const IconeChangerCompte(),
      ),
    );
  }

  /// « Bienvenue Ahmed » : la pastille du compte memorise et son prenom.
  List<Widget> _accueil() {
    final compte = _compteActif;
    if (compte == null) return const [SizedBox(height: 6)];
    return [
      const SizedBox(height: 6),
      Center(child: AvatarCompte(compte: compte, diametre: 72)),
      const SizedBox(height: 14),
      Center(
        child: Text(
          "Bienvenue ${compte.prenomAffiche}",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: texteConnexion,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          compte.identifiant,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: texteDouxConnexion,
            fontSize: 12.5,
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Le formulaire complet. Le champ accepte une adresse e-mail comme un
  /// numero de telephone : le serveur reconnait les deux, l'application ne
  /// doit donc plus exiger un format d'e-mail.
  List<Widget> _formulaireIdentifiant() {
    return [
      const SizedBox(height: 2),
      Center(
        child: Text(
          "Connexion",
          style: GoogleFonts.poppins(
            color: texteConnexion,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          "Entrez votre e-mail ou votre numéro de téléphone",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: texteDouxConnexion,
            fontSize: 12.5,
          ),
        ),
      ),
      const SizedBox(height: 22),
      MyFormField(
        label: "Email ou téléphone",
        hint: 'exemple@mail.com ou 06 12 34 56 78',
        borderColor: bordureConnexion,
        labelColor: texteConnexion,
        activeBorderColor: AppColors.primaryColor,
        hintColor: texteDouxConnexion,
        fillColor: Colors.white,
        isWithBorder: true,
        borderRadius: rayonChampConnexion,
        fontSizeLabel: 13.5,
        fontSizeHint: 13,
        controller: identifiantController,
        inputType: TextInputType.emailAddress,
        // Ni majuscule automatique ni correction : une adresse ou un numero
        // ne se laisse pas corriger par le clavier.
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        validator: Validator().required().make(),
      ),
      const SizedBox(height: 18),
    ];
  }

  /// Le separateur « Ou » et le bouton rond de deverrouillage.
  List<Widget> _blocBiometrie(bool enCours) {
    final libelle = ServiceBiometrie.instance.libelle(_typeBio);
    return [
      const SizedBox(height: 20),
      const SeparateurOu(),
      const SizedBox(height: 18),
      Center(
        child: BoutonRondConnexion(
          libelle: libelle,
          diametre: 58,
          fond: AppColors.primaryColor.withValues(alpha: 0.10),
          bordure: AppColors.primaryColor.withValues(alpha: 0.35),
          onTap: (enCours || _controleBioEnCours) ? null : _connexionBiometrique,
          child: _controleBioEnCours
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryColor,
                  ),
                )
              : Icon(_typeBio.icone, size: 28, color: AppColors.primaryColor),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          libelle,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: texteDouxConnexion,
            fontSize: 12,
          ),
        ),
      ),
    ];
  }

  /// Ce qui sera envoye au serveur : la saisie en mode formulaire complet,
  /// l'identifiant du compte affiche sinon.
  String get _identifiantSaisi => _formulaireComplet
      ? identifiantController.text.trim()
      : (_compteActif?.identifiant ?? identifiantController.text.trim());

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      final manager = Manager(
        // Le serveur lit ce champ comme un identifiant : e-mail ou telephone.
        email: _identifiantSaisi,
        password: passwordController.text.trim(),
      );
      BlocProvider.of<LoginBloc>(context).add(LoginSubmitted(manager));
    }
  }

  /// Relit l'etat de la biometrie pour le compte affiche.
  Future<void> _preparerBiometrie() async {
    final compte = _compteActif;
    final type = await ServiceBiometrie.instance.typeDisponible();
    final jeton = compte == null
        ? false
        : await ServiceBiometrie.instance.jetonMemorise(compte.identifiant);
    if (!mounted) return;
    setState(() {
      _typeBio = type;
      _jetonPresent = jeton;
    });
  }

  Future<void> _ouvrirFeuilleComptes() async {
    final choix = await choisirCompte(
      context,
      comptes: _comptes,
      onOublier: _oublierCompte,
      cleCompteAffiche: _compteActif?.cle,
    );
    if (!mounted || choix == null) return;

    if (choix.autreCompte) {
      setState(() {
        _formulaireComplet = true;
        _compteActif = null;
        identifiantController.clear();
        passwordController.clear();
        _motDePasseRempli = false;
        _jetonPresent = false;
      });
      return;
    }

    final compte = choix.compte;
    if (compte == null) return;
    setState(() {
      _compteActif = compte;
      _formulaireComplet = false;
      identifiantController.text = compte.identifiant;
      passwordController.clear();
      _motDePasseRempli = false;
      _jetonPresent = false;
    });
    await _preparerBiometrie();
  }

  /// Oublier un compte : il sort de la liste et son jeton de deverrouillage
  /// est detruit. Rien n'est envoye au serveur, le compte continue d'exister.
  Future<void> _oublierCompte(CompteMemorise compte) async {
    _comptesService.oublier(compte.identifiant);
    await ServiceBiometrie.instance.oublierJeton(compte.identifiant);
    final comptes = _comptesService.lire();
    if (!mounted) return;
    final etaitAffiche = _compteActif?.cle == compte.cle;
    setState(() {
      _comptes = comptes;
      if (etaitAffiche) {
        _compteActif = comptes.isEmpty ? null : comptes.first;
        _formulaireComplet = _compteActif == null;
        identifiantController.text = _compteActif?.identifiant ?? "";
        passwordController.clear();
        _motDePasseRempli = false;
        _jetonPresent = false;
      }
    });
    if (etaitAffiche) await _preparerBiometrie();
  }

  /// Le raccourci : on demande l'empreinte ou le visage, puis on presente
  /// le jeton au serveur. Un refus ou un echec ne bloque rien, le mot de
  /// passe reste juste au-dessus.
  Future<void> _connexionBiometrique() async {
    final compte = _compteActif;
    if (compte == null || _controleBioEnCours) return;

    setState(() => _controleBioEnCours = true);
    final reconnu =
        await ServiceBiometrie.instance.controler(ServiceBiometrie.instance.raison(_typeBio));
    if (!mounted) return;

    if (!reconnu) {
      setState(() => _controleBioEnCours = false);
      showToast(
        "Non reconnu. Entrez votre mot de passe.",
        context,
        type: ToastificationType.warning,
      );
      return;
    }

    final jeton = await ServiceBiometrie.instance.lireJeton(compte.identifiant);
    if (!mounted) return;
    setState(() => _controleBioEnCours = false);

    if ((jeton ?? "").trim().isEmpty) {
      setState(() => _jetonPresent = false);
      showToast(
        "Le raccourci n'est plus disponible. Entrez votre mot de passe.",
        context,
        type: ToastificationType.warning,
      );
      return;
    }

    BlocProvider.of<LoginBloc>(context).add(ConnexionParJeton(compte, jeton!));
  }

  void listener(BuildContext context, LoginState state) {
    if (state.loginStatus == AppStatus.error) {
      if (state.jetonInvalide == true) _abandonnerJeton();
      showToast(state.error ?? AppStrings.error, context,
          type: ToastificationType.error);
    } else if (state.loginStatus == AppStatus.success) {
      _apresConnexion(state);
    }
  }

  /// Le serveur a refuse le jeton : session expiree, mot de passe change, ou
  /// compte supprime. Le raccourci est detruit et le mot de passe redemande.
  void _abandonnerJeton() {
    final compte = _compteActif;
    if (compte == null) return;
    ServiceBiometrie.instance.oublierJeton(compte.identifiant);
    setState(() {
      _jetonPresent = false;
      passwordController.clear();
      _motDePasseRempli = false;
    });
  }

  Future<void> _apresConnexion(LoginState state) async {
    final compte = state.compte;
    final jeton = state.manager?.token ?? "";
    if (compte != null && jeton.isNotEmpty && state.parJeton != true) {
      await _proposerBiometrie(compte, jeton);
    }
    if (!mounted) return;
    showToast(
      AppStrings.success,
      context,
      type: ToastificationType.success,
      second: 2,
      whenComplete: () {
        while (GoRouter.of(context).canPop()) {
          GoRouter.of(context).pop();
        }
        GoRouter.of(context).replace(Routes.initialiser);
      },
    );
  }

  /// « Se connecter plus vite la prochaine fois ? » La question n'est posee
  /// qu'une seule fois par compte. Si elle est acceptee, c'est le jeton de
  /// session qui part au coffre — jamais le mot de passe.
  Future<void> _proposerBiometrie(CompteMemorise compte, String jeton) async {
    final service = ServiceBiometrie.instance;
    if (service.propositionFaite(compte.identifiant)) return;
    final type = await service.typeDisponible();
    if (type == TypeBiometrie.aucune) return;
    if (!mounted) return;

    // Marquee avant la question : si l'application est fermee pendant le
    // dialogue, elle ne redemandera pas.
    service.marquerPropositionFaite(compte.identifiant);

    final accepte = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text("Se connecter plus vite la prochaine fois ?"),
        content: Text(
          "Vous pourrez ouvrir votre session avec ${service.nomCourt(type)}, "
          "sans retaper votre mot de passe.\n\n"
          "Votre mot de passe n'est jamais enregistré sur l'appareil.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Plus tard"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Activer"),
          ),
        ],
      ),
    );
    if (accepte != true) return;
    await service.memoriserJeton(compte.identifiant, jeton);
  }
}
