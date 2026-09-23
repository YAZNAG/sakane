import 'package:flutter/material.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// Un chiffre du jour : le nombre, ce qu'il compte, et l'écran qui le
/// détaille.
class TuileJour {
  final int nombre;
  final String libelle;
  final Color teinte;
  final VoidCallback onTap;

  const TuileJour({
    required this.nombre,
    required this.libelle,
    required this.teinte,
    required this.onTap,
  });
}

/// La rangée « Aujourd'hui » : quatre chiffres, quatre écrans.
///
/// Elle défile horizontalement plutôt que de se comprimer : sur un
/// téléphone étroit, un chiffre réduit ne se lit plus, alors qu'un
/// chiffre hors champ se retrouve d'un geste.
class TuilesAujourdhui extends StatelessWidget {
  final List<TuileJour> tuiles;

  const TuilesAujourdhui({super.key, required this.tuiles});

  @override
  Widget build(BuildContext context) {
    if (tuiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tuiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _Tuile(tuile: tuiles[i]),
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  final TuileJour tuile;

  const _Tuile({required this.tuile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: InkWell(
        onTap: tuile.onTap,
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: Container(
          width: 92,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            border: Border.all(color: bordureAccueil),
            borderRadius: BorderRadius.circular(rayonAccueil),
            boxShadow: ombreAccueil,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tuile.nombre}',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.05,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -.5,
                  color: tuile.teinte,
                  fontFeatures: chiffresTabulaires,
                ),
              ),
              Text(
                tuile.libelle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: texteDouxAccueil,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
