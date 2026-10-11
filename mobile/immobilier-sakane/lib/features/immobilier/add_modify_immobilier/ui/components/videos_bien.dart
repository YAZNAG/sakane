import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/models/media.dart';

/// La visite filmee d'un bien.
///
/// Deux photos ne disent pas ce qu'une video dit d'un logement : on y suit le
/// couloir, on voit la lumiere tomber. Le bien en accepte deux au plus, de
/// soixante megaoctets chacune — au-dela, l'envoi n'aboutirait pas depuis un
/// telephone.
class VideosBien extends StatelessWidget {
  /// Les videos deja en ligne.
  final List<Media> enLigne;

  /// Celles qui attendent d'etre envoyees.
  final List<File> choisies;

  /// Celles que l'on retire du bien (identifiants des medias).
  final List<int> retirees;

  final void Function(List<File> fichiers) onAjouter;
  final void Function(File fichier) onEnlever;
  final void Function(Media media) onRetirerEnLigne;

  /// Vrai pendant l'enregistrement : la section se tait.
  final bool occupe;

  static const int maximum = 2;
  static const int octetsMax = 60 * 1024 * 1024;

  const VideosBien({
    super.key,
    this.enLigne = const [],
    this.choisies = const [],
    this.retirees = const [],
    required this.onAjouter,
    required this.onEnlever,
    required this.onRetirerEnLigne,
    this.occupe = false,
  });

  List<Media> get _gardees => enLigne.where((m) => !retirees.contains(m.id)).toList();

  int get _total => _gardees.length + choisies.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TitreGroupeBien('Visite en vidéo (optionnel)'),
        const SizedBox(height: 8),
        CarteAccueil(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Une vidéo montre le bien mieux que des photos : 2 au plus, '
                '60 Mo chacune (mp4 ou mov).',
                style: TextStyle(fontSize: 12.5, color: texteDouxAccueil),
              ),
              if (_total > 0) ...[
                const SizedBox(height: 12),
                for (final m in _gardees)
                  _ligne(
                    nom: _nomDe(m.url ?? 'Vidéo'),
                    detail: 'Déjà en ligne',
                    onRetirer: occupe ? null : () => onRetirerEnLigne(m),
                  ),
                for (final f in choisies)
                  _ligne(
                    nom: _nomDe(f.path),
                    detail: _poids(f.lengthSync()),
                    onRetirer: occupe ? null : () => onEnlever(f),
                  ),
              ],
              const SizedBox(height: 12),
              _tuile(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tuile(BuildContext context) {
    final plein = _total >= maximum;
    final actif = !occupe && !plein;
    return BordurePointillee(
      couleur: actif ? principaleBien : bordureAccueil,
      rayon: rayonChampBien,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(rayonChampBien),
        child: InkWell(
          borderRadius: BorderRadius.circular(rayonChampBien),
          onTap: actif ? () => _choisir(context) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(Icons.videocam_outlined,
                    size: 26, color: actif ? principaleBien : texteDouxAccueil),
                const SizedBox(height: 6),
                Text(
                  plein
                      ? 'Maximum atteint'
                      : (_total == 0 ? 'Ajouter une vidéo' : 'Ajouter une autre vidéo'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: actif ? principaleBien : texteDouxAccueil,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ligne({required String nom, required String detail, VoidCallback? onRetirer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fondPrincipaleBien,
              borderRadius: BorderRadius.circular(rayonChampBien),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: principaleBien),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: texteAccueil)),
                Text(detail,
                    style: const TextStyle(fontSize: 11.5, color: texteDouxAccueil)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: onRetirer,
            icon: const Icon(Icons.close, size: 18, color: rougeAccueil),
          ),
        ],
      ),
    );
  }

  Future<void> _choisir(BuildContext context) async {
    final choix = await FilePicker.pickFiles(
      dialogTitle: 'Visite en vidéo',
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'm4v', 'webm'],
    );
    final fichiers =
        choix.map((f) => f.path).whereType<String>().map(File.new).toList();
    if (fichiers.isEmpty || !context.mounted) return;

    final place = maximum - _total;
    final retenues = fichiers.take(place < 0 ? 0 : place).toList();
    final lourdes = retenues.where((f) => f.lengthSync() > octetsMax).toList();
    final gardees = retenues.where((f) => f.lengthSync() <= octetsMax).toList();

    if (gardees.isNotEmpty) onAjouter(gardees);
    if (!context.mounted) return;
    if (lourdes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_nomDe(lourdes.first.path)} dépasse 60 Mo : '
            'raccourcissez la vidéo avant de l\'envoyer.'),
        backgroundColor: rougeAccueil,
      ));
    } else if (fichiers.length > retenues.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('$maximum vidéos au maximum par bien.')),
      );
    }
  }

  static String _nomDe(String chemin) => chemin.split(RegExp(r'[\\/?]')).last;

  static String _poids(int octets) {
    if (octets >= 1024 * 1024) return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
    return '${(octets / 1024).round()} Ko';
  }
}
