import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';

/// Tableau de données dont la première ligne et la première colonne
/// restent visibles pendant le défilement.
///
/// Chaque colonne prend la largeur de son contenu : l'en-tête peut tenir
/// sur deux lignes, les valeurs sur une. Si le tableau est plus étroit que
/// l'écran, les colonnes s'élargissent pour l'occuper. Une ligne de totaux,
/// facultative, reste en bas et suit le défilement horizontal.
class TableauFige extends StatefulWidget {
  /// Libellé de la colonne figée (coin haut-gauche).
  final String enteteColonneFigee;

  /// En-têtes des colonnes défilantes.
  final List<String> entetes;

  /// Valeurs de la colonne figée, une par ligne.
  final List<String> colonneFigee;

  /// Corps du tableau : une liste de lignes, chacune de la même longueur
  /// que [entetes].
  final List<List<String>> lignes;

  /// Ligne de totaux, de la même longueur que [entetes]. Nulle : pas de
  /// ligne de totaux.
  final List<String>? totaux;
  final String libelleTotaux;

  /// Largeur minimale de la colonne figée ; elle s'élargit pour les noms
  /// longs, jusqu'à 42 % de l'écran.
  final double largeurColonneFigee;

  /// Conservée pour les écrans existants : largeur minimale d'une colonne.
  final double largeurColonne;
  final double hauteurLigne;

  const TableauFige({
    super.key,
    required this.enteteColonneFigee,
    required this.entetes,
    required this.colonneFigee,
    required this.lignes,
    this.totaux,
    this.libelleTotaux = 'TOTAL',
    this.largeurColonneFigee = 130,
    this.largeurColonne = 72,
    this.hauteurLigne = 46,
  });

  @override
  State<TableauFige> createState() => _TableauFigeState();
}

class _TableauFigeState extends State<TableauFige> {
  static const _caractere = 7.4;
  static const _hauteurEntete = 52.0;

  // défilement horizontal : en-têtes, corps et totaux
  final _hEntetes = ScrollController();
  final _hCorps = ScrollController();
  final _hTotaux = ScrollController();
  // défilement vertical : colonne figée et corps
  final _vColonne = ScrollController();
  final _vCorps = ScrollController();

  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _lier(_hCorps, [_hEntetes, _hTotaux]);
    _lier(_hEntetes, [_hCorps, _hTotaux]);
    _lier(_vCorps, [_vColonne]);
    _lier(_vColonne, [_vCorps]);
  }

  /// Reporte le défilement de [source] sur [cibles] sans boucler.
  void _lier(ScrollController source, List<ScrollController> cibles) {
    source.addListener(() {
      if (_enCours) return;
      _enCours = true;
      for (final cible in cibles) {
        if (cible.hasClients && cible.offset != source.offset) {
          cible.jumpTo(source.offset.clamp(0.0, cible.position.maxScrollExtent));
        }
      }
      _enCours = false;
    });
  }

  @override
  void dispose() {
    _hEntetes.dispose();
    _hCorps.dispose();
    _hTotaux.dispose();
    _vColonne.dispose();
    _vCorps.dispose();
    super.dispose();
  }

  /// La largeur de chaque colonne, d'après son en-tête (sur deux lignes au
  /// plus) et la plus longue de ses valeurs.
  List<double> _largeurs(double disponible) {
    final n = widget.entetes.length;
    final largeurs = List<double>.generate(n, (i) {
      final entete = widget.entetes[i];
      final plusLongMot = entete.split(' ').fold<int>(0, (m, w) => math.max(m, w.length));
      final surDeuxLignes = math.max(plusLongMot, (entete.length / 2).ceil());

      var contenu = 0;
      for (final ligne in widget.lignes) {
        if (i < ligne.length) contenu = math.max(contenu, ligne[i].length);
      }
      final totaux = widget.totaux;
      if (totaux != null && i < totaux.length) contenu = math.max(contenu, totaux[i].length);

      return (math.max(surDeuxLignes, contenu) * _caractere + 24)
          .clamp(math.max(64.0, widget.largeurColonne), 190.0)
          .toDouble();
    });

    final total = largeurs.fold<double>(0, (a, b) => a + b);
    if (total > 0 && total < disponible) {
      final facteur = disponible / total;
      return largeurs.map((l) => l * facteur).toList();
    }
    return largeurs;
  }

  BoxDecoration get _bordure => BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 0.6),
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.6),
        ),
      );

  Widget _cellule(String texte, double largeur,
      {bool entete = false, bool figee = false, bool total = false, bool pair = false}) {
    final fond = entete
        ? AppColors.primaryColor
        : total
            ? AppColors.primaryColor.withValues(alpha: .12)
            : figee
                ? const Color(0xFFF1F4F6)
                : (pair ? const Color(0xFFF8FAFB) : Colors.white);

    return Container(
      width: largeur,
      height: entete ? _hauteurEntete : widget.hauteurLigne,
      alignment: entete
          ? Alignment.center
          : (figee ? Alignment.centerLeft : Alignment.centerRight),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: _bordure.copyWith(color: fond),
      child: Text(
        texte,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: entete ? TextAlign.center : (figee ? TextAlign.left : TextAlign.right),
        style: TextStyle(
          fontSize: entete ? 12 : 12.5,
          height: 1.2,
          fontWeight: entete || figee || total ? FontWeight.w700 : FontWeight.normal,
          color: entete ? Colors.white : const Color(0xFF17262E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lignes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          "Aucune donnée sur cette période",
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final ecran = MediaQuery.of(context).size;
    final hauteurMax = ecran.height * .6;
    final hauteur = (widget.lignes.length * widget.hauteurLigne).clamp(0.0, hauteurMax).toDouble();

    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeurTotale = contraintes.maxWidth.isFinite ? contraintes.maxWidth : ecran.width;

        // La colonne figée s'élargit pour les noms longs, sans dépasser 42 %.
        final plusLongNom = widget.colonneFigee.fold<int>(
            widget.enteteColonneFigee.length, (m, t) => math.max(m, (t.length / 2).ceil()));
        final figee = (plusLongNom * _caractere + 24)
            .clamp(widget.largeurColonneFigee, math.max(widget.largeurColonneFigee, largeurTotale * .42))
            .toDouble();

        final largeurs = _largeurs(largeurTotale - figee - 2);
        final largeurCorps = largeurs.fold<double>(0, (a, b) => a + b);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- ligne d'en-tête ----
              Row(
                children: [
                  Container(
                    width: figee,
                    height: _hauteurEntete,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: _bordure.copyWith(color: AppColors.primaryColor),
                    child: Text(widget.enteteColonneFigee,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _hEntetes,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < widget.entetes.length; i++)
                            _cellule(widget.entetes[i], largeurs[i], entete: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ---- corps ----
              SizedBox(
                height: hauteur,
                child: Row(
                  children: [
                    SizedBox(
                      width: figee,
                      child: ListView.builder(
                        controller: _vColonne,
                        physics: const ClampingScrollPhysics(),
                        itemCount: widget.colonneFigee.length,
                        itemBuilder: (_, i) =>
                            _cellule(widget.colonneFigee[i], figee, figee: true),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _hCorps,
                        thumbVisibility: true,
                        notificationPredicate: (n) => n.depth == 0,
                        child: SingleChildScrollView(
                          controller: _hCorps,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: largeurCorps,
                            child: Scrollbar(
                              controller: _vCorps,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _vCorps,
                                physics: const ClampingScrollPhysics(),
                                itemCount: widget.lignes.length,
                                itemBuilder: (_, i) => Row(
                                  children: [
                                    for (var j = 0; j < largeurs.length; j++)
                                      _cellule(
                                        j < widget.lignes[i].length ? widget.lignes[i][j] : '',
                                        largeurs[j],
                                        pair: i.isOdd,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- totaux ----
              if (widget.totaux != null)
                Row(
                  children: [
                    _cellule(widget.libelleTotaux, figee, figee: true, total: true),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hTotaux,
                        scrollDirection: Axis.horizontal,
                        // La ligne suit le corps : elle ne se fait pas défiler seule.
                        physics: const NeverScrollableScrollPhysics(),
                        child: Row(
                          children: [
                            for (var j = 0; j < largeurs.length; j++)
                              _cellule(
                                j < widget.totaux!.length ? widget.totaux![j] : '',
                                largeurs[j],
                                total: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
