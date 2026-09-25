import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/models/compte_memorise.dart';

import 'style_connexion.dart';

/// Ce que l'utilisateur a choisi dans la feuille des comptes : un compte
/// deja connu, ou bien le formulaire complet pour en utiliser un autre.
class ChoixCompte {
  final CompteMemorise? compte;
  final bool autreCompte;

  const ChoixCompte.existant(this.compte) : autreCompte = false;

  const ChoixCompte.autre() : compte = null, autreCompte = true;
}

/// La feuille « changer de compte ».
///
/// Elle liste les comptes deja utilises sur cet appareil, avec la date de
/// leur derniere connexion, et laisse oublier celui qui n'a plus rien a
/// faire la. La derniere entree ouvre le formulaire complet.
///
/// [onOublier] fait le vrai travail (retirer le compte, effacer son jeton) ;
/// la feuille se contente de retirer la ligne pour que l'effet soit visible
/// tout de suite.
Future<ChoixCompte?> choisirCompte(
  BuildContext context, {
  required List<CompteMemorise> comptes,
  required Future<void> Function(CompteMemorise) onOublier,
  String? cleCompteAffiche,
}) {
  return showModalBottomSheet<ChoixCompte>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(rayonCarteConnexion),
      ),
    ),
    builder: (_) => _FeuilleComptes(
      comptes: comptes,
      onOublier: onOublier,
      cleCompteAffiche: cleCompteAffiche,
    ),
  );
}

class _FeuilleComptes extends StatefulWidget {
  final List<CompteMemorise> comptes;
  final Future<void> Function(CompteMemorise) onOublier;
  final String? cleCompteAffiche;

  const _FeuilleComptes({
    required this.comptes,
    required this.onOublier,
    this.cleCompteAffiche,
  });

  @override
  State<_FeuilleComptes> createState() => _FeuilleComptesState();
}

class _FeuilleComptesState extends State<_FeuilleComptes> {
  late List<CompteMemorise> _comptes;

  @override
  void initState() {
    super.initState();
    _comptes = List<CompteMemorise>.from(widget.comptes);
  }

  @override
  Widget build(BuildContext context) {
    // La feuille ne depasse jamais les trois quarts de l'ecran : la carte
    // de connexion reste visible derriere, et la liste defile.
    final hauteurMax = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: hauteurMax),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: bordureConnexion,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choisir un compte',
                      style: GoogleFonts.poppins(
                        color: texteConnexion,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final compte in _comptes) _ligne(compte),
                  const Divider(
                    color: bordureConnexion,
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  _ligneAutreCompte(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligne(CompteMemorise compte) {
    final affiche = widget.cleCompteAffiche != null &&
        widget.cleCompteAffiche == compte.cle;

    return ListTile(
      onTap: () => Navigator.of(context).pop(ChoixCompte.existant(compte)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: AvatarCompte(compte: compte, diametre: 44),
      title: Row(
        children: [
          Flexible(
            child: Text(
              compte.nomComplet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: texteConnexion,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (affiche)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: AppColors.primaryColor,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            compte.identifiant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: texteDouxConnexion,
              fontSize: 12.5,
            ),
          ),
          Text(
            'Dernière connexion ${compte.derniereConnexionLisible}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: texteDouxConnexion,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Options du compte',
        icon: const Icon(Icons.more_vert, size: 20, color: texteDouxConnexion),
        onSelected: (valeur) {
          if (valeur == 'oublier') _oublier(compte);
        },
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
            value: 'oublier',
            child: Row(
              children: [
                Icon(Icons.person_remove_outlined, size: 18),
                SizedBox(width: 10),
                Text('Oublier ce compte'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneAutreCompte() {
    return ListTile(
      onTap: () => Navigator.of(context).pop(const ChoixCompte.autre()),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryColor.withValues(alpha: 0.10),
        ),
        child: Icon(
          Icons.person_add_alt_1_outlined,
          size: 20,
          color: AppColors.primaryColor,
        ),
      ),
      title: Text(
        'Utiliser un autre compte',
        style: GoogleFonts.poppins(
          color: texteConnexion,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Email ou téléphone, et mot de passe',
        style: GoogleFonts.poppins(
          color: texteDouxConnexion,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Future<void> _oublier(CompteMemorise compte) async {
    await widget.onOublier(compte);
    if (!mounted) return;
    setState(() => _comptes.removeWhere((c) => c.cle == compte.cle));
    // Plus aucun compte a proposer : la feuille n'a plus de raison d'etre
    // ouverte, l'ecran repart sur le formulaire complet.
    if (_comptes.isEmpty && mounted) {
      Navigator.of(context).pop(const ChoixCompte.autre());
    }
  }
}
