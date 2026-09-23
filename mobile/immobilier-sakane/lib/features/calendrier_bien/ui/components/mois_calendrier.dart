import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/calendrier_bien.dart';

/// Hauteur d'une barre de séjour et l'air qui la sépare de la suivante.
const double hauteurBarre = 20;
const double espaceBarre = 3;

/// Le haut de la première barre, sous le numéro du jour.
const double hautBarres = 30;

/// Une case sans séjour : le numéro, la barre, le prix.
const double hauteurCase = 72;

/// Un séjour posé sur la grille, quelle qu'en soit l'origine : une
/// réservation, un séjour Airbnb ou un bail. La grille n'a besoin que
/// de ses deux dates, de sa couleur et de son nom.
class _Sejour {
  /// Premier jour occupé, et le lendemain du dernier (départ exclu).
  final DateTime debut;
  final DateTime finExclue;
  final Color couleur;
  final String libelle;
  final VoidCallback onTap;

  const _Sejour({
    required this.debut,
    required this.finExclue,
    required this.couleur,
    required this.libelle,
    required this.onTap,
  });
}

/// Un séjour découpé aux bords d'une semaine : ses colonnes, ses coins.
class _Troncon {
  final _Sejour sejour;
  final double gauche;
  final double droite;
  final bool arrondiGauche;
  final bool arrondiDroite;
  int voie = 0;

  _Troncon({
    required this.sejour,
    required this.gauche,
    required this.droite,
    required this.arrondiGauche,
    required this.arrondiDroite,
  });
}

/// Un mois du calendrier : la grille lundi-dimanche, le prix de chaque
/// nuit, et par-dessus les barres continues des séjours.
///
/// Les barres d'une même semaine s'empilent : deux séjours qui se
/// suivent de près gardent chacun leur ligne.
class MoisCalendrier extends StatelessWidget {
  final DateTime mois;
  final CalendrierBien calendrier;
  final bool Function(DateTime jour) estSelectionne;
  final void Function(DateTime jour) onTapJour;
  final void Function(ReservationCalendrier reservation) onTapReservation;
  final void Function(BailCalendrier bail) onTapBail;
  final void Function(SejourAirbnb sejour) onTapAirbnb;

  /// Glissement sur les jours : le doigt se pose, traverse, se lève.
  /// Nuls quand la sélection n'est pas permise : le geste n'existe pas.
  final void Function(DateTime jour)? onGlissementDebut;
  final void Function(DateTime jour)? onGlissementVers;
  final VoidCallback? onGlissementFin;

  const MoisCalendrier({
    super.key,
    required this.mois,
    required this.calendrier,
    required this.estSelectionne,
    required this.onTapJour,
    required this.onTapReservation,
    required this.onTapBail,
    required this.onTapAirbnb,
    this.onGlissementDebut,
    this.onGlissementVers,
    this.onGlissementFin,
  });

  int get _nbJours => DateTime(mois.year, mois.month + 1, 0).day;

  /// Colonne du 1er du mois : lundi = 0.
  int get _decalage => DateTime(mois.year, mois.month, 1).weekday - 1;

  int get _nbSemaines => ((_decalage + _nbJours) / 7).ceil();

  /// Tous les séjours du mois, réservations, Airbnb et baux confondus.
  List<_Sejour> get _sejours {
    final tous = <_Sejour>[];
    for (final b in calendrier.baux) {
      tous.add(_Sejour(
        debut: b.du,
        finExclue: b.finExclue,
        couleur: b.actif ? CouleursCalendrier.bail : CouleursCalendrier.bailTermine,
        libelle: (b.locataire ?? '').trim().isEmpty ? 'Bail' : b.locataire!.trim(),
        onTap: () => onTapBail(b),
      ));
    }
    for (final r in calendrier.reservations) {
      tous.add(_Sejour(
        debut: r.checkin,
        finExclue: r.checkout,
        couleur: CouleursCalendrier.selonPaiement(r.paiement),
        libelle: (r.clientNom ?? '').trim().isEmpty ? 'Client' : r.clientNom!.trim(),
        onTap: () => onTapReservation(r),
      ));
    }
    for (final a in calendrier.airbnb) {
      tous.add(_Sejour(
        debut: a.du,
        finExclue: a.au,
        couleur: CouleursCalendrier.sejourAirbnb,
        libelle: a.estReservation ? 'Airbnb' : 'Airbnb · bloqué',
        onTap: () => onTapAirbnb(a),
      ));
    }
    return tous;
  }

  /// Les séjours d'une semaine, découpés à ses bords et rangés par
  /// voies : la première libre accueille le tronçon suivant.
  List<_Troncon> _troncons(int semaine) {
    final premiereCol = semaine == 0 ? _decalage : 0;
    final derniereCol = semaine == _nbSemaines - 1 ? (_decalage + _nbJours - 1) % 7 : 6;
    final debutLigne = DateTime(mois.year, mois.month, semaine * 7 + premiereCol - _decalage + 1);
    final finLigne = DateTime(mois.year, mois.month, semaine * 7 + derniereCol - _decalage + 1);

    final troncons = <_Troncon>[];
    for (final s in _sejours) {
      if (!s.finExclue.isAfter(s.debut)) continue;
      if (s.debut.isAfter(finLigne) || s.finExclue.isBefore(debutLigne)) continue;
      final debutIci = !s.debut.isBefore(debutLigne);
      final finIci = !s.finExclue.isAfter(finLigne);
      final gauche = debutIci ? premiereCol + ecartJours(debutLigne, s.debut) + .5 : premiereCol.toDouble();
      final droite = finIci ? premiereCol + ecartJours(debutLigne, s.finExclue) + .5 : derniereCol + 1.0;
      if (droite - gauche < .05) continue;
      troncons.add(_Troncon(
        sejour: s,
        gauche: gauche,
        droite: droite,
        arrondiGauche: debutIci,
        arrondiDroite: finIci,
      ));
    }

    troncons.sort((a, b) => a.gauche != b.gauche
        ? a.gauche.compareTo(b.gauche)
        : b.droite.compareTo(a.droite));

    final finDesVoies = <double>[];
    for (final t in troncons) {
      var voie = finDesVoies.indexWhere((fin) => fin <= t.gauche + .01);
      if (voie < 0) {
        finDesVoies.add(t.droite);
        voie = finDesVoies.length - 1;
      } else {
        finDesVoies[voie] = t.droite;
      }
      t.voie = voie;
    }
    return troncons;
  }

  /// Le jour sous le doigt, ou null hors du mois.
  DateTime? _jourSous(Offset point, double largeurCase, double hauteurRangee) {
    final colonne = (point.dx / largeurCase).floor().clamp(0, 6);
    final ligne = (point.dy / hauteurRangee).floor().clamp(0, _nbSemaines - 1);
    final numero = ligne * 7 + colonne - _decalage + 1;
    if (numero < 1 || numero > _nbJours) return null;
    return DateTime(mois.year, mois.month, numero);
  }

  @override
  Widget build(BuildContext context) {
    final semaines = [for (int s = 0; s < _nbSemaines; s++) _troncons(s)];
    var voies = 1;
    for (final semaine in semaines) {
      for (final t in semaine) {
        if (t.voie + 1 > voies) voies = t.voie + 1;
      }
    }
    final hauteurRangee =
        math.max(hauteurCase, hautBarres + voies * (hauteurBarre + espaceBarre) + 20);

    return LayoutBuilder(builder: (context, contraintes) {
      final largeurCase = contraintes.maxWidth / 7;

      DateTime? jour(Offset p) => _jourSous(p, largeurCase, hauteurRangee);

      final grille = Column(
        children: [
          for (int s = 0; s < _nbSemaines; s++)
            _semaine(s, semaines[s], largeurCase, hauteurRangee),
        ],
      );

      // Le glissement part d'un mouvement horizontal : le défilement
      // vertical de la page lui reste possible, et une fois le geste
      // gagné le doigt descend librement d'une semaine à l'autre.
      if (onGlissementDebut == null) return grille;
      return GestureDetector(
        onHorizontalDragStart: (d) {
          final j = jour(d.localPosition);
          if (j != null) onGlissementDebut!(j);
        },
        onHorizontalDragUpdate: (d) {
          final j = jour(d.localPosition);
          if (j != null) onGlissementVers?.call(j);
        },
        onHorizontalDragEnd: (_) => onGlissementFin?.call(),
        onHorizontalDragCancel: () => onGlissementFin?.call(),
        child: grille,
      );
    });
  }

  Widget _semaine(int semaine, List<_Troncon> troncons, double largeurCase, double hauteurRangee) {
    return SizedBox(
      height: hauteurRangee,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final n = semaine * 7 + c - _decalage + 1;
                    if (n < 1 || n > _nbJours) return const SizedBox();
                    return _case(DateTime(mois.year, mois.month, n));
                  }(),
                ),
            ],
          ),
          for (final t in troncons)
            Positioned(
              left: t.gauche * largeurCase + (t.arrondiGauche ? 1.5 : 0),
              width: math.max(
                  2.0,
                  (t.droite - t.gauche) * largeurCase -
                      (t.arrondiGauche ? 1.5 : 0) -
                      (t.arrondiDroite ? 1.5 : 0)),
              top: hautBarres + t.voie * (hauteurBarre + espaceBarre),
              height: hauteurBarre,
              child: _BarreSejour(troncon: t),
            ),
        ],
      ),
    );
  }

  Widget _case(DateTime jour) {
    final t = aujourdhui();
    final passe = jour.isBefore(t);
    final estAujourdhui = jour == t;
    final occupe = calendrier.estOccupe(jour) || calendrier.sejourAirbnbDe(jour) != null;
    final blocage = occupe ? null : calendrier.blocageDe(jour);
    final special = calendrier.aPrixSpecial(jour);
    final selection = estSelectionne(jour);

    final fond = selection
        ? AppColors.primaryColor.withValues(alpha: .12)
        : blocage != null
            ? CouleursCalendrier.bloque
            : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapJour(jour),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selection ? AppColors.primaryColor.withValues(alpha: .55) : bordureAccueil,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            children: [
              if (blocage != null)
                const Positioned.fill(child: CustomPaint(painter: RayuresPainter())),
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: estAujourdhui
                        ? const BoxDecoration(color: AppColors.primaryColor, shape: BoxShape.circle)
                        : null,
                    child: Text(
                      '${jour.day}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: estAujourdhui ? FontWeight.w800 : FontWeight.w600,
                        color: estAujourdhui
                            ? Colors.white
                            : passe
                                ? texteDouxAccueil
                                : texteAccueil,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 2,
                right: 2,
                bottom: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    prixCompact(calendrier.prixDe(jour)),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: special ? FontWeight.w800 : FontWeight.w500,
                      color: special ? orangeAccueil : texteDouxAccueil,
                    ),
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

/// Une barre de séjour : sa couleur dit ce qui a été payé, son initiale
/// et son nom disent de qui il s'agit. Ses bouts ne s'arrondissent
/// qu'aux vraies dates d'arrivée et de départ.
class _BarreSejour extends StatelessWidget {
  final _Troncon troncon;

  const _BarreSejour({required this.troncon});

  @override
  Widget build(BuildContext context) {
    final sejour = troncon.sejour;
    const rayon = Radius.circular(10);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: sejour.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: sejour.couleur,
          borderRadius: BorderRadius.horizontal(
            left: troncon.arrondiGauche ? rayon : Radius.zero,
            right: troncon.arrondiDroite ? rayon : Radius.zero,
          ),
        ),
        padding: EdgeInsets.only(left: troncon.arrondiGauche ? 2.5 : 6, right: 6),
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 18) return const SizedBox();
          final avecInitiale = troncon.arrondiGauche && c.maxWidth >= 44;
          return Row(
            children: [
              if (avecInitiale) ...[
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Text(
                    sejour.libelle.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: sejour.couleur),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  sejour.libelle,
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
      ),
    );
  }
}
