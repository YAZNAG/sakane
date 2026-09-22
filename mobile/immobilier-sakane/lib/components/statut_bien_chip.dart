import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart' show CouleursAirbnb;
import 'package:immobilier/models/statut_jour.dart';

/// Pastille du statut du bien aujourd'hui (disponible, occupe, reserve
/// sur Airbnb, a nettoyer, nettoyage en cours, desactive), avec sa
/// precision (« Jusqu'au … ») a cote ou dessous.
class StatutBienChip extends StatelessWidget {
  final StatutJour statut;

  /// Precision sous la pastille plutot qu'a cote.
  final bool detailDessous;

  /// Pastille plus petite (listes).
  final bool compact;

  const StatutBienChip({
    super.key,
    required this.statut,
    this.detailDessous = false,
    this.compact = false,
  });

  static const Color _vert = Color(0xFF2E7D32);
  static const Color _rouge = Color(0xFFC62828);
  static const Color _orange = Color(0xFFE65100);
  static const Color _bleu = Color(0xFF1565C0);
  static const Color _gris = Color(0xFF6B7B84);

  /// Couleur du statut ; un code inconnu reste neutre (gris).
  static Color couleurDe(StatutJour s) {
    if (s.estAirbnb) return CouleursAirbnb.rose;
    switch (s.code) {
      case StatutJour.disponible:
        return _vert;
      case StatutJour.occupe:
        return _rouge;
      case StatutJour.aNettoyer:
        return _orange;
      case StatutJour.nettoyage:
        return _bleu;
      case StatutJour.desactive:
      default:
        return _gris;
    }
  }

  static IconData _iconeDe(StatutJour s) {
    switch (s.code) {
      case StatutJour.disponible:
        return Icons.check_circle_outline;
      case StatutJour.occupe:
        return Icons.person_outline;
      case StatutJour.aNettoyer:
        return Icons.cleaning_services_outlined;
      case StatutJour.nettoyage:
        return Icons.cleaning_services;
      case StatutJour.desactive:
        return Icons.block;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final couleur = couleurDe(statut);
    final taille = compact ? 11.0 : 12.5;
    final icone = compact ? 13.0 : 15.0;

    final pastille = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statut.estAirbnb
              ? FaIcon(FontAwesomeIcons.airbnb, size: icone - 1, color: couleur)
              : Icon(_iconeDe(statut), size: icone, color: couleur),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              statut.libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: taille, fontWeight: FontWeight.w700, color: couleur),
            ),
          ),
        ],
      ),
    );

    final detail = statut.detail;
    if ((detail ?? '').isEmpty) return pastille;

    final texteDetail = Text(
      detail!,
      maxLines: detailDessous ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: taille - 1, color: _gris),
    );

    if (detailDessous) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [pastille, const SizedBox(height: 3), texteDetail],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: pastille),
        const SizedBox(width: 6),
        Flexible(child: texteDetail),
      ],
    );
  }
}
