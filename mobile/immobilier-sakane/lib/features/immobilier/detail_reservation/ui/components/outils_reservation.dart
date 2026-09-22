import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:path_provider/path_provider.dart';

/// Rapatrie un contrat depuis son adresse puis l'affiche.
Future<void> ouvrirContratDistant(BuildContext context, String url, {String titre = 'Contrat'}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final dir = await getTemporaryDirectory();
    final nom = url.split('/').last.split('?').first;
    // Horodate : le visualiseur garderait sinon l'ancienne version en cache.
    final chemin = '${dir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$nom';
    await Dio().download(url, chemin);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    await VisionneuseContrat.ouvrir(context, chemin: chemin, titre: titre);
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    afficherMessage(context, "Le contrat n'a pas pu être ouvert.", erreur: true);
  }
}

/// Apres un changement de prix, les contrats ont ete regeneres :
/// on propose de les relire.
Future<void> proposerNouveauContrat(BuildContext context, DetailReservation d) async {
  final prive = d.contratPrive, public = d.contratPublic;
  if (prive == null && public == null) return;
  final choix = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Nouveau contrat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: const Text(
        "Les contrats ont été régénérés avec l'ancien et le nouveau prix. Voulez-vous les consulter ?",
        style: TextStyle(fontSize: 13.5, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Plus tard')),
        if (public != null)
          TextButton(onPressed: () => Navigator.of(ctx).pop(public), child: const Text('Contrat public')),
        if (prive != null)
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(prive),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Contrat privé'),
          ),
      ],
    ),
  );
  if (choix == null || !context.mounted) return;
  await ouvrirContratDistant(context, choix, titre: choix == prive ? 'Contrat privé' : 'Contrat public');
}

/// « 14:00:00 » → « 14:00 ».
String heureCourte(String? h) {
  if (h == null || h.isEmpty) return '';
  return h.length >= 5 ? h.substring(0, 5) : h;
}

/// « 12/03/2026 à 14:05 ».
String dateHeureFr(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String deux(int n) => n.toString().padLeft(2, '0');
  final heure = (l.hour == 0 && l.minute == 0) ? '' : ' à ${deux(l.hour)}:${deux(l.minute)}';
  return '${deux(l.day)}/${deux(l.month)}/${l.year}$heure';
}

/// Bande de titre commune aux feuilles du bas.
class PoigneeFeuille extends StatelessWidget {
  const PoigneeFeuille({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD5DDE2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

/// Petite pastille coloree (statut, « Modifiée », « Payée »…).
class PastilleReservation extends StatelessWidget {
  final String texte;
  final Color couleur;
  final IconData? icone;

  const PastilleReservation({super.key, required this.texte, required this.couleur, this.icone});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 13, color: couleur),
              const SizedBox(width: 4),
            ],
            Text(texte, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur)),
          ],
        ),
      );
}
