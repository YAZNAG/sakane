import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/brouillons.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/routes.dart';

/// Chemin de l'ajout d'un bien : famille et dossier preselectionnes, ou brouillon repris.
String cheminAjoutBien({String? type, int? dossier, String? brouillon}) {
  final parametres = {
    if (type != null) 'type': type,
    if (dossier != null) 'dossier': '$dossier',
    if (brouillon != null) 'brouillon': brouillon,
  };
  return Uri(path: Routes.addImmobilier, queryParameters: parametres.isEmpty ? null : parametres).toString();
}

const Map<String, String> _libellesEtapes = {
  // Anciens brouillons de vente : la reprise se fait aux informations de base.
  'mandat': 'Informations de base',
  'signature': 'Informations de base',
  'base': 'Informations de base',
  'location': 'Localisation',
  'details': 'Détails',
  'features': 'Équipements',
  'images': 'Photos',
};

String _quand(DateTime d) {
  final h = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final jour = DateTime(d.year, d.month, d.day);
  if (jour == aujourdhui()) return "aujourd'hui à $h";
  return 'le ${dateMoyenne(jour)} à $h';
}

/// Rappel : un brouillon ne quitte pas le telephone.
class MentionBrouillonsLocaux extends StatelessWidget {
  const MentionBrouillonsLocaux({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.phone_android, size: 16, color: CouleursBail.texteDoux),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Brouillons gardés sur ce téléphone uniquement : ils ne sont pas visibles par vos collègues.',
            style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux),
          ),
        ),
      ],
    );
  }
}

/// Un brouillon : photo, titre, etape atteinte, date ; reprendre ou supprimer.
class CarteBrouillon extends StatelessWidget {
  final BrouillonBien brouillon;
  final VoidCallback onReprendre;
  final VoidCallback onSupprimer;

  const CarteBrouillon({super.key, required this.brouillon, required this.onReprendre, required this.onSupprimer});

  @override
  Widget build(BuildContext context) {
    final b = brouillon;
    final fichiers = b.fichiers;
    return CarteBail(
      onTap: onReprendre,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 62,
              height: 62,
              child: fichiers.isEmpty
                  ? Container(
                      color: CouleursBail.fond,
                      child: const Icon(Icons.edit_note, color: CouleursBail.texteDoux, size: 30),
                    )
                  : Image.file(File(fichiers.first.path), fit: BoxFit.cover, cacheWidth: 180),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                Text('Modifié ${_quand(b.modifieLe)}',
                    style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    PastilleBail(
                      texte: 'Étape : ${_libellesEtapes[b.etape] ?? b.etape}',
                      couleur: CouleursBail.aPayer,
                      icone: Icons.flag_outlined,
                    ),
                    if (b.mandatId != null)
                      PastilleBail(
                        texte: b.mandatSigne ? 'Mandat signé' : 'Mandat non signé',
                        couleur: b.mandatSigne ? CouleursVente.aVendre : CouleursVente.sansMandat,
                        icone: Icons.assignment_outlined,
                      ),
                    if ((b.dossierNom ?? '').isNotEmpty)
                      PastilleBail(texte: b.dossierNom!, couleur: CouleursBail.texteDoux, icone: Icons.folder_outlined),
                    if (fichiers.isNotEmpty)
                      PastilleBail(texte: pluriel(fichiers.length, 'photo'), couleur: CouleursBail.texteDoux),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: CouleursBail.texteDoux),
            color: Colors.white,
            onSelected: (a) => a == 'reprendre' ? onReprendre() : onSupprimer(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reprendre', child: Text('Reprendre')),
              PopupMenuItem(
                  value: 'supprimer', child: Text('Supprimer le brouillon', style: TextStyle(color: CouleursBail.retard))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Confirme puis supprime ; rend vrai si le brouillon a ete supprime.
Future<bool> supprimerBrouillon(BuildContext context, BrouillonBien b) async {
  final ok = await confirmer(
    context,
    titre: 'Supprimer le brouillon ?',
    message: '« ${b.titre} » et ses photos seront effacés de ce téléphone.',
    action: 'Supprimer',
    couleur: CouleursBail.retard,
  );
  if (!ok) return false;
  await Brouillons.supprimer(b.id);
  return true;
}

/// « Mes brouillons » : rend le brouillon a reprendre, ou null.
Future<BrouillonBien?> ouvrirBrouillons(BuildContext context, {String? type, int? dossierId}) {
  return showModalBottomSheet<BrouillonBien>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CouleursBail.fond,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ListeBrouillons(type: type, dossierId: dossierId),
  );
}

class _ListeBrouillons extends StatefulWidget {
  final String? type;
  final int? dossierId;

  const _ListeBrouillons({this.type, this.dossierId});

  @override
  State<_ListeBrouillons> createState() => _ListeBrouillonsState();
}

class _ListeBrouillonsState extends State<_ListeBrouillons> {
  late List<BrouillonBien> _liste = _lire();

  List<BrouillonBien> _lire() => Brouillons.filtrer(type: widget.type, dossierId: widget.dossierId);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: CouleursBail.texte),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Mes brouillons',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: MentionBrouillonsLocaux(),
            ),
            Expanded(
              child: _liste.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          "Aucun brouillon.\nPendant l'ajout d'un bien, « Enregistrer comme brouillon » garde la saisie pour la reprendre plus tard.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: CouleursBail.texteDoux, height: 1.4),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                      itemCount: _liste.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => CarteBrouillon(
                        brouillon: _liste[i],
                        onReprendre: () => Navigator.of(context).pop(_liste[i]),
                        onSupprimer: () async {
                          if (await supprimerBrouillon(context, _liste[i]) && mounted) {
                            setState(() => _liste = _lire());
                          }
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
