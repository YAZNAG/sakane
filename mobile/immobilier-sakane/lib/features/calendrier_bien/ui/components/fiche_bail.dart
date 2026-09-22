import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/cubit/calendrier_bien_cubit.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/routes.dart';

/// Resume d'un bail de longue duree, ouvert depuis le calendrier.
Future<void> ouvrirFicheBail(BuildContext contexte, CalendrierBienCubit cubit, BailCalendrier bail) async {
  final ouvrir = await showModalBottomSheet<bool>(
    context: contexte,
    backgroundColor: Colors.transparent,
    builder: (_) => _FicheBail(bail: bail),
  );
  if (ouvrir != true || !contexte.mounted) return;
  await GoRouter.of(contexte).push(Routes.bailDetail.replaceFirst(':id', '${bail.id}'));
  // Prolonge ou termine depuis la fiche : le calendrier suit.
  await cubit.rafraichir();
}

class _FicheBail extends StatelessWidget {
  final BailCalendrier bail;

  const _FicheBail({required this.bail});

  @override
  Widget build(BuildContext context) {
    final couleur = bail.actif ? CouleursCalendrier.bail : CouleursCalendrier.bailTermine;
    final nom = (bail.locataire ?? '').trim().isEmpty ? 'Locataire' : bail.locataire!.trim();
    final mois = (ecartJours(bail.du, bail.finExclue) / 30.4).round();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: CouleursCalendrier.bordure, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: couleur.withValues(alpha: .15),
                child: Icon(Icons.key_rounded, color: couleur),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
                    const SizedBox(height: 4),
                    PastilleBail(
                      texte: bail.actif ? 'Location longue durée' : 'Bail terminé',
                      couleur: couleur,
                    ),
                  ],
                ),
              ),
              BoutonsContact(tel: bail.tel),
            ],
          ),
          const SizedBox(height: 16),
          _ligne(Icons.date_range_outlined, 'Du ${dateMoyenne(bail.du)} au ${dateMoyenne(bail.au)}'
              '${mois > 0 ? ' (≈ $mois mois)' : ''}'),
          _ligne(Icons.payments_outlined, '${montantLisible(bail.loyer)} / mois'),
          if ((bail.tel ?? '').isNotEmpty) _ligne(Icons.phone_outlined, bail.tel!),
          if (peutVoirBaux) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Ouvrir le bail'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursCalendrier.bail,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ligne(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icone, size: 18, color: CouleursCalendrier.texteDoux),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
          ),
        ],
      ),
    );
  }
}
