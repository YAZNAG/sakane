import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';

/// La charte de la page d'accueil : un fond gris très clair, des cartes
/// blanches posées dessus, et trois couleurs de sens — l'argent qui
/// entre, l'argent qui sort, ce qui reste à faire.
///
/// Ces valeurs sont réunies ici pour que l'accueil tienne d'un seul
/// regard : une teinte changée l'est partout à la fois.
const Color fondAccueil = Color(0xFFF4F6F8);
const Color bordureAccueil = Color(0xFFE6EBEE);
const Color texteAccueil = Color(0xFF17262E);
const Color texteDouxAccueil = Color(0xFF6B7B84);

/// L'argent encaissé, l'argent sorti, ce qui reste à remettre.
const Color vertAccueil = Color(0xFF2E9E5B);
const Color rougeAccueil = Color(0xFFE03E3E);
const Color orangeAccueil = Color(0xFFE8710A);

/// L'ombre d'une carte : présente, jamais visible.
const List<BoxShadow> ombreAccueil = [
  BoxShadow(color: Color(0x0A17262E), blurRadius: 10, offset: Offset(0, 2)),
];

const double rayonAccueil = 16;

/// Les chiffres d'un montant gardent tous la même largeur : une colonne
/// de montants reste alignée, et le solde ne tremble pas quand il change.
const List<FontFeature> chiffresTabulaires = [FontFeature.tabularFigures()];

/// Espace fine insécable : « 4 850 MAD » ne se coupe pas en fin de ligne.
const String _finesInsecable = ' ';

/// « 4 850 MAD ». Les centimes n'apparaissent que s'il y en a : un solde
/// rond se lit mieux sans « ,00 ».
String montantAccueil(double montant, {bool avecDevise = true}) {
  final negatif = montant < 0;
  final absolu = montant.abs();
  final entier = absolu.truncate();
  final centimes = ((absolu - entier) * 100).round();

  final chiffres = entier.toString();
  final tampon = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(_finesInsecable);
    tampon.write(chiffres[i]);
  }

  final fraction =
      centimes == 0 ? '' : ',${centimes.toString().padLeft(2, '0')}';
  final devise = avecDevise ? '${_finesInsecable}MAD' : '';
  return '${negatif ? '−' : ''}$tampon$fraction$devise';
}

const List<String> _jours = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// « Lundi 21/09/2026 ». Les noms de jours sont écrits ici plutôt que
/// confiés à une locale : l'application n'installe pas les données de
/// langue et afficherait « Monday ».
String jourEtDate(DateTime date) {
  final jour = _jours[(date.weekday - 1).clamp(0, 6)];
  final j = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$jour $j/$m/${date.year}';
}

/// La carte blanche de l'accueil : le même fond, la même bordure, la
/// même ombre partout.
class CarteAccueil extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CarteAccueil({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: bordureAccueil),
        borderRadius: BorderRadius.circular(rayonAccueil),
        boxShadow: ombreAccueil,
      ),
      child: child,
    );
  }
}

/// Un bouton rond bordé, discret : il porte une icône et rien d'autre.
class BoutonRondAccueil extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final VoidCallback onTap;
  final Color? teinte;

  const BoutonRondAccueil({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.teinte,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: libelle,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: bordureAccueil)),
            ),
            child: Icon(icone, size: 18, color: teinte ?? texteAccueil),
          ),
        ),
      ),
    );
  }
}

/// Une bordure en pointillés, pour la tuile « Tous » : elle dit que la
/// case n'est pas un module mais une porte vers tous les autres.
class BordurePointillee extends StatelessWidget {
  final Widget child;
  final Color couleur;
  final double rayon;

  const BordurePointillee({
    super.key,
    required this.child,
    required this.couleur,
    this.rayon = rayonAccueil,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PeintreePointilles(couleur: couleur, rayon: rayon),
      child: child,
    );
  }
}

class _PeintreePointilles extends CustomPainter {
  final Color couleur;
  final double rayon;

  const _PeintreePointilles({required this.couleur, required this.rayon});

  @override
  void paint(Canvas toile, Size taille) {
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final contour = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(.6, .6, taille.width - 1.2, taille.height - 1.2),
        Radius.circular(rayon),
      ));

    const trait = 4.0;
    const blanc = 3.5;
    for (final segment in contour.computeMetrics()) {
      var distance = 0.0;
      while (distance < segment.length) {
        final fin = (distance + trait).clamp(0.0, segment.length);
        toile.drawPath(segment.extractPath(distance, fin), pinceau);
        distance = fin + blanc;
      }
    }
  }

  @override
  bool shouldRepaint(_PeintreePointilles ancien) =>
      ancien.couleur != couleur || ancien.rayon != rayon;
}

/// Un bloc gris en attente de sa donnée.
class BlocSquelette extends StatelessWidget {
  final double hauteur;
  final double? largeur;
  final double rayon;

  const BlocSquelette({
    super.key,
    required this.hauteur,
    this.largeur,
    this.rayon = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECEF),
        borderRadius: BorderRadius.circular(rayon),
      ),
    );
  }
}

/// L'esquisse de la carte de caisse, le temps de la lecture.
class SqueletteCarteCaisse extends StatelessWidget {
  const SqueletteCarteCaisse({super.key});

  @override
  Widget build(BuildContext context) {
    return const CarteAccueil(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BlocSquelette(hauteur: 12, largeur: 120),
              Spacer(),
              BlocSquelette(hauteur: 34, largeur: 34, rayon: 11),
            ],
          ),
          SizedBox(height: 16),
          BlocSquelette(hauteur: 32, largeur: 170, rayon: 10),
          SizedBox(height: 10),
          BlocSquelette(hauteur: 11, largeur: 200),
          SizedBox(height: 16),
          Divider(height: 1, color: bordureAccueil),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: BlocSquelette(hauteur: 34)),
              SizedBox(width: 10),
              Expanded(child: BlocSquelette(hauteur: 34)),
              SizedBox(width: 10),
              Expanded(child: BlocSquelette(hauteur: 34)),
            ],
          ),
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
    );
  }
}

/// L'échec de la lecture du résumé : une carte discrète et un bouton.
///
/// Discrète parce que le reste de l'accueil fonctionne : les modules
/// s'ouvrent, la caisse s'atteint. Seuls les chiffres manquent.
class CarteErreurResume extends StatelessWidget {
  final String? message;
  final VoidCallback onReessayer;

  const CarteErreurResume({super.key, this.message, required this.onReessayer});

  @override
  Widget build(BuildContext context) {
    return CarteAccueil(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 20, color: texteDouxAccueil),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message?.isNotEmpty == true
                  ? message!
                  : "Les chiffres du jour n'ont pas pu être lus.",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.3, color: texteDouxAccueil),
            ),
          ),
          TextButton(
            onPressed: onReessayer,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Réessayer', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
