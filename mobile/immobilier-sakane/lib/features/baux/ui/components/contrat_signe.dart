import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/repository/repository.dart';

/// Le contrat revenu signe et legalise.
///
/// Le PDF que l'application fabrique n'est qu'un modele : ce qui compte, au
/// dossier, c'est l'exemplaire que les deux parties ont signe et fait
/// legaliser. Cette section le garde avec le bail, et le rend consultable.
class SectionContratSigne extends StatelessWidget {
  final Bail bail;

  /// Joint les pieces choisies ; renvoie l'erreur, ou null si c'est passe.
  final Future<String?> Function(List<File> fichiers) onJoindre;

  /// Retire une piece ; renvoie l'erreur, ou null.
  final Future<String?> Function(int mediaId) onSupprimer;

  /// Vrai pendant une operation : les boutons se taisent.
  final bool enCours;

  /// Faux pour un lecteur qui n'a pas le droit de toucher au dossier.
  final bool modifiable;

  const SectionContratSigne({
    super.key,
    required this.bail,
    required this.onJoindre,
    required this.onSupprimer,
    this.enCours = false,
    this.modifiable = true,
  });

  @override
  Widget build(BuildContext context) {
    final pieces = bail.contratsSignes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitreSection(
          texte: pieces.isEmpty ? 'Contrat signé' : 'Contrat signé (${pieces.length})',
          icone: Icons.verified_outlined,
        ),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pieces.isEmpty)
                const Text(
                  'Joignez ici le contrat une fois signé par les deux parties et '
                  'légalisé. Il restera consultable et téléchargeable depuis cette fiche.',
                  style: TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
                )
              else
                for (final p in pieces) ...[
                  _Piece(
                    piece: p,
                    photos: pieces.where((x) => !x.pdf).toList(),
                    enCours: enCours,
                    modifiable: modifiable,
                    onSupprimer: () => _retirer(context, p),
                  ),
                  if (p != pieces.last) Divider(height: 14, color: Colors.grey.shade200),
                ],
              if (modifiable) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: enCours ? null : () => _joindre(context),
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text(pieces.isEmpty ? 'Joindre le contrat signé' : 'Ajouter une pièce'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CouleursBail.teinte,
                      side: const BorderSide(color: CouleursBail.teinte),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('PDF ou photos, 12 Mo par fichier.',
                    style: TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _joindre(BuildContext context) async {
    final choix = await FilePicker.pickFiles(
      dialogTitle: 'Contrat signé et légalisé',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final chemins = choix
        .map((f) => f.path)
        .whereType<String>()
        .map(File.new)
        .toList();
    if (chemins.isEmpty || !context.mounted) return;

    // Le serveur refuse au-dela de 12 Mo : autant le dire tout de suite.
    final trop = chemins.where((f) => f.lengthSync() > 12 * 1024 * 1024).toList();
    if (trop.isNotEmpty) {
      afficherMessage(context,
          'Un fichier dépasse 12 Mo : ${_nomDe(trop.first.path)}. Réduisez-le avant de le joindre.',
          erreur: true);
      return;
    }

    final erreur = await onJoindre(chemins);
    if (!context.mounted) return;
    afficherMessage(
      context,
      erreur ?? (chemins.length == 1 ? 'Contrat signé joint.' : '${chemins.length} pièces jointes.'),
      erreur: erreur != null,
    );
  }

  Future<void> _retirer(BuildContext context, PieceContratSigne p) async {
    final ok = await confirmer(
      context,
      titre: 'Retirer cette pièce ?',
      message: 'La pièce « ${p.nom} » sera retirée du dossier du bail.',
      action: 'Retirer',
      couleur: CouleursBail.retard,
    );
    if (ok != true || !context.mounted) return;
    final erreur = await onSupprimer(p.id);
    if (!context.mounted) return;
    afficherMessage(context, erreur ?? 'Pièce retirée.', erreur: erreur != null);
  }

  static String _nomDe(String chemin) => chemin.split(RegExp(r'[\\/]')).last;
}

class _Piece extends StatelessWidget {
  final PieceContratSigne piece;
  final List<PieceContratSigne> photos;
  final bool enCours;
  final bool modifiable;
  final VoidCallback onSupprimer;

  const _Piece({
    required this.piece,
    required this.photos,
    required this.enCours,
    required this.modifiable,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (piece.pdf ? CouleursBail.retard : CouleursBail.aPayer).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(piece.pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
              size: 20, color: piece.pdf ? CouleursBail.retard : CouleursBail.aPayer),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(piece.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: CouleursBail.texte)),
              Text(
                [
                  piece.tailleLisible,
                  if (piece.ajouteLe != null) dateBail(DateTime.tryParse(piece.ajouteLe!)),
                ].join(' • '),
                style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Voir',
          onPressed: () => _ouvrir(context),
          icon: const Icon(Icons.visibility_outlined, size: 20, color: CouleursBail.teinte),
        ),
        if (modifiable)
          IconButton(
            tooltip: 'Retirer',
            onPressed: enCours ? null : onSupprimer,
            icon: const Icon(Icons.delete_outline, size: 20, color: CouleursBail.retard),
          ),
      ],
    );
  }

  /// Un PDF s'ouvre dans la visionneuse — qui sait aussi l'enregistrer ou le
  /// partager ; une photo s'ouvre dans la galerie.
  Future<void> _ouvrir(BuildContext context) async {
    if (!piece.pdf) {
      final index = photos.indexWhere((p) => p.id == piece.id);
      await showDialog(
        context: context,
        builder: (_) => ImagesGalery(
          medias: [for (final p in photos) Media(id: p.id, url: p.url)],
          index: index < 0 ? 0 : index,
        ),
      );
      return;
    }
    await ouvrirPdfBail(
      context,
      () => Dependencies.get<Repository>().telechargerPieceBail(piece.url, piece.id),
      'Contrat signé',
    );
  }
}
