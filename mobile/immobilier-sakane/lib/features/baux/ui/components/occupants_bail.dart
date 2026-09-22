import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/components/images_galery.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/media.dart';

/// Nombre maximum d'occupants accepte par le serveur.
const int maxOccupants = 10;

/// Une ligne « autre occupant » en cours de saisie.
class LigneOccupant {
  final TextEditingController nom;
  final TextEditingController cin;
  final TextEditingController tel;
  final TextEditingController lien;

  LigneOccupant([Colocataire? c])
      : nom = TextEditingController(text: c?.nom ?? ''),
        cin = TextEditingController(text: c?.cin ?? ''),
        tel = TextEditingController(text: c?.tel ?? ''),
        lien = TextEditingController(text: c?.lien ?? '');

  bool get vide => [nom, cin, tel, lien].every((c) => c.text.trim().isEmpty);

  /// Null tant que le nom manque : une ligne sans nom n'est pas envoyee.
  Colocataire? get valeur => nom.text.trim().isEmpty
      ? null
      : Colocataire(nom: nom.text.trim(), cin: cin.text.trim(), tel: tel.text.trim(), lien: lien.text.trim());

  void dispose() {
    for (final c in [nom, cin, tel, lien]) {
      c.dispose();
    }
  }
}

/// Les occupants saisis, sans les lignes vides.
List<Colocataire> occupantsSaisis(List<LigneOccupant> lignes) =>
    lignes.map((l) => l.valeur).whereType<Colocataire>().toList();

/// Saisie des autres occupants : ajout et retrait de lignes.
class EditeurOccupants extends StatelessWidget {
  final List<LigneOccupant> lignes;

  /// Appele apres chaque ajout ou retrait : l'ecran parent se redessine.
  final VoidCallback onChange;

  const EditeurOccupants({super.key, required this.lignes, required this.onChange});

  static const List<String> _liens = ['Épouse', 'Époux', 'Enfant', 'Parent', 'Colocataire'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < lignes.length; i++) ...[
          _ligne(context, i),
          const SizedBox(height: 10),
        ],
        if (lignes.length < maxOccupants)
          OutlinedButton.icon(
            onPressed: () {
              lignes.add(LigneOccupant());
              onChange();
            },
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(lignes.isEmpty ? 'Ajouter un occupant' : 'Ajouter un autre occupant'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CouleursBail.teinte,
              side: BorderSide(color: CouleursBail.teinte.withValues(alpha: .4)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        else
          const Text('Maximum de $maxOccupants occupants atteint.',
              style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
      ],
    );
  }

  Widget _ligne(BuildContext context, int i) {
    final l = lignes[i];
    return Container(
      key: ObjectKey(l),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 12),
      decoration: BoxDecoration(
        color: CouleursBail.fond,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CouleursBail.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Occupant ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
              ),
              IconButton(
                tooltip: 'Retirer',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final retiree = lignes.removeAt(i);
                  onChange();
                  // Les champs lachent leurs controleurs au prochain affichage.
                  WidgetsBinding.instance.addPostFrameCallback((_) => retiree.dispose());
                },
                icon: const Icon(Icons.delete_outline, color: CouleursBail.retard, size: 20),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: l.nom,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => onChange(),
                  decoration: decorationBail('Nom complet *', icone: Icons.person_outline),
                  // Une ligne entierement vide est simplement ignoree.
                  validator: (v) => (v ?? '').trim().isEmpty && !l.vide ? 'Nom requis' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: l.cin,
                        textCapitalization: TextCapitalization.characters,
                        decoration: decorationBail('N° CIN'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: l.tel,
                        keyboardType: TextInputType.phone,
                        decoration: decorationBail('Téléphone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: l.lien,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: decorationBail('Lien avec le locataire', aide: 'Ex. épouse, enfant, colocataire'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final lien in _liens)
                      ActionChip(
                        label: Text(lien, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: CouleursBail.bordure),
                        onPressed: () {
                          l.lien.text = lien;
                          onChange();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Photos prises a l'appareil ou choisies dans la galerie.
Future<List<File>> choisirPhotosBail(BuildContext context, ImageSource source) async {
  try {
    if (source == ImageSource.gallery) {
      final photos = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
      return photos.map((p) => File(p.path)).toList();
    }
    final photo = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
    return photo == null ? const [] : [File(photo.path)];
  } catch (_) {
    if (context.mounted) afficherMessage(context, "La photo n'a pas pu être ajoutée.", erreur: true);
    return const [];
  }
}

/// Rangee de photos locales, precedee des boutons Appareil et Galerie.
class SelecteurPhotosBail extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onChange;

  const SelecteurPhotosBail({super.key, required this.photos, required this.onChange});

  Future<void> _ajouter(BuildContext context, ImageSource source) async {
    final nouvelles = await choisirPhotosBail(context, source);
    if (nouvelles.isEmpty) return;
    photos.addAll(nouvelles);
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _bouton(Icons.photo_camera_outlined, 'Appareil', () => _ajouter(context, ImageSource.camera)),
          _bouton(Icons.photo_library_outlined, 'Galerie', () => _ajouter(context, ImageSource.gallery)),
          for (int i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(photos[i], width: 86, height: 86, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () {
                        photos.removeAt(i);
                        onChange();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bouton(IconData icone, String texte, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: CouleursBail.fondTeinte,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CouleursBail.teinte.withValues(alpha: .3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: CouleursBail.teinte),
              const SizedBox(height: 4),
              Text(texte, style: const TextStyle(fontSize: 12, color: CouleursBail.teinte)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatures d'images du serveur ; un appui ouvre la visionneuse plein ecran.
class MiniaturesBail extends StatelessWidget {
  final List<String> urls;
  final double taille;

  const MiniaturesBail({super.key, required this.urls, this.taille = 76});

  void _ouvrir(BuildContext context, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImagesGalery(medias: [for (final u in urls) Media(url: u)], index: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final vide = Container(
      width: taille,
      height: taille,
      color: CouleursBail.fondTeinte,
      child: const Icon(Icons.image_outlined, color: CouleursBail.teinte),
    );
    return SizedBox(
      height: taille,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => InkWell(
          onTap: () => _ouvrir(context, i),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: urls[i],
              width: taille,
              height: taille,
              fit: BoxFit.cover,
              placeholder: (_, __) => vide,
              errorWidget: (_, __, ___) => vide,
            ),
          ),
        ),
      ),
    );
  }
}
