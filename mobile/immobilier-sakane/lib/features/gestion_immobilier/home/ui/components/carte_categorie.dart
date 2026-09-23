import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// Une pastille d'état : « 24 disponibles ». Elle porte la teinte de son
/// état et ouvre la liste déjà filtrée.
///
/// [onTap] nul : la pastille reste lisible mais n'ouvre rien (l'état
/// « Aucun bien », ou un module que l'utilisateur ne peut pas voir).
class EtatPastille {
  final String libelle;
  final int? nombre;
  final Color teinte;
  final VoidCallback? onTap;

  const EtatPastille({
    required this.libelle,
    required this.teinte,
    this.nombre,
    this.onTap,
  });
}

/// La carte d'une famille de biens : son icône, son nom, son nombre, ses
/// états, et le lien qui ouvre la famille.
///
/// Le nombre à null dit que le compteur n'a pas pu être lu : la carte
/// s'affiche quand même, et la catégorie s'ouvre comme d'habitude.
class CarteCategorie extends StatelessWidget {
  final String titre;
  final String detail;
  final IconData icone;
  final Color teinte;
  final int? nombre;
  final List<EtatPastille> pastilles;
  final VoidCallback onOuvrir;

  const CarteCategorie({
    super.key,
    required this.titre,
    required this.detail,
    required this.icone,
    required this.teinte,
    required this.onOuvrir,
    this.nombre,
    this.pastilles = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CarteAccueil(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: teinte.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icone, size: 22, color: teinte),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          color: texteAccueil,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: texteDouxAccueil,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (nombre != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$nombre',
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          color: texteAccueil,
                          fontFeatures: chiffresTabulaires,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nombre == 1 ? 'bien' : 'biens',
                        style: const TextStyle(
                          fontSize: 11,
                          color: texteDouxAccueil,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (pastilles.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pastilles.map(_Pastille.new).toList(),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: bordureAccueil),
            InkWell(
              onTap: onOuvrir,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
                child: Row(
                  children: [
                    Text(
                      'Ouvrir cette catégorie',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded,
                        size: 19, color: AppColors.primaryColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le dessin d'une pastille : fond teinté clair, texte de la teinte,
/// bords pleinement arrondis.
class _Pastille extends StatelessWidget {
  final EtatPastille etat;

  const _Pastille(this.etat);

  @override
  Widget build(BuildContext context) {
    final libelle =
        etat.nombre == null ? etat.libelle : '${etat.nombre} ${etat.libelle}';
    final corps = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: etat.teinte.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: etat.teinte,
          fontFeatures: chiffresTabulaires,
        ),
      ),
    );

    if (etat.onTap == null) return corps;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        onTap: etat.onTap,
        borderRadius: BorderRadius.circular(100),
        child: corps,
      ),
    );
  }
}

/// L'esquisse d'une carte de catégorie, le temps de la lecture.
class SqueletteCarteCategorie extends StatelessWidget {
  const SqueletteCarteCategorie({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: CarteAccueil(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocSquelette(hauteur: 46, largeur: 46, rayon: 12),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlocSquelette(hauteur: 13, largeur: 150),
                      SizedBox(height: 8),
                      BlocSquelette(hauteur: 11, largeur: 110),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                BlocSquelette(hauteur: 30, largeur: 42, rayon: 8),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                BlocSquelette(hauteur: 26, largeur: 96, rayon: 100),
                SizedBox(width: 8),
                BlocSquelette(hauteur: 26, largeur: 82, rayon: 100),
              ],
            ),
            SizedBox(height: 16),
            Divider(height: 1, color: bordureAccueil),
            SizedBox(height: 14),
            BlocSquelette(hauteur: 12, largeur: 140),
          ],
        ),
      ),
    );
  }
}
