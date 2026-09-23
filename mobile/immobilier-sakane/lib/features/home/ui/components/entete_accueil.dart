import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// L'en-tête de l'accueil : qui est là, quel jour, quelle agence.
///
/// Plus de bandeau coloré : le nom de l'agent et la date suffisent à
/// situer l'écran, et l'œil descend directement sur la caisse. Les deux
/// actions qui restent en haut sont rondes et bordées, pour ne pas
/// concurrencer les chiffres.
class EnteteAccueil extends StatelessWidget {
  /// Le prénom, tel que le serveur le donne ; à défaut, celui du compte.
  final String prenom;

  /// « Agence Sakane ». Vide : la ligne ne porte que la date.
  final String agence;

  /// La date du serveur, qui fait foi pour « aujourd'hui ». Nulle avant
  /// la réponse : on prend celle du téléphone plutôt que rien.
  final DateTime? date;

  /// Ouvre la réception WhatsApp ; nul : l'utilisateur n'y a pas droit.
  final VoidCallback? onWhatsapp;

  /// Le mode personnalisation, proposé dans le menu comme dans la
  /// section « Modules ».
  final VoidCallback onPersonnaliser;

  const EnteteAccueil({
    super.key,
    required this.prenom,
    required this.agence,
    required this.date,
    required this.onPersonnaliser,
    this.onWhatsapp,
  });

  String get _initiale {
    final propre = prenom.trim();
    return propre.isEmpty ? '?' : propre[0].toUpperCase();
  }

  Future<void> _menu(BuildContext context) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DDE2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined,
                  color: texteAccueil),
              title: const Text("Personnaliser l'accueil",
                  style: TextStyle(fontSize: 15, color: texteAccueil)),
              onTap: () => Navigator.of(feuille).pop('personnaliser'),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: rougeAccueil),
              title: const Text('Se déconnecter',
                  style: TextStyle(fontSize: 15, color: rougeAccueil)),
              onTap: () => Navigator.of(feuille).pop('deconnexion'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (choix == 'personnaliser') {
      onPersonnaliser();
    } else if (choix == 'deconnexion') {
      await demanderDeconnexion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final marque = AppColors.primaryColor;
    final quand = date ?? DateTime.now();
    final sousTitre =
        agence.trim().isEmpty ? jourEtDate(quand) : '${jourEtDate(quand)} · ${agence.trim()}';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 14, 16, 14),
      child: Row(
        children: [
          // Un appui long sur l'initiale ouvre le même menu : la
          // déconnexion reste à portée sans occuper l'écran.
          GestureDetector(
            onLongPress: () => _menu(context),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: marque.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Text(
                _initiale,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: marque,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour, ${prenom.trim().isEmpty ? 'vous' : prenom.trim()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: texteAccueil,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: texteDouxAccueil,
                    fontFeatures: chiffresTabulaires,
                  ),
                ),
              ],
            ),
          ),
          if (onWhatsapp != null) ...[
            const SizedBox(width: 8),
            BoutonRondAccueil(
              icone: FontAwesomeIcons.commentDots,
              libelle: 'Réception WhatsApp',
              onTap: onWhatsapp!,
            ),
          ],
          const SizedBox(width: 8),
          BoutonRondAccueil(
            icone: Icons.more_horiz,
            libelle: 'Menu',
            teinte: texteDouxAccueil,
            onTap: () => _menu(context),
          ),
        ],
      ),
    );
  }
}
