import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/ui/components/mandat_outils.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

// Outils du recu de visite (وصل زيارة عقار) : signature du client,
// consultation et envoi du recu.

/// « Signé » en vert, ou « À signer » en orange.
class PastilleSignatureVisite extends StatelessWidget {
  final VisiteVente visite;

  const PastilleSignatureVisite({super.key, required this.visite});

  @override
  Widget build(BuildContext context) {
    if (visite.signe) {
      return PastilleBail(
        texte: visite.signeLe == null ? 'Signé' : 'Signé le ${dateBail(visite.signeLe)}',
        couleur: CouleursVente.aVendre,
        icone: Icons.draw_outlined,
      );
    }
    return const PastilleBail(texte: 'À signer', couleur: CouleursVente.sansMandat, icone: Icons.edit_outlined);
  }
}

/// Fait signer le client sur le pave plein ecran puis envoie la signature.
/// Rend la visite signee, ou null (« Signer plus tard » ou erreur).
Future<VisiteVente?> faireSignerVisite(BuildContext context, VisiteVente visite) async {
  final png = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PaveSignaturePage(
      titre: 'Signature du client',
      nom: visite.visiteurNom,
      mention: 'Je confirme avoir visité le bien présenté par l’agence (وصل زيارة عقار).',
      plusTard: 'Signer plus tard',
      messageVide: "Le client n'a pas encore signé.",
    ),
  ));
  if (png == null || !context.mounted) return null;

  final navigateur = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
  VisiteVente? signee;
  String? erreur;
  try {
    signee = await Dependencies.get<Repository>().signerVisiteVente(visite.id, png);
  } catch (ex) {
    erreur = messageErreurBail(ex);
  }
  navigateur.pop();
  if (!context.mounted) return signee;
  if (signee == null) {
    afficherMessage(context, erreur ?? "La signature n'a pas pu être enregistrée.", erreur: true);
    return null;
  }
  afficherMessage(context, 'Reçu signé par le client.');
  return signee;
}

/// Le PDF du recu dans la visionneuse de l'application.
Future<void> voirRecuVisite(BuildContext context, VisiteVente v) => ouvrirPdfBail(
      context,
      () => Dependencies.get<Repository>().telechargerRecuVisite(v.id),
      'Reçu de visite',
    );

/// Bouton « Faire signer le client », a n'afficher que si le recu n'est pas signe.
class BoutonSignerVisite extends StatelessWidget {
  final VoidCallback? onPressed;

  const BoutonSignerVisite({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.draw_outlined, size: 19),
        label: const Text('Faire signer le client', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: CouleursVente.sansMandat,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
