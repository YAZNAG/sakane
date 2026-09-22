import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bien_desactive.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/repository.dart';

/// Droit « Désactiver un bien » (l'administrateur l'a). Un utilisateur
/// pas encore chargé n'a simplement pas le droit.
bool peutDesactiverBien() {
  try {
    return Dependencies.get<Manager>().can(AppPermission.deactivateProperty);
  } catch (_) {
    return false;
  }
}

/// Droit « Réactiver un bien ».
bool peutReactiverBien() {
  try {
    return Dependencies.get<Manager>().can(AppPermission.reactivateProperty);
  } catch (_) {
    return false;
  }
}

/// Droit « Voir les biens désactivés ».
bool peutVoirBiensDesactives() {
  try {
    return Dependencies.get<Manager>().can(AppPermission.viewDeactivatedProperties);
  } catch (_) {
    return false;
  }
}

/// L'action utile pour ce bien : réactiver s'il est désactivé, sinon
/// désactiver.
bool peutChangerActivationBien(bool desactive) =>
    desactive ? peutReactiverBien() : peutDesactiverBien();

const Color couleurDesactivation = Color(0xFFC62828);

/// Bandeau rouge « Bien désactivé le … » en tete des fiches du bien.
class BandeauBienDesactive extends StatelessWidget {
  final DateTime desactiveLe;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const BandeauBienDesactive({super.key, required this.desactiveLe, this.margin, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: couleurDesactivation.withValues(alpha: 0.08),
        borderRadius: borderRadius,
        border: borderRadius == null ? null : Border.all(color: couleurDesactivation.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined, color: couleurDesactivation, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bien désactivé le ${desactiveLe.toLocal().formattedDateFr}',
                  style: const TextStyle(color: couleurDesactivation, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Il n'apparaît plus dans les listes, les réservations, le calendrier ni les statistiques.",
                  style: TextStyle(color: couleurDesactivation, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton explicite « Désactiver le bien » (contour rouge) ou
/// « Réactiver le bien » (vert) selon l'etat du bien.
class BoutonDesactivationBien extends StatelessWidget {
  final bool desactive;
  final VoidCallback onDesactiver;
  final VoidCallback onReactiver;

  const BoutonDesactivationBien({
    super.key,
    required this.desactive,
    required this.onDesactiver,
    required this.onReactiver,
  });

  @override
  Widget build(BuildContext context) {
    final forme = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const texte = TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold);
    if (!peutChangerActivationBien(desactive)) return const SizedBox.shrink();
    if (desactive) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onReactiver,
          icon: const Icon(Icons.restore, size: 22),
          label: const Text('Réactiver le bien', style: texte),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: forme,
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onDesactiver,
        icon: const Icon(Icons.visibility_off_outlined, size: 22),
        label: const Text('Désactiver le bien', style: texte),
        style: OutlinedButton.styleFrom(
          foregroundColor: couleurDesactivation,
          backgroundColor: Colors.white,
          side: const BorderSide(color: couleurDesactivation, width: 1.4),
          shape: forme,
        ),
      ),
    );
  }
}

/// Appui long sur une carte de bien : feuille d'actions avec « Désactiver ».
/// Rend true si le bien a ete desactive (la liste doit se recharger).
Future<bool> actionsBienParAppuiLong(BuildContext context, {required int bienId, String? titre}) async {
  final choix = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((titre ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(titre!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined, color: couleurDesactivation),
            title: const Text('Désactiver le bien',
                style: TextStyle(color: couleurDesactivation, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.of(ctx).pop('desactiver'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choix != 'desactiver' || !context.mounted) return false;
  return desactiverBienAvecDialogue(context, bienId);
}

/// Demande le motif puis desactive le bien. Rend true en cas de succes.
Future<bool> desactiverBienAvecDialogue(BuildContext context, int bienId) async {
  final motif = await showDialog<String>(
    context: context,
    builder: (_) => const _DialogueDesactivation(),
  );
  if (motif == null || !context.mounted) return false;
  try {
    await Dependencies.get<Repository>().desactiverBien(bienId, motif: motif);
    if (context.mounted) afficherMessage(context, 'Bien désactivé');
    return true;
  } catch (ex) {
    if (context.mounted) afficherMessage(context, messageErreur(ex), erreur: true);
    return false;
  }
}

/// Confirme puis reactive le bien. Rend le bien reactive, ou null.
Future<BienDesactive?> reactiverBienAvecDialogue(BuildContext context, int bienId, {String? titre}) async {
  final ok = await confirmer(
    context,
    titre: 'Réactiver le bien',
    message: (titre ?? '').isEmpty
        ? 'Le bien réapparaîtra dans les listes, les réservations, le calendrier et les statistiques.'
        : '« $titre » réapparaîtra dans les listes, les réservations, le calendrier et les statistiques.',
    action: 'Réactiver',
    couleur: Colors.green.shade700,
  );
  if (!ok || !context.mounted) return null;
  try {
    final bien = await Dependencies.get<Repository>().reactiverBien(bienId);
    if (context.mounted) afficherMessage(context, 'Bien réactivé');
    return bien;
  } catch (ex) {
    if (context.mounted) afficherMessage(context, messageErreur(ex), erreur: true);
    return null;
  }
}

/// Explication + motif facultatif. Rend le motif (eventuellement vide), ou null si annule.
class _DialogueDesactivation extends StatefulWidget {
  const _DialogueDesactivation();

  @override
  State<_DialogueDesactivation> createState() => _DialogueDesactivationState();
}

class _DialogueDesactivationState extends State<_DialogueDesactivation> {
  final TextEditingController _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Désactiver le bien', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Le bien n'apparaîtra plus dans les listes, les réservations, le calendrier ni les "
              "statistiques à partir d'aujourd'hui. Son historique est conservé et vous pourrez le réactiver.",
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motif,
              maxLength: 255,
              maxLines: 2,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Motif',
                hintText: 'Facultatif',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_motif.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: couleurDesactivation,
            foregroundColor: Colors.white,
          ),
          child: const Text('Désactiver'),
        ),
      ],
    );
  }
}
