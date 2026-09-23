import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// Les deux teintes de sens qui manquaient à la palette de l'accueil :
/// le bleu de ce qui est réservé ou partiellement payé, le violet des
/// baux de longue durée.
const Color bleuCharte = Color(0xFF2C6FB5);
const Color violetCharte = Color(0xFF6D4AB0);

/// La barre de titre claire des écrans de gestion : un fond blanc, un
/// texte sombre, une fine ligne en bas. Elle remplace la barre verte :
/// les cartes blanches y gagnent en lisibilité.
AppBar appBarClaire({
  required String titre,
  String? sousTitre,
  List<Widget>? actions,
  Widget? retour,
  bool enCours = false,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.white,
    foregroundColor: texteAccueil,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: retour,
    titleSpacing: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          titre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: texteAccueil),
        ),
        if ((sousTitre ?? '').isNotEmpty)
          Text(
            sousTitre!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: texteDouxAccueil),
          ),
      ],
    ),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: Size.fromHeight(enCours ? 3 : 1),
      child: enCours
          ? const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primaryColor,
              backgroundColor: bordureAccueil,
            )
          : const Divider(height: 1, thickness: 1, color: bordureAccueil),
    ),
  );
}

/// Une carte compteur de la grille 2×2 : une pastille de couleur, le
/// libellé en petit gris, le nombre en très gros.
///
/// Le nombre est la donnée : il occupe la place, le reste l'annonce.
class CarteCompteur extends StatelessWidget {
  final String libelle;

  /// Null tant que le compte n'est pas connu : un tiret s'affiche.
  final int? nombre;
  final Color teinte;
  final VoidCallback? onTap;

  const CarteCompteur({
    super.key,
    required this.libelle,
    required this.nombre,
    required this.teinte,
    this.onTap,
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: teinte, shape: BoxShape.circle),
              ),
              const SizedBox(height: 10),
              Text(
                libelle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, height: 1.25, color: texteDouxAccueil),
              ),
              const SizedBox(height: 2),
              Text(
                nombre == null ? '—' : '$nombre',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: texteAccueil,
                  fontFeatures: chiffresTabulaires,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La pastille d'état de paiement d'un séjour : payé, partiel, reste dû,
/// ou Airbnb (qui ne s'encaisse pas ici).
class PastillePaiement extends StatelessWidget {
  final String libelle;
  final Color teinte;

  const PastillePaiement({
    super.key,
    required this.libelle,
    required this.teinte,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: teinte.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: teinte.withValues(alpha: .32)),
      ),
      child: Text(
        libelle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: teinte,
          fontFeatures: chiffresTabulaires,
        ),
      ),
    );
  }
}

/// Le bloc heure à gauche d'une carte de séjour : l'heure en gras, ce
/// qu'elle désigne en dessous, sur un aplat teinté.
class BlocHeure extends StatelessWidget {
  final String heure;
  final String libelle;
  final Color teinte;

  const BlocHeure({
    super.key,
    required this.heure,
    required this.libelle,
    required this.teinte,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: teinte.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            heure.isEmpty ? '—' : heure,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: teinte,
              fontFeatures: chiffresTabulaires,
            ),
          ),
          Text(
            libelle,
            maxLines: 1,
            style: TextStyle(
                fontSize: 10.5,
                color: teinte.withValues(alpha: .85),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Le nom d'un client, avec sa version arabe dessous quand elle existe.
///
/// L'arabe s'écrit de droite à gauche : le [Directionality] le remet
/// dans son sens, sans quoi la ponctuation se retrouverait du mauvais côté.
class NomClient extends StatelessWidget {
  final String nom;
  final String? nomArabe;
  final TextStyle style;

  const NomClient({
    super.key,
    required this.nom,
    this.nomArabe,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final arabe = (nomArabe ?? '').trim();
    if (arabe.isEmpty) {
      return Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            arabe,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(
                fontSize: (style.fontSize ?? 13) - .5, color: texteDouxAccueil),
          ),
        ),
      ],
    );
  }
}

/// Une ligne discrète, quand une liste du jour est vide : elle dit que
/// la journée est calme, pas que la lecture a échoué.
class LigneVide extends StatelessWidget {
  final String texte;

  const LigneVide({super.key, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        children: [
          const Icon(Icons.remove_rounded, size: 14, color: texteDouxAccueil),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 12.5, color: texteDouxAccueil),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un titre de section des listes du jour, avec le nombre d'éléments
/// à sa droite.
///
/// Le nom évite « TitreSection », déjà pris par le module des baux : les
/// deux écrans se croisent dans les mêmes fichiers.
class TitreDuJour extends StatelessWidget {
  final String titre;
  final int? nombre;

  const TitreDuJour({super.key, required this.titre, this.nombre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Text(
        nombre == null ? titre : '$titre · $nombre',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: texteAccueil,
          fontFeatures: chiffresTabulaires,
        ),
      ),
    );
  }
}
