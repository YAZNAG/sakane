import 'package:flutter/material.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// Les pièces de la fiche « Gestion du bien » : la photo de tête et ses
/// boutons flottants, la carte d'identité qui la chevauche, les tuiles
/// de la grille, et leurs esquisses de chargement.
///
/// Elles suivent la charte de l'accueil — fond clair, cartes blanches,
/// bordure fine, ombre discrète — et se contentent des 375 px d'un
/// téléphone étroit.

/// La photo principale du bien, avec ses boutons ronds flottants.
///
/// Sans photo, un aplat gris et une icône : la page garde sa forme, elle
/// ne se replie pas sur un vide.
class PhotoDeTete extends StatelessWidget {
  final String? url;

  /// Nombre total de photos : le badge « 1 / 8 » le dit, et l'appui
  /// ouvre la galerie.
  final int nbPhotos;

  final VoidCallback? onOuvrirGalerie;
  final VoidCallback onRetour;

  /// Null : le partage n'est pas proposé (droit manquant, fiche non lue).
  final VoidCallback? onPartager;

  final double hauteur;

  const PhotoDeTete({
    super.key,
    this.url,
    this.nbPhotos = 0,
    this.onOuvrirGalerie,
    required this.onRetour,
    this.onPartager,
    this.hauteur = 240,
  });

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    final adresse = (url ?? '').trim();

    return SizedBox(
      height: hauteur + haut,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: adresse.isEmpty ? null : onOuvrirGalerie,
            child: adresse.isEmpty
                ? const _PhotoAbsente()
                : Image.network(
                    adresse,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _PhotoAbsente(),
                    loadingBuilder: (_, enfant, avancement) =>
                        avancement == null ? enfant : const _PhotoEnCours(),
                  ),
          ),
          // Un voile en haut : les boutons blancs restent lisibles même
          // sur une photo claire.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x40000000), Color(0x00000000)],
                  stops: [0, .45],
                ),
              ),
            ),
          ),
          Positioned(
            top: haut + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                BoutonRondAccueil(
                  icone: Icons.arrow_back,
                  libelle: 'Retour',
                  onTap: onRetour,
                ),
                const Spacer(),
                if (onPartager != null)
                  BoutonRondAccueil(
                    icone: Icons.share_outlined,
                    libelle: 'Partager la fiche',
                    onTap: onPartager!,
                  ),
              ],
            ),
          ),
          if (nbPhotos > 0)
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: onOuvrirGalerie,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xB317262E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '1 / $nbPhotos',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: chiffresTabulaires,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoAbsente extends StatelessWidget {
  const _PhotoAbsente();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7ECEF),
      alignment: Alignment.center,
      child: const Icon(Icons.home_work_outlined,
          size: 56, color: Color(0xFFA9B6BD)),
    );
  }
}

class _PhotoEnCours extends StatelessWidget {
  const _PhotoEnCours();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFE7ECEF),
        child: SizedBox.expand(),
      );
}

/// Le titre en petites majuscules d'une carte : « AUJOURD'HUI »,
/// « RÉF. AG-1042 · 3E ÉTAGE ».
class SurTitre extends StatelessWidget {
  final String texte;

  const SurTitre(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .9,
        color: texteDouxAccueil,
        fontFeatures: chiffresTabulaires,
      ),
    );
  }
}

/// Une tuile de la grille 2×2 : une icône teintée, un titre, une ligne
/// de précision. Le point de couleur signale une liaison (Airbnb).
class TuileBien extends StatelessWidget {
  final IconData? icone;

  /// Remplace [icone] quand la marque a son propre pictogramme.
  final Widget? pictogramme;

  final String titre;
  final String sousTitre;
  final Color teinte;

  /// Point de couleur à droite du titre ; null : rien.
  final Color? pastille;

  final VoidCallback onTap;

  const TuileBien({
    super.key,
    this.icone,
    this.pictogramme,
    required this.titre,
    required this.sousTitre,
    required this.teinte,
    this.pastille,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: BoxDecoration(
            border: Border.all(color: bordureAccueil),
            borderRadius: BorderRadius.circular(rayonAccueil),
            boxShadow: ombreAccueil,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: teinte.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: pictogramme ?? Icon(icone, size: 19, color: teinte),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: texteAccueil,
                      ),
                    ),
                  ),
                  if (pastille != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: pastille, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                sousTitre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, height: 1.25, color: texteDouxAccueil),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'esquisse de la fiche, le temps de la première lecture.
class SqueletteFicheBien extends StatelessWidget {
  final double hauteurPhoto;

  const SqueletteFicheBien({super.key, this.hauteurPhoto = 240});

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(height: hauteurPhoto + haut, color: const Color(0xFFE7ECEF)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              CarteAccueil(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocSquelette(hauteur: 10, largeur: 140),
                    SizedBox(height: 10),
                    BlocSquelette(hauteur: 20, largeur: 210, rayon: 7),
                    SizedBox(height: 9),
                    BlocSquelette(hauteur: 12, largeur: 160),
                  ],
                ),
              ),
              SizedBox(height: 14),
              CarteAccueil(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BlocSquelette(hauteur: 10, largeur: 90),
                        Spacer(),
                        BlocSquelette(hauteur: 22, largeur: 84, rayon: 11),
                      ],
                    ),
                    SizedBox(height: 12),
                    BlocSquelette(hauteur: 12, largeur: 200),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: BlocSquelette(hauteur: 42, rayon: 12)),
                        SizedBox(width: 10),
                        Expanded(child: BlocSquelette(hauteur: 42, rayon: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: BlocSquelette(hauteur: 122, rayon: 16)),
                  SizedBox(width: 12),
                  Expanded(child: BlocSquelette(hauteur: 122, rayon: 16)),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: BlocSquelette(hauteur: 122, rayon: 16)),
                  SizedBox(width: 12),
                  Expanded(child: BlocSquelette(hauteur: 122, rayon: 16)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
