import 'package:flutter/material.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/apparence_dossier.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// Une tuile de la grille des dossiers.
///
/// Elle dit trois choses, dans cet ordre : de quel dossier il s'agit
/// (l'icône et le nom), ce qu'il contient, et qui y a accès. Le menu ⋮
/// reste discret : on ouvre un dossier bien plus souvent qu'on ne le
/// renomme.
class CarteDossier extends StatelessWidget {
  /// Null pour « Hors dossier » : la tuile passe alors en gris.
  final int? dossierId;

  final String nom;
  final int nombreBiens;

  /// Nombre d'agents autorisés. Zéro signifie « toute l'équipe ».
  final int nombreAgents;

  /// Tuile grise, en fin de grille : les biens qu'on n'a pas encore rangés.
  final bool horsDossier;

  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  const CarteDossier({
    super.key,
    this.dossierId,
    required this.nom,
    required this.nombreBiens,
    this.nombreAgents = 0,
    this.horsDossier = false,
    this.onTap,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final apparence = horsDossier
        ? const ApparenceDossier(
            icone: Icons.inbox_outlined, couleur: texteDouxAccueil)
        : ApparencesDossiers.de(dossierId);

    final sousTitre = horsDossier
        ? '$nombreBiens bien${nombreBiens > 1 ? 's' : ''}'
        : '$nombreBiens bien${nombreBiens > 1 ? 's' : ''} · '
            '${nombreAgents == 0 ? "toute l'équipe" : '$nombreAgents agent${nombreAgents > 1 ? 's' : ''}'}';

    return Material(
      color: horsDossier ? const Color(0xFFF0F3F5) : Colors.white,
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          decoration: BoxDecoration(
            border: Border.all(color: bordureAccueil),
            borderRadius: BorderRadius.circular(rayonAccueil),
            boxShadow: horsDossier ? null : ombreAccueil,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: apparence.couleur.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(apparence.icone,
                        size: 21, color: apparence.couleur),
                  ),
                  const Spacer(),
                  if (onMenu != null)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        onPressed: onMenu,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Actions du dossier',
                        icon: const Icon(Icons.more_vert,
                            size: 19, color: texteDouxAccueil),
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: texteAccueil,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: texteDouxAccueil,
                    fontFeatures: chiffresTabulaires,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
