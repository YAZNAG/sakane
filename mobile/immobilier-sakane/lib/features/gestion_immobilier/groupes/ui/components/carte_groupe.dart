import 'package:flutter/material.dart';

/// Carte de groupe : un compteur à gauche, le libellé et l'action à droite,
/// sur un dégradé propre à chaque catégorie.
class CarteGroupe extends StatelessWidget {
  /// Null tant que le compte n'est pas connu : un tiret s'affiche.
  final int? nombre;

  /// Unite sous le compteur (« LOCATAIRES », « VISITES »…) ; BIEN(S) par defaut.
  final String? unite;

  final String titre;
  final String sousTitre;
  final String libelleAction;
  final IconData icone;
  final List<Color> degrade;
  final VoidCallback? onTap;

  /// Actions secondaires, presentees par un bouton discret.
  final VoidCallback? onMenu;

  const CarteGroupe({
    super.key,
    required this.nombre,
    required this.titre,
    required this.sousTitre,
    required this.libelleAction,
    required this.icone,
    required this.degrade,
    this.onTap,
    this.onMenu,
    this.unite,
  });

  @override
  Widget build(BuildContext context) {
    // Un groupe vide reste affiché mais s'efface visuellement : la
    // structure des catégories demeure lisible d'un coup d'œil.
    final vide = nombre == 0;

    return Opacity(
      opacity: vide ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: degrade,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: degrade.first.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _compteur(),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    Expanded(child: _contenu()),
                    if (onMenu != null)
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: onMenu,
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          tooltip: "Actions",
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compteur() {
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              nombre == null ? "—" : "$nombre",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            unite ?? ((nombre ?? 0) > 1 ? "BIENS" : "BIEN"),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _MotifPoints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icone, color: Colors.white, size: 26),
        const SizedBox(height: 4),
        Text(
          titre,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sousTitre,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  libelleAction,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

/// Trame de points discrète, sous le compteur.
class _MotifPoints extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()..color = Colors.white.withValues(alpha: 0.22);
    const pas = 11.0;
    const rayon = 1.7;

    for (double y = rayon; y < size.height; y += pas) {
      for (double x = rayon; x < size.width; x += pas) {
        canvas.drawCircle(Offset(x, y), rayon, peinture);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
