import 'package:flutter/material.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/vente.dart';

/// Le mandat qui compte pour le bien : celui que le serveur designe, sinon
/// le plus recent des mandats actifs, sinon le plus recent tout court.
MandatVente? mandatCourant(DossierVente d) {
  final designe = d.bien.mandat;
  if (designe != null) {
    for (final m in d.mandats) {
      if (m.id == designe.id) return m;
    }
    return designe;
  }
  if (d.mandats.isEmpty) return null;
  final tries = [...d.mandats]..sort((a, b) {
      if (a.actif != b.actif) return a.actif ? -1 : 1;
      return (b.dateSignature ?? DateTime(0)).compareTo(a.dateSignature ?? DateTime(0));
    });
  return tries.first;
}

/// « Mandat signé », « Mandat à signer » ou « Aucun mandat ».
class PastilleEtatMandat extends StatelessWidget {
  final MandatVente? mandat;

  const PastilleEtatMandat({super.key, required this.mandat});

  @override
  Widget build(BuildContext context) {
    final m = mandat;
    if (m == null) {
      return const PastilleBail(texte: 'Aucun mandat', couleur: CouleursVente.sansMandat, icone: Icons.warning_amber_rounded);
    }
    if (m.signe) {
      return const PastilleBail(texte: 'Mandat signé', couleur: CouleursVente.aVendre, icone: Icons.verified_outlined);
    }
    return const PastilleBail(texte: 'Mandat à signer', couleur: CouleursVente.sansMandat, icone: Icons.draw_outlined);
  }
}

/// Carte de suivi d'une vente : statut, mandat, visites et actions rapides.
class CarteSuiviVente extends StatelessWidget {
  final DossierVente dossier;
  final VoidCallback? onCreerMandat;
  final VoidCallback? onAjouterVisite;
  final VoidCallback? onOuvrir;

  const CarteSuiviVente({
    super.key,
    required this.dossier,
    this.onCreerMandat,
    this.onAjouterVisite,
    this.onOuvrir,
  });

  @override
  Widget build(BuildContext context) {
    final b = dossier.bien;
    final mandat = mandatCourant(dossier);
    final visites = dossier.visites.isNotEmpty ? dossier.visites.length : b.nbVisites;
    final actions = onCreerMandat != null || onAjouterVisite != null;
    final aSigner = dossier.visites.where((v) => !v.signe).length;
    return CarteBail(
      onTap: onOuvrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: CouleursVente.fondTeinte, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.sell_outlined, color: CouleursVente.teinte, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Suivi de la vente',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
              ),
              if (onOuvrir != null) const Icon(Icons.chevron_right, color: CouleursBail.texteDoux),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              PastilleStatutVente(statut: b.statutVente, libelle: b.statutVenteLibelle),
              PastilleEtatMandat(mandat: mandat),
              PastilleBail(
                texte: visites == 0 ? 'Aucune visite' : pluriel(visites, 'visite'),
                couleur: CouleursBail.texteDoux,
                icone: Icons.directions_walk,
              ),
              if (aSigner > 0)
                PastilleBail(
                  texte: aSigner == 1 ? '1 reçu à signer' : '$aSigner reçus à signer',
                  couleur: CouleursVente.sansMandat,
                  icone: Icons.draw_outlined,
                ),
            ],
          ),
          if (mandat != null) ...[
            const SizedBox(height: 8),
            Text(
              'Mandat du ${dateBail(mandat.dateSignature)}'
              '${mandat.dateFin == null ? '' : " • jusqu'au ${dateBail(mandat.dateFin)}"}'
              '${dossier.mandats.length > 1 ? ' • ${dossier.mandats.length} mandats' : ''}',
              style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
            ),
          ],
          if (actions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onCreerMandat != null)
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: onCreerMandat,
                        icon: const Icon(Icons.note_add_outlined, size: 19),
                        label: const Text('Créer un mandat', maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CouleursVente.teinte,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                if (onCreerMandat != null && onAjouterVisite != null) const SizedBox(width: 10),
                if (onAjouterVisite != null)
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: onAjouterVisite,
                        icon: const Icon(Icons.directions_walk, size: 19),
                        label: const Text('Ajouter une visite', maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CouleursVente.teinte,
                          side: const BorderSide(color: CouleursVente.teinte),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
