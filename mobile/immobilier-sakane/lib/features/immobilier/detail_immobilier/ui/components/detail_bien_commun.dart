import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/media.dart';

/// Les pièces de la fiche « Détails du bien » : le carrousel de photos et
/// ses boutons flottants, les cartes chiffres, les puces d'équipement, la
/// mini-carte, et l'esquisse de chargement.
///
/// Elles suivent la charte de l'accueil — fond clair, cartes blanches,
/// bordure fine, ombre discrète — et tiennent dans les 375 px d'un
/// téléphone étroit.

/// Un bouton rond blanc posé sur la photo : il porte une icône et rien
/// d'autre. Le fond blanc et l'ombre le gardent lisible sur une photo
/// claire comme sur une photo sombre.
class CercleFlottant extends StatelessWidget {
  final Widget enfant;
  final double taille;

  const CercleFlottant({super.key, required this.enfant, this.taille = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: bordureAccueil)),
        boxShadow: ombreAccueil,
      ),
      child: enfant,
    );
  }
}

/// Le carrousel des photos du bien.
///
/// Les points de pagination disent où l'on se trouve, le badge « 3 / 8 »
/// combien il en reste, et l'appui ouvre la galerie plein écran à la
/// photo regardée. Sans photo, un aplat gris : la page garde sa forme.
class CarrouselPhotos extends StatefulWidget {
  final List<Media> photos;

  final double hauteur;

  final VoidCallback onRetour;

  /// Null : le partage n'est pas proposé (droit manquant).
  final VoidCallback? onPartager;

  /// Le bouton ⋮ déjà habillé, ou null quand aucune action n'est ouverte.
  final Widget? menu;

  /// Reçoit l'index de la photo regardée.
  final void Function(int index)? onOuvrirGalerie;

  const CarrouselPhotos({
    super.key,
    required this.photos,
    required this.onRetour,
    this.hauteur = 250,
    this.onPartager,
    this.menu,
    this.onOuvrirGalerie,
  });

  @override
  State<CarrouselPhotos> createState() => _CarrouselPhotosState();
}

class _CarrouselPhotosState extends State<CarrouselPhotos> {
  final PageController _pages = PageController();
  int _courante = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<Media> get _photos => widget.photos;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    final total = _photos.length;

    return SizedBox(
      height: widget.hauteur + haut,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (total == 0)
            const _PhotoAbsente()
          else
            PageView.builder(
              controller: _pages,
              itemCount: total,
              onPageChanged: (i) => setState(() => _courante = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: widget.onOuvrirGalerie == null
                    ? null
                    : () => widget.onOuvrirGalerie!(i),
                child: _Photo(url: _photos[i].pleineTaille),
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
                  onTap: widget.onRetour,
                ),
                const Spacer(),
                if (widget.onPartager != null)
                  BoutonRondAccueil(
                    icone: Icons.share_outlined,
                    libelle: 'Partager la fiche',
                    onTap: widget.onPartager!,
                  ),
                if (widget.menu != null) ...[
                  const SizedBox(width: 8),
                  widget.menu!,
                ],
              ],
            ),
          ),

          // Les points de pagination, à gauche ; le compte, à droite.
          if (total > 1)
            Positioned(
              left: 16,
              bottom: 14,
              child: Row(
                children: List.generate(
                  total.clamp(0, 8),
                  (i) => Container(
                    margin: const EdgeInsets.only(right: 5),
                    width: i == _courante ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _courante
                          ? Colors.white
                          : Colors.white.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          if (total > 0)
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: widget.onOuvrirGalerie == null
                    ? null
                    : () => widget.onOuvrirGalerie!(_courante),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xB317262E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_courante + 1} / $total',
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

class _Photo extends StatelessWidget {
  final String? url;

  const _Photo({this.url});

  @override
  Widget build(BuildContext context) {
    final adresse = (url ?? '').trim();
    if (adresse.isEmpty) return const _PhotoAbsente();
    return Image.network(
      adresse,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _PhotoAbsente(),
      loadingBuilder: (_, enfant, avancement) =>
          avancement == null ? enfant : const _PhotoEnCours(),
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
      child: const Icon(
        Icons.home_work_outlined,
        size: 56,
        color: Color(0xFFA9B6BD),
      ),
    );
  }
}

class _PhotoEnCours extends StatelessWidget {
  const _PhotoEnCours();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFFE7ECEF), child: SizedBox.expand());
}

/// Le titre d'une section de la fiche : « Description », « Équipements ».
class TitreSectionDetail extends StatelessWidget {
  final String texte;

  const TitreSectionDetail(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texte,
      style: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        color: texteAccueil,
      ),
    );
  }
}

/// Un chiffre du bien et ce qu'il compte : « 86 » sur « m² ».
///
/// Les cartes ne sont dressées que pour les chiffres renseignés : une
/// ligne de « N/A » ne dit rien.
class CarteChiffre extends StatelessWidget {
  final String valeur;
  final String libelle;
  final IconData icone;

  const CarteChiffre({
    super.key,
    required this.valeur,
    required this.libelle,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: bordureAccueil),
        borderRadius: BorderRadius.circular(rayonAccueil),
        boxShadow: ombreAccueil,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: AppColors.primaryColor),
          const SizedBox(height: 8),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: texteAccueil,
              fontFeatures: chiffresTabulaires,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            libelle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              color: texteDouxAccueil,
            ),
          ),
        ],
      ),
    );
  }
}

/// La rangée des cartes chiffres : elle défile quand les quatre ne
/// tiennent pas dans la largeur.
class RangeeChiffres extends StatelessWidget {
  final List<CarteChiffre> cartes;

  const RangeeChiffres({super.key, required this.cartes});

  @override
  Widget build(BuildContext context) {
    // Les cartes partagent la hauteur de la plus haute : « salles de bain »
    // tient sur deux lignes, « m² » sur une, et leurs bords restent alignes.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cartes.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              cartes[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Une puce à bordure fine : un équipement, ou « + 4 » quand la liste
/// est repliée.
class PuceEquipement extends StatelessWidget {
  final String texte;
  final bool accentuee;
  final VoidCallback? onTap;

  const PuceEquipement(
    this.texte, {
    super.key,
    this.accentuee = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = accentuee ? AppColors.primaryColor : texteAccueil;
    final puce = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: accentuee
              ? AppColors.primaryColor.withValues(alpha: .45)
              : bordureAccueil,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: accentuee ? FontWeight.w700 : FontWeight.w500,
          color: couleur,
        ),
      ),
    );

    if (onTap == null) return puce;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: puce,
    );
  }
}

/// La carte du quartier, avec le bouton « Ouvrir dans Maps » posé en bas
/// à gauche.
///
/// Sans coordonnées, un aplat gris et un repère rouge : la section dit
/// quand même où le bien se trouve, par son adresse.
class MiniCarte extends StatelessWidget {
  final double? latitude;
  final double? longitude;

  /// Null : le bouton n'est pas proposé (pas de position à ouvrir).
  final VoidCallback? onOuvrirMaps;

  final double hauteur;

  const MiniCarte({
    super.key,
    this.latitude,
    this.longitude,
    this.onOuvrirMaps,
    this.hauteur = 150,
  });

  bool get _aPosition {
    final la = latitude;
    final lo = longitude;
    if (la == null || lo == null) return false;
    return !(la == 0 && lo == 0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: SizedBox(
        height: hauteur,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_aPosition) _carte() else const _AplatCarte(),
            if (onOuvrirMaps != null)
              Positioned(
                left: 10,
                bottom: 10,
                child: _PiluleMaps(onTap: onOuvrirMaps!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _carte() {
    final position = LatLng(latitude!, longitude!);
    return IgnorePointer(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: position, zoom: 15),
        markers: {Marker(markerId: const MarkerId('bien'), position: position)},
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
        zoomGesturesEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
      ),
    );
  }
}

class _AplatCarte extends StatelessWidget {
  const _AplatCarte();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7ECEF),
      alignment: Alignment.center,
      child: const Icon(Icons.location_on, size: 34, color: rougeAccueil),
    );
  }
}

class _PiluleMaps extends StatelessWidget {
  final VoidCallback onTap;

  const _PiluleMaps({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: bordureAccueil),
            borderRadius: BorderRadius.circular(20),
            boxShadow: ombreAccueil,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 15, color: texteAccueil),
              SizedBox(width: 6),
              Text(
                'Ouvrir dans Maps',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: texteAccueil,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// L'esquisse de la fiche, le temps de la première lecture.
class SqueletteDetailBien extends StatelessWidget {
  final double hauteurPhoto;

  const SqueletteDetailBien({super.key, this.hauteurPhoto = 250});

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(height: hauteurPhoto + haut, color: const Color(0xFFE7ECEF)),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CarteAccueil(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BlocSquelette(hauteur: 10, largeur: 110),
                        Spacer(),
                        BlocSquelette(hauteur: 22, largeur: 92, rayon: 7),
                      ],
                    ),
                    SizedBox(height: 12),
                    BlocSquelette(hauteur: 20, largeur: 210, rayon: 7),
                    SizedBox(height: 9),
                    BlocSquelette(hauteur: 12, largeur: 150),
                  ],
                ),
              ),
              SizedBox(height: 14),
              Row(
                children: [
                  BlocSquelette(hauteur: 86, largeur: 86, rayon: 16),
                  SizedBox(width: 10),
                  BlocSquelette(hauteur: 86, largeur: 86, rayon: 16),
                  SizedBox(width: 10),
                  BlocSquelette(hauteur: 86, largeur: 86, rayon: 16),
                ],
              ),
              SizedBox(height: 14),
              CarteAccueil(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocSquelette(hauteur: 12, largeur: 110),
                    SizedBox(height: 12),
                    BlocSquelette(hauteur: 10),
                    SizedBox(height: 8),
                    BlocSquelette(hauteur: 10),
                    SizedBox(height: 8),
                    BlocSquelette(hauteur: 10, largeur: 180),
                  ],
                ),
              ),
              SizedBox(height: 14),
              CarteAccueil(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlocSquelette(hauteur: 12, largeur: 110),
                    SizedBox(height: 12),
                    BlocSquelette(hauteur: 150, rayon: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
