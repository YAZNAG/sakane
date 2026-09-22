import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/calendrier_bien.dart';

const double hauteurCase = 72;

/// Un mois du calendrier : grille lundi-dimanche, prix des nuits et
/// barres continues des reservations et des baux.
class MoisCalendrier extends StatelessWidget {
  final DateTime mois;
  final CalendrierBien calendrier;
  final bool Function(DateTime jour) estSelectionne;
  final DateTime? debutSelection;
  final DateTime? finSelection;
  final void Function(DateTime jour) onTap;

  const MoisCalendrier({
    super.key,
    required this.mois,
    required this.calendrier,
    required this.estSelectionne,
    required this.debutSelection,
    required this.finSelection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final premier = DateTime(mois.year, mois.month, 1);
    final nbJours = DateTime(mois.year, mois.month + 1, 0).day;
    final decalage = premier.weekday - 1;
    final nbSemaines = ((decalage + nbJours) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              titreMois(mois),
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: CouleursCalendrier.texte,
                letterSpacing: -.2,
              ),
            ),
          ),
          for (int s = 0; s < nbSemaines; s++)
            _semaine([
              for (int c = 0; c < 7; c++)
                () {
                  final n = s * 7 + c - decalage + 1;
                  return (n < 1 || n > nbJours) ? null : DateTime(mois.year, mois.month, n);
                }(),
            ]),
        ],
      ),
    );
  }

  Widget _semaine(List<DateTime?> jours) {
    final premiereCol = jours.indexWhere((j) => j != null);
    final derniereCol = jours.lastIndexWhere((j) => j != null);
    final debutLigne = jours[premiereCol]!;
    final finLigne = jours[derniereCol]!;

    return LayoutBuilder(builder: (context, contraintes) {
      final largeur = contraintes.maxWidth / 7;
      final barres = <Widget>[];

      // Meme geometrie qu'une reservation : le bail libere le lendemain de son dernier jour.
      for (final b in calendrier.baux) {
        final fin = b.finExclue;
        if (b.du.isAfter(finLigne) || fin.isBefore(debutLigne)) continue;
        final debutIci = !b.du.isBefore(debutLigne);
        final finIci = !fin.isAfter(finLigne);
        final gauche = debutIci
            ? (premiereCol + ecartJours(debutLigne, b.du) + .5) * largeur + 1.5
            : premiereCol * largeur;
        final droite = finIci
            ? (premiereCol + ecartJours(debutLigne, fin) + .5) * largeur - 1.5
            : (derniereCol + 1) * largeur;
        if (droite - gauche < 2) continue;
        barres.add(Positioned(
          left: gauche,
          width: droite - gauche,
          top: 30,
          height: 22,
          child: IgnorePointer(
            child: _BarreBail(bail: b, arrondiGauche: debutIci, arrondiDroite: finIci),
          ),
        ));
      }

      for (final r in calendrier.reservations) {
        // Visible si une nuit, ou la demi-case du depart, tombe sur la ligne.
        if (r.checkin.isAfter(finLigne) || r.checkout.isBefore(debutLigne)) continue;
        if (!r.checkout.isAfter(r.checkin)) continue;
        final debutIci = !r.checkin.isBefore(debutLigne);
        final finIci = !r.checkout.isAfter(finLigne);
        final gauche = debutIci
            ? (premiereCol + ecartJours(debutLigne, r.checkin) + .5) * largeur + 1.5
            : premiereCol * largeur;
        final droite = finIci
            ? (premiereCol + ecartJours(debutLigne, r.checkout) + .5) * largeur - 1.5
            : (derniereCol + 1) * largeur;
        if (droite - gauche < 2) continue;
        barres.add(Positioned(
          left: gauche,
          width: droite - gauche,
          top: 30,
          height: 22,
          child: IgnorePointer(
            child: _BarreReservation(
              reservation: r,
              arrondiGauche: debutIci,
              arrondiDroite: finIci,
            ),
          ),
        ));
      }

      // Sejours Airbnb : meme geometrie, depart exclu.
      for (final a in calendrier.airbnb) {
        if (a.du.isAfter(finLigne) || a.au.isBefore(debutLigne)) continue;
        if (!a.au.isAfter(a.du)) continue;
        final debutIci = !a.du.isBefore(debutLigne);
        final finIci = !a.au.isAfter(finLigne);
        final gauche = debutIci
            ? (premiereCol + ecartJours(debutLigne, a.du) + .5) * largeur + 1.5
            : premiereCol * largeur;
        final droite = finIci
            ? (premiereCol + ecartJours(debutLigne, a.au) + .5) * largeur - 1.5
            : (derniereCol + 1) * largeur;
        if (droite - gauche < 2) continue;
        barres.add(Positioned(
          left: gauche,
          width: droite - gauche,
          top: 30,
          height: 22,
          child: IgnorePointer(
            child: _BarreAirbnb(sejour: a, arrondiGauche: debutIci, arrondiDroite: finIci),
          ),
        ));
      }

      return SizedBox(
        height: hauteurCase,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                for (final j in jours)
                  Expanded(child: j == null ? const SizedBox() : _case(j)),
              ],
            ),
            ...barres,
          ],
        ),
      );
    });
  }

  Widget _case(DateTime jour) {
    final t = aujourdhui();
    final passe = jour.isBefore(t);
    final estAujourdhui = jour == t;
    // Affichage : un sejour Airbnb, meme bloque, a sa barre sur le jour.
    final occupe = calendrier.estOccupe(jour) || calendrier.sejourAirbnbDe(jour) != null;
    final blocage = !occupe ? calendrier.blocageDe(jour) : null;
    final special = calendrier.aPrixSpecial(jour);
    final selection = estSelectionne(jour);
    final borne = selection && (jour == debutSelection || jour == (finSelection ?? debutSelection));
    final couleurPrimaire = AppColors.primaryColor;

    Color? fond;
    if (borne) {
      fond = couleurPrimaire;
    } else if (selection) {
      fond = couleurPrimaire.withValues(alpha: .14);
    } else if (blocage != null) {
      fond = CouleursCalendrier.bloque;
    }

    final couleurNumero = borne
        ? Colors.white
        : blocage != null
            ? CouleursCalendrier.texteDoux
            : CouleursCalendrier.texte;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(jour),
      child: Opacity(
        opacity: passe ? .45 : 1,
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: fond ?? Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borne ? couleurPrimaire : CouleursCalendrier.bordure,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              children: [
                if (blocage != null && !borne)
                  const Positioned.fill(child: CustomPaint(painter: RayuresPainter())),
                Positioned(
                  top: 5,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: estAujourdhui
                          ? BoxDecoration(
                              color: borne ? Colors.white : CouleursCalendrier.texte,
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      child: Text(
                        '${jour.day}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: estAujourdhui ? FontWeight.w800 : FontWeight.w600,
                          color: estAujourdhui
                              ? (borne ? couleurPrimaire : Colors.white)
                              : couleurNumero,
                          decoration: blocage != null && !borne ? TextDecoration.lineThrough : null,
                          decorationColor: CouleursCalendrier.texteDoux,
                        ),
                      ),
                    ),
                  ),
                ),
                if (special && !occupe && !borne)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: CouleursCalendrier.prixSpecial,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (!occupe)
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 6,
                    child: blocage != null
                        ? Icon(Icons.lock_outline,
                            size: 14, color: borne ? Colors.white : CouleursCalendrier.texteDoux)
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              prixCompact(calendrier.prixDe(jour)),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: special ? FontWeight.w800 : FontWeight.w500,
                                color: borne
                                    ? Colors.white
                                    : special
                                        ? CouleursCalendrier.prixSpecial
                                        : CouleursCalendrier.texteDoux,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarreReservation extends StatelessWidget {
  final ReservationCalendrier reservation;
  final bool arrondiGauche;
  final bool arrondiDroite;

  const _BarreReservation({
    required this.reservation,
    required this.arrondiGauche,
    required this.arrondiDroite,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = CouleursCalendrier.reservation(reservation);
    final nom = (reservation.clientNom ?? '').trim();
    const rayon = Radius.circular(11);

    return Container(
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.horizontal(
          left: arrondiGauche ? rayon : Radius.zero,
          right: arrondiDroite ? rayon : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(color: couleur.withValues(alpha: .35), blurRadius: 4, offset: const Offset(0, 1.5)),
        ],
      ),
      padding: EdgeInsets.only(left: arrondiGauche ? 2.5 : 6, right: 6),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 20) return const SizedBox();
        final avecAvatar = arrondiGauche && c.maxWidth >= 44;
        return Row(
          children: [
            if (avecAvatar) ...[
              Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Text(
                  nom.isEmpty ? '?' : nom.characters.first.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: couleur),
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                nom.isEmpty ? 'Client' : nom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _BarreBail extends StatelessWidget {
  final BailCalendrier bail;
  final bool arrondiGauche;
  final bool arrondiDroite;

  const _BarreBail({required this.bail, required this.arrondiGauche, required this.arrondiDroite});

  @override
  Widget build(BuildContext context) {
    final couleur = bail.actif ? CouleursCalendrier.bail : CouleursCalendrier.bailTermine;
    final nom = (bail.locataire ?? '').trim();
    const rayon = Radius.circular(11);

    return Container(
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.horizontal(
          left: arrondiGauche ? rayon : Radius.zero,
          right: arrondiDroite ? rayon : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(color: couleur.withValues(alpha: .35), blurRadius: 4, offset: const Offset(0, 1.5)),
        ],
      ),
      padding: EdgeInsets.only(left: arrondiGauche ? 4 : 6, right: 6),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 20) return const SizedBox();
        return Row(
          children: [
            if (arrondiGauche && c.maxWidth >= 44) ...[
              const Icon(Icons.key_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                nom.isEmpty ? 'Bail' : 'Bail · $nom',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _BarreAirbnb extends StatelessWidget {
  final SejourAirbnb sejour;
  final bool arrondiGauche;
  final bool arrondiDroite;

  const _BarreAirbnb({required this.sejour, required this.arrondiGauche, required this.arrondiDroite});

  @override
  Widget build(BuildContext context) {
    final passe = !sejour.au.isAfter(aujourdhui());
    final couleur = passe ? CouleursCalendrier.passee : CouleursAirbnb.sejour(sejour);
    const rayon = Radius.circular(11);

    return Container(
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.horizontal(
          left: arrondiGauche ? rayon : Radius.zero,
          right: arrondiDroite ? rayon : Radius.zero,
        ),
        boxShadow: [
          BoxShadow(color: couleur.withValues(alpha: .35), blurRadius: 4, offset: const Offset(0, 1.5)),
        ],
      ),
      padding: EdgeInsets.only(left: arrondiGauche ? 5 : 6, right: 6),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < 20) return const SizedBox();
        return Row(
          children: [
            if (arrondiGauche && c.maxWidth >= 44) ...[
              const FaIcon(FontAwesomeIcons.airbnb, size: 12, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                sejour.estReservation ? 'Airbnb' : 'Airbnb · bloqué',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        );
      }),
    );
  }
}
