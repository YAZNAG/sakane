import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/apercu_commun.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';

/// L'icône et la couleur d'un dossier.
///
/// Le serveur ne les connaît pas : ce sont des repères de lecture, pas
/// une donnée du dossier. Ils restent donc sur ce téléphone, comme les
/// brouillons — chacun range sa grille comme il la reconnaît.
///
/// Sans choix, l'apparence se déduit de l'identifiant du dossier : elle
/// est alors stable, ce qui suffit à distinguer deux dossiers voisins.
class ApparenceDossier {
  final IconData icone;
  final Color couleur;

  const ApparenceDossier({required this.icone, required this.couleur});
}

/// Les icônes proposées, dans l'ordre de la feuille de choix.
const List<IconData> iconesDossier = [
  Icons.folder_outlined,
  Icons.apartment_rounded,
  Icons.home_work_outlined,
  Icons.villa_outlined,
  Icons.holiday_village_outlined,
  Icons.business_outlined,
  Icons.location_city_rounded,
  Icons.beach_access_rounded,
  Icons.cottage_outlined,
  Icons.vpn_key_outlined,
];

/// Les couleurs proposées : celles de la charte, et rien d'autre.
const List<Color> couleursDossier = [
  AppColors.primaryColor,
  vertAccueil,
  bleuCharte,
  orangeAccueil,
  rougeAccueil,
  violetCharte,
];

/// Lit et écrit l'apparence des dossiers sur ce téléphone.
class ApparencesDossiers {
  static const String _cle = 'apparence_dossiers';

  static SharedPrefService? get _prefs {
    try {
      return Dependencies.get<SharedPrefService>();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _tout() {
    try {
      final brut = _prefs?.getValue<String>(_cle, '') ?? '';
      if (brut.isEmpty) return {};
      final lu = jsonDecode(brut);
      return lu is Map ? Map<String, dynamic>.from(lu) : {};
    } catch (_) {
      return {};
    }
  }

  static void _ecrire(Map<String, dynamic> tout) {
    try {
      _prefs?.putValue(_cle, jsonEncode(tout));
    } catch (_) {}
  }

  /// L'apparence d'un dossier : celle choisie, ou celle que son
  /// identifiant lui donne.
  static ApparenceDossier de(int? dossierId) {
    if (dossierId == null) {
      return const ApparenceDossier(
          icone: Icons.folder_off_outlined, couleur: texteDouxAccueil);
    }

    final enregistre = _tout()['$dossierId'];
    var iIcone = dossierId % iconesDossier.length;
    var iCouleur = dossierId % couleursDossier.length;

    if (enregistre is Map) {
      final i = enregistre['i'];
      final c = enregistre['c'];
      if (i is int && i >= 0 && i < iconesDossier.length) iIcone = i;
      if (c is int && c >= 0 && c < couleursDossier.length) iCouleur = c;
    }

    return ApparenceDossier(
      icone: iconesDossier[iIcone],
      couleur: couleursDossier[iCouleur],
    );
  }

  /// Enregistre le choix d'un dossier.
  static void enregistrer(int dossierId, int indexIcone, int indexCouleur) {
    final tout = _tout();
    tout['$dossierId'] = {'i': indexIcone, 'c': indexCouleur};
    _ecrire(tout);
  }

  /// Oublie le choix d'un dossier : l'apparence revient à celle que son
  /// identifiant lui donne.
  static void oublier(int dossierId) {
    final tout = _tout();
    if (tout.remove('$dossierId') != null) _ecrire(tout);
  }

  /// La feuille de choix. Rend vrai quand l'apparence a changé.
  static Future<bool> choisir(
    BuildContext context, {
    required int dossierId,
    required String nom,
  }) async {
    final actuelle = de(dossierId);
    var iIcone = iconesDossier.indexOf(actuelle.icone);
    var iCouleur = couleursDossier.indexOf(actuelle.couleur);
    if (iIcone < 0) iIcone = 0;
    if (iCouleur < 0) iCouleur = 0;

    final valide = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (feuille) => StatefulBuilder(
        builder: (feuille, rafraichir) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: texteAccueil),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Le repère reste sur ce téléphone : vos collègues gardent le leur.",
                  style: TextStyle(fontSize: 12, color: texteDouxAccueil),
                ),
                const SizedBox(height: 14),
                const Text('Icône',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: texteAccueil)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: List.generate(iconesDossier.length, (i) {
                    final actif = i == iIcone;
                    return InkWell(
                      onTap: () => rafraichir(() => iIcone = i),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: actif
                              ? couleursDossier[iCouleur].withValues(alpha: .14)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: actif
                                ? couleursDossier[iCouleur]
                                : bordureAccueil,
                            width: actif ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(iconesDossier[i],
                            size: 21,
                            color: actif
                                ? couleursDossier[iCouleur]
                                : texteDouxAccueil),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('Couleur',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: texteAccueil)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 11,
                  runSpacing: 9,
                  children: List.generate(couleursDossier.length, (i) {
                    final actif = i == iCouleur;
                    return InkWell(
                      onTap: () => rafraichir(() => iCouleur = i),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: couleursDossier[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: actif ? texteAccueil : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: actif
                            ? const Icon(Icons.check_rounded,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(feuille).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: texteDouxAccueil,
                          side: const BorderSide(color: bordureAccueil),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(feuille).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (valide != true) return false;
    enregistrer(dossierId, iIcone, iCouleur);
    return true;
  }
}
