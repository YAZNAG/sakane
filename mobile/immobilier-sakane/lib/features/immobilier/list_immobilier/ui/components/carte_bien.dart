import 'package:flutter/material.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart'
    show bleuCharte;
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/models/statut_jour.dart';

/// Les couleurs de la pastille d'état, telles que la charte les fixe.
const Color _grisEtat = Color(0xFF6B7B84);

/// « 3e étage », « RDC » : l'étage tel qu'on le dit, pas le nombre brut.
String? etageLisible(int? etage) {
  if (etage == null) return null;
  if (etage <= 0) return 'RDC';
  return etage == 1 ? '1er étage' : '${etage}e étage';
}

/// « 4,8 » : la note avec une décimale, virgule française.
String noteLisible(num note) =>
    note.toStringAsFixed(1).replaceAll('.', ',');

/// L'état du jour d'un bien, sa couleur et son libellé.
///
/// Le serveur calcule `statutJour` ; quand il manque — ancienne réponse,
/// lecture partielle — l'état se déduit de ce que la liste sait déjà.
class EtatDuBien {
  final String libelle;
  final Color teinte;

  const EtatDuBien(this.libelle, this.teinte);

  static EtatDuBien? de(Realestate bien) {
    final statut = bien.statutJour;
    if (statut != null && statut.libelle.isNotEmpty) {
      return EtatDuBien(statut.libelle, _teinteDuCode(statut));
    }
    if (bien.estDesactive) return const EtatDuBien('Désactivé', _grisEtat);
    if (bien.booking != null) return const EtatDuBien('Occupé', rougeAccueil);
    if (bien.aNettoyer) return const EtatDuBien('À nettoyer', orangeAccueil);
    if (bien.enNettoyage) return const EtatDuBien('Nettoyage', bleuCharte);
    return const EtatDuBien('Disponible', vertAccueil);
  }

  static Color _teinteDuCode(StatutJour statut) {
    switch (statut.code) {
      case StatutJour.disponible:
        return vertAccueil;
      case StatutJour.occupe:
      case StatutJour.occupeAirbnb:
        return rougeAccueil;
      case StatutJour.aNettoyer:
        return orangeAccueil;
      case StatutJour.nettoyage:
        return bleuCharte;
      case StatutJour.desactive:
        return _grisEtat;
      default:
        return _grisEtat;
    }
  }
}

/// Une pastille d'état : un aplat très clair, un texte de la même teinte.
class PastilleEtatBien extends StatelessWidget {
  final EtatDuBien etat;

  const PastilleEtatBien({super.key, required this.etat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: etat.teinte.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: etat.teinte.withValues(alpha: .28)),
      ),
      child: Text(
        etat.libelle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: etat.teinte,
        ),
      ),
    );
  }
}

/// Un bien dans la liste : sa photo, son identité, son prix, son état.
///
/// La carte se lit de haut en bas : ce qu'est le bien, où il est, ce
/// qu'il coûte. L'état du jour se tient à droite du titre — c'est la
/// seule chose qui change d'un jour à l'autre.
class CarteBien extends StatelessWidget {
  final Realestate bien;

  /// Famille du bien, pour l'unité du prix : « / nuit », « / mois », ou
  /// rien du tout pour une vente.
  final String? familleCode;

  final void Function(Realestate)? onTap;
  final void Function(Realestate)? onAppuiLong;

  const CarteBien({
    super.key,
    required this.bien,
    this.familleCode,
    this.onTap,
    this.onAppuiLong,
  });

  /// L'unité du prix dépend de la famille du bien, jamais du prix.
  String? get _uniteDuPrix {
    final code = familleCode ?? bien.typeTransaction?.value;
    switch (code) {
      case 'rent-short':
        return '/ nuit';
      case 'rent-long':
        return '/ mois';
      case 'selle':
        return null;
      default:
        return '/ nuit';
    }
  }

  String? get _lieu {
    final ville = bien.address?.city?.name?.trim();
    if ((ville ?? '').isNotEmpty) return ville;
    final secteur = bien.secteur?.name?.trim();
    return (secteur ?? '').isEmpty ? null : secteur;
  }

  /// « 2 chambres · 64 m² · 3e étage » : seul ce qui est connu s'écrit.
  String get _caracteristiques {
    final morceaux = <String>[];
    final chambres = bien.nbRooms;
    if (chambres != null && chambres > 0) {
      morceaux.add('$chambres chambre${chambres > 1 ? 's' : ''}');
    }
    final surface = bien.surface;
    if (surface != null && surface > 0) {
      final entier = surface.toFloat();
      morceaux.add('$entier m²');
    }
    final etage = etageLisible(bien.etage);
    if (etage != null) morceaux.add(etage);
    return morceaux.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final etat = EtatDuBien.de(bien);
    final caracteristiques = _caracteristiques;
    final lieu = _lieu;
    final reference = bien.referenceLisible;
    final avis = (bien.rateCount ?? 0).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(bien),
        onLongPress: onAppuiLong == null ? null : () => onAppuiLong!(bien),
        child: CarteAccueil(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VignetteBien(bien: bien),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            (bien.title ?? '').trim().isEmpty
                                ? 'Bien sans titre'
                                : bien.title!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: texteAccueil,
                            ),
                          ),
                        ),
                        if (etat != null) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 108),
                            child: PastilleEtatBien(etat: etat),
                          ),
                        ],
                      ],
                    ),
                    if (reference.isNotEmpty || lieu != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (reference.isNotEmpty) 'Réf. $reference',
                          if (lieu != null) lieu,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: texteDouxAccueil,
                          fontFeatures: chiffresTabulaires,
                        ),
                      ),
                    ],
                    if (caracteristiques.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        caracteristiques,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A5B64),
                          fontFeatures: chiffresTabulaires,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _PrixEtMentions(
                      prix: (bien.price ?? 0).toDouble(),
                      unite: _uniteDuPrix,
                      note: avis > 0 ? bien.rate : null,
                      avis: avis,
                      airbnb: bien.airbnbRelie,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La photo du bien, ou un aplat gris et une icône quand il n'y en a pas.
class _VignetteBien extends StatelessWidget {
  final Realestate bien;

  const _VignetteBien({required this.bien});

  static const double _cote = 88;

  @override
  Widget build(BuildContext context) {
    final photos = bien.media ?? const [];
    final url = photos.isEmpty ? null : photos.first.vignette;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _cote,
        height: _cote,
        child: (url == null || url.isEmpty)
            ? const _AplatSansPhoto()
            : Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 264,
                errorBuilder: (_, __, ___) => const _AplatSansPhoto(),
              ),
      ),
    );
  }
}

class _AplatSansPhoto extends StatelessWidget {
  const _AplatSansPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEDF1F3),
      alignment: Alignment.center,
      child: const Icon(Icons.home_work_outlined, size: 30, color: Color(0xFFA7B4BB)),
    );
  }
}

/// Le prix à gauche, la note et la mention Airbnb à droite.
class _PrixEtMentions extends StatelessWidget {
  final double prix;
  final String? unite;
  final num? note;
  final int avis;
  final bool airbnb;

  const _PrixEtMentions({
    required this.prix,
    required this.unite,
    required this.note,
    required this.avis,
    required this.airbnb,
  });

  @override
  Widget build(BuildContext context) {
    final mentions = note != null || airbnb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: montantAccueil(prix),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: texteAccueil,
                  fontFeatures: chiffresTabulaires,
                ),
              ),
              if ((unite ?? '').isNotEmpty)
                TextSpan(
                  text: ' ${unite!}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: texteDouxAccueil,
                  ),
                ),
            ],
          ),
        ),
        if (mentions) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (note != null)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFE8B10A)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${noteLisible(note!)} · $avis avis',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: texteDouxAccueil,
                            fontFeatures: chiffresTabulaires,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (airbnb) ...[
                if (note != null) const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: rougeAccueil.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '• Airbnb',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: rougeAccueil,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

extension _SurfaceLisible on num {
  /// « 64 » plutôt que « 64.0 » : la surface s'écrit sans décimale
  /// inutile, et la garde quand elle en a une.
  String toFloat() {
    if (this == truncate()) return truncate().toString();
    return toStringAsFixed(1).replaceAll('.', ',');
  }
}
