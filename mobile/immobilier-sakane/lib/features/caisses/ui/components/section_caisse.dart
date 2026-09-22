import 'package:flutter/material.dart';

import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/caisses/ui/components/motifs_caisse.dart';

/// Un bloc de l'écran de la caisse : un en-tête qu'on touche pour
/// ouvrir ou fermer, et son contenu.
///
/// L'en-tête dit à lui seul ce que le bloc contient — un nombre, un
/// total — pour qu'on sache s'il vaut la peine de l'ouvrir. L'état
/// d'ouverture est tenu par l'écran, pas par la section : il survit
/// ainsi aux rechargements de la liste.
class SectionCaisse extends StatelessWidget {
  final IconData icone;

  /// La teinte de la pastille. Celle du thème par défaut.
  final Color? teinte;

  final String titre;

  /// Le compteur, sous le titre : « 3 opérations ».
  final String? compteur;

  /// Le total, à droite du titre.
  final String? total;
  final Color? couleurTotal;

  final bool ouverte;
  final VoidCallback onBascule;
  final Widget enfant;

  const SectionCaisse({
    super.key,
    required this.icone,
    required this.titre,
    required this.ouverte,
    required this.onBascule,
    required this.enfant,
    this.teinte,
    this.compteur,
    this.total,
    this.couleurTotal,
  });

  @override
  Widget build(BuildContext context) {
    final t = teinte ?? AppColors.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: couleurBordureCaisse),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onBascule,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 9, 11),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icone, size: 19, color: t),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: couleurTexteCaisse),
                        ),
                        if (compteur != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            compteur!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: couleurTexteDouxCaisse),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (total != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      total!,
                      style: styleMontantCaisse(
                          taille: 14.5,
                          couleur: couleurTotal ?? couleurTexteCaisse),
                    ),
                  ],
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: ouverte ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: const Icon(Icons.expand_more,
                        size: 22, color: couleurTexteDouxCaisse),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ouverte
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(
                          height: 1, thickness: 1, color: Color(0xFFEEF1F4)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: enfant,
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Ce qu'une section affiche quand elle est vide : une phrase, pas un
/// écran entier.
class VideSectionCaisse extends StatelessWidget {
  final IconData icone;
  final String texte;

  const VideSectionCaisse(this.texte,
      {super.key, this.icone = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.35, color: couleurTexteDouxCaisse),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'écran vide de son contenu pendant le chargement : la forme des
/// cartes se devine avant que les chiffres arrivent.
class SqueletteCaisse extends StatelessWidget {
  /// Le nombre de sections esquissées sous la carte du solde.
  final int sections;

  const SqueletteCaisse({super.key, this.sections = 3});

  @override
  Widget build(BuildContext context) {
    return _Pulsation(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E9ED),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < sections; i++)
            Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: couleurBordureCaisse),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EEF2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 11,
                            width: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EEF2),
                              borderRadius: BorderRadius.circular(4),
                            )),
                        const SizedBox(height: 6),
                        Container(
                            height: 9,
                            width: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF3F6),
                              borderRadius: BorderRadius.circular(4),
                            )),
                      ],
                    ),
                  ),
                  Container(
                      height: 12,
                      width: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEF2),
                        borderRadius: BorderRadius.circular(4),
                      )),
                  const SizedBox(width: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Un battement lent : le squelette respire au lieu de rester figé.
class _Pulsation extends StatefulWidget {
  final Widget child;

  const _Pulsation({required this.child});

  @override
  State<_Pulsation> createState() => _PulsationState();
}

class _PulsationState extends State<_Pulsation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: .55, end: 1).animate(
        CurvedAnimation(parent: _controleur, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
