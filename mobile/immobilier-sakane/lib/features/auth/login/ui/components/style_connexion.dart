import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/services/service_biometrie.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/compte_memorise.dart';

/// La charte de l'ecran de connexion : un fond clair, une carte blanche
/// posee dessus, des coins tres arrondis, et la couleur de l'agence pour
/// tout ce sur quoi on appuie.
///
/// Les valeurs sont reunies ici pour que l'ecran tienne d'un seul regard,
/// et pour que la feuille des comptes et la carte parlent la meme langue.
///
/// Les teintes viennent de la charte de l'accueil : la connexion et
/// l'accueil ne doivent pas avoir l'air de deux applications.
const Color fondConnexion = fondAccueil;
const Color bordureConnexion = bordureAccueil;
const Color texteConnexion = texteAccueil;
const Color texteDouxConnexion = texteDouxAccueil;

/// L'ombre de la carte : elle la decolle du fond sans se montrer.
const List<BoxShadow> ombreConnexion = [
  BoxShadow(color: Color(0x1417262E), blurRadius: 24, offset: Offset(0, 8)),
];

const double rayonCarteConnexion = 24;
const double rayonChampConnexion = 12;

/// La carte blanche de la connexion.
class CarteConnexion extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CarteConnexion({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 22),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: bordureConnexion),
        borderRadius: BorderRadius.circular(rayonCarteConnexion),
        boxShadow: ombreConnexion,
      ),
      child: child,
    );
  }
}

/// La pastille d'un compte : ses initiales sur sa couleur.
///
/// Elle remplace la photo que le serveur ne fournit pas, et suffit a
/// reconnaitre d'un coup d'oeil sur quel compte on est.
class AvatarCompte extends StatelessWidget {
  final CompteMemorise compte;
  final double diametre;

  const AvatarCompte({super.key, required this.compte, this.diametre = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diametre,
      height: diametre,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: compte.couleur,
        boxShadow: [
          BoxShadow(
            color: compte.couleur.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        compte.initiales,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: diametre * 0.36,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Un bouton rond : une icone, un cercle, rien d'autre.
class BoutonRondConnexion extends StatelessWidget {
  final Widget child;
  final String libelle;
  final VoidCallback? onTap;
  final double diametre;
  final Color fond;
  final Color? bordure;

  const BoutonRondConnexion({
    super.key,
    required this.child,
    required this.libelle,
    this.onTap,
    this.diametre = 40,
    this.fond = Colors.white,
    this.bordure = bordureConnexion,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: libelle,
      child: Semantics(
        button: true,
        label: libelle,
        child: Material(
          color: fond,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: diametre,
              height: diametre,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: bordure == null
                    ? null
                    : Border.fromBorderSide(BorderSide(color: bordure!)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Deux silhouettes et une fleche qui tourne : « ce n'est pas moi,
/// changeons de compte ».
class IconeChangerCompte extends StatelessWidget {
  final Color couleur;
  final double taille;

  const IconeChangerCompte({
    super.key,
    this.couleur = texteConnexion,
    this.taille = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Icon(Icons.people_alt_outlined, size: taille, color: couleur),
          ),
          Positioned(
            right: -2,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.autorenew_rounded,
                size: taille * 0.55,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un trait, le mot « Ou », un trait. Il annonce qu'il existe une autre
/// facon d'entrer que le mot de passe.
class SeparateurOu extends StatelessWidget {
  const SeparateurOu({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: bordureConnexion, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Ou',
            style: GoogleFonts.poppins(
              color: texteDouxConnexion,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: bordureConnexion, height: 1)),
      ],
    );
  }
}

/// L'icone qui correspond a ce que l'appareil sait reconnaitre : un
/// visage, une empreinte, ou un cadenas quand il ne le dit pas.
extension ApparenceBiometrie on TypeBiometrie {
  IconData get icone {
    switch (this) {
      case TypeBiometrie.visage:
        return Icons.face_rounded;
      case TypeBiometrie.empreinte:
        return Icons.fingerprint_rounded;
      case TypeBiometrie.generique:
      case TypeBiometrie.aucune:
        return Icons.lock_open_rounded;
    }
  }
}
