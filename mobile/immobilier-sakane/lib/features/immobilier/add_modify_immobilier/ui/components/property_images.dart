import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/bloc/add_modify_imm_bloc.dart';
import 'package:immobilier/features/immobilier/add_modify_immobilier/ui/components/assistant_bien_commun.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:toastification/toastification.dart';

/// Une photo du bien : déjà sur le serveur, ou choisie sur ce téléphone.
///
/// Les deux vivent dans la même liste : c'est cette liste qui donne
/// l'ordre affiché, et sa première photo est la couverture.
class _VignetteBien {
  final Media? media;
  final File? fichier;

  const _VignetteBien.distante(Media this.media) : fichier = null;

  const _VignetteBien.locale(File this.fichier) : media = null;

  bool get estLocale => fichier != null;
}

/// Étape 5 — Photos, et le récapitulatif avant l'enregistrement.
class PropertyImages extends StatefulWidget {
  final void Function()? onFinish;
  final void Function()? onPrevious;
  final void Function()? onBrouillon;

  const PropertyImages({super.key, this.onPrevious, this.onFinish, this.onBrouillon});

  @override
  State<PropertyImages> createState() => _PropertyImagesState();
}

class _PropertyImagesState extends State<PropertyImages> {
  /// Deux photos : une façade et une pièce. En dessous, l'annonce ne dit rien.
  static const int _minimumPhotos = 2;

  List<_VignetteBien> _vignettes = [];

  /// Les photos distantes retirées : le serveur les effacera.
  List<int> _corbeille = [];

  final ImagePicker _picker = ImagePicker();
  late final AddModifyImmBloc _bloc;

  /// Vrai quand l'agent a demandé l'enregistrement sans assez de photos.
  bool _manquePhotos = false;

  @override
  void initState() {
    super.initState();
    // Le brouillon lit la saisie de l'etape affichee.
    _bloc = BlocProvider.of<AddModifyImmBloc>(context);
    _bloc.instantaneEtape = _instantane;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      remplirFields();
    });
  }

  @override
  void dispose() {
    if (_bloc.instantaneEtape == _instantane) _bloc.instantaneEtape = null;
    super.dispose();
  }

  Realestate _instantane() => updateImages();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddModifyImmBloc, AddModifyImmState>(
      builder: (context, state) {
        final isUpdate = state.realestateId != null;
        final envoi = state.addModifyStatus == AppStatus.loading;

        return Column(
          children: [
            Expanded(
              child: CorpsEtapeBien(
                enfants: [
                  const BandeauInfoBien(
                    '2 photos minimum. Maintenez une photo pour la déplacer.',
                  ),
                  const SizedBox(height: 16),
                  _grille(envoi),
                  if (_manquePhotos && _vignettes.length < _minimumPhotos)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Ajoutez au moins 2 photos pour enregistrer le bien.',
                        style: TextStyle(fontSize: 11.5, color: rougeAccueil),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _tuileSource(
                          icone: Icons.photo_camera_outlined,
                          texte: 'Appareil photo',
                          onTap: envoi ? null : _prendrePhoto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _tuileSource(
                          icone: Icons.photo_library_outlined,
                          texte: 'Galerie',
                          onTap: envoi ? null : _pickImages,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _recapitulatif(state),
                ],
              ),
            ),
            BarreActionsBien(
              libelleSuivant:
                  isUpdate ? 'Enregistrer les modifications' : 'Enregistrer le bien',
              onSuivant: onFinishClick,
              onPrecedent: onPreviousClick,
              occupe: envoi,
              onBrouillon: widget.onBrouillon,
            ),
          ],
        );
      },
    );
  }

  // ── La grille des photos ─────────────────────────────────────────

  /// Trois colonnes de vignettes carrées. Vide, elle laisse la place à un
  /// aplat clair : la page garde sa forme.
  Widget _grille(bool envoi) {
    if (_vignettes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: bordureAccueil),
          borderRadius: BorderRadius.circular(rayonAccueil),
        ),
        child: const Column(
          children: [
            Icon(Icons.photo_library_outlined, size: 34, color: texteDouxAccueil),
            SizedBox(height: 12),
            Text(
              'Aucune photo pour le moment.',
              style: TextStyle(fontSize: 13.5, color: texteDouxAccueil),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, contraintes) {
        const espace = 10.0;
        final cote = (contraintes.maxWidth - espace * 2) / 3;
        return Wrap(
          spacing: espace,
          runSpacing: espace,
          children: [
            for (var i = 0; i < _vignettes.length; i++)
              SizedBox(
                width: cote,
                height: cote,
                child: _caseVignette(i, cote, envoi),
              ),
          ],
        );
      },
    );
  }

  /// Une vignette : la photo, sa croix, son étiquette de couverture, et de
  /// quoi la déplacer. L'appui long la décolle, le lâcher la range.
  Widget _caseVignette(int index, double cote, bool envoi) {
    final vignette = _vignettes[index];
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => _deplacer(details.data, index),
      builder: (context, candidats, refuses) {
        final survol = candidats.isNotEmpty;
        final contenu = Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(rayonChampBien),
              child: _photo(vignette),
            ),
            if (envoi && vignette.estLocale)
              ClipRRect(
                borderRadius: BorderRadius.circular(rayonChampBien),
                child: Container(
                  color: const Color(0x8017262E),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            if (survol)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(rayonChampBien),
                  border: Border.all(color: principaleBien, width: 2),
                ),
              ),
            if (index == 0)
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xD917262E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Couverture',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              top: 4,
              child: Material(
                color: const Color(0xE617262E),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: envoi ? null : () => _retirer(index),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );

        if (envoi) return contenu;

        return LongPressDraggable<int>(
          data: index,
          feedback: Opacity(
            opacity: .9,
            child: SizedBox(
              width: cote,
              height: cote,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(rayonChampBien),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(rayonChampBien),
                  child: _photo(vignette),
                ),
              ),
            ),
          ),
          childWhenDragging: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEDF1F3),
              borderRadius: BorderRadius.circular(rayonChampBien),
            ),
          ),
          child: contenu,
        );
      },
    );
  }

  Widget _photo(_VignetteBien vignette) {
    final fichier = vignette.fichier;
    if (fichier != null) {
      return Image.file(fichier, fit: BoxFit.cover, cacheWidth: 360);
    }
    final adresse = vignette.media?.vignette;
    if (adresse == null) return const ColoredBox(color: Color(0xFFEDF1F3));
    return Image.network(
      adresse,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progression) {
        if (progression == null) return child;
        return ColoredBox(
          color: const Color(0xFFEDF1F3),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                value: progression.expectedTotalBytes != null
                    ? progression.cumulativeBytesLoaded / progression.expectedTotalBytes!
                    : null,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, erreur, trace) => const ColoredBox(
        color: Color(0xFFEDF1F3),
        child: Icon(Icons.broken_image_outlined, color: texteDouxAccueil),
      ),
    );
  }

  /// Une tuile en pointillés : l'appareil photo, ou la galerie.
  Widget _tuileSource({
    required IconData icone,
    required String texte,
    required VoidCallback? onTap,
  }) {
    return BordurePointillee(
      couleur: onTap == null ? bordureAccueil : principaleBien,
      rayon: rayonChampBien,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(rayonChampBien),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(rayonChampBien),
          child: Container(
            height: 86,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone,
                    size: 24, color: onTap == null ? texteDouxAccueil : principaleBien),
                const SizedBox(height: 7),
                Text(
                  texte,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: onTap == null ? texteDouxAccueil : principaleBien,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Le récapitulatif ─────────────────────────────────────────────

  /// Ce que l'agent va enregistrer, relu d'un coup d'œil. Seules les
  /// lignes renseignées apparaissent.
  Widget _recapitulatif(AddModifyImmState state) {
    final bien = state.realestate;
    final lignes = <Widget>[];

    void ligne(String libelle, String? valeur) {
      final v = (valeur ?? '').trim();
      if (v.isEmpty) return;
      lignes.add(LigneRecapBien(libelle: libelle, valeur: v));
    }

    ligne('Titre', bien?.title);
    ligne('Localisation', _localisation(bien));
    ligne('Dossier', bien?.dossier?.nom);
    ligne('Prix', bien?.price == null ? null : montantAccueil(bien!.price!.toDouble()));
    if (_vignettes.isNotEmpty) {
      ligne('Photos',
          '${_vignettes.length} ajoutée${_vignettes.length > 1 ? 's' : ''}');
    }

    if (lignes.isEmpty) return const SizedBox();

    return CarteAccueil(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récapitulatif',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: texteAccueil,
            ),
          ),
          const SizedBox(height: 4),
          ...lignes,
        ],
      ),
    );
  }

  /// « Agadir, Founty » : la ville, puis l'adresse quand elle est saisie.
  String? _localisation(Realestate? bien) {
    final morceaux = <String>[];
    final ville = bien?.address?.city?.name?.trim();
    final adresse = bien?.address?.address?.trim();
    if (ville != null && ville.isNotEmpty) morceaux.add(ville);
    if (adresse != null && adresse.isNotEmpty) morceaux.add(adresse);
    return morceaux.isEmpty ? null : morceaux.join(', ');
  }

  // ── Les photos ───────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final List<XFile> choisies = await _picker.pickMultiImage();
    if (choisies.isEmpty) return;
    setState(() {
      _vignettes = [
        ..._vignettes,
        ...choisies.map((e) => _VignetteBien.locale(File(e.path))),
      ];
      _manquePhotos = false;
    });
    updateImages();
  }

  Future<void> _prendrePhoto() async {
    final XFile? prise = await _picker.pickImage(source: ImageSource.camera);
    if (prise == null) return;
    setState(() {
      _vignettes = [..._vignettes, _VignetteBien.locale(File(prise.path))];
      _manquePhotos = false;
    });
    updateImages();
  }

  /// Retire la photo. Une photo distante part à la corbeille : le serveur
  /// l'effacera à l'enregistrement.
  void _retirer(int index) {
    if (index < 0 || index >= _vignettes.length) return;
    final vignette = _vignettes[index];
    final id = vignette.media?.id;
    setState(() {
      _vignettes = [..._vignettes]..removeAt(index);
      if (id != null) _corbeille = [..._corbeille, id];
    });
    updateImages();
  }

  /// Déplace une photo devant une autre. La première de la liste devient
  /// la couverture.
  void _deplacer(int de, int vers) {
    if (de == vers || de < 0 || de >= _vignettes.length) return;
    final liste = [..._vignettes];
    final photo = liste.removeAt(de);
    liste.insert(vers.clamp(0, liste.length), photo);
    setState(() => _vignettes = liste);
    updateImages();
  }

  /// Rend à la saisie les photos dans l'ordre affiché : les distantes
  /// gardées, les locales à envoyer, les retirées en corbeille.
  Realestate updateImages() {
    Realestate realestate = getRealEstate();
    Realestate nr = realestate.copyWith(
      media: _vignettes.where((v) => v.media != null).map((v) => v.media!).toList(),
      files: _vignettes.where((v) => v.fichier != null).map((v) => v.fichier!).toList(),
      trashImages: [..._corbeille],
    );
    updateRealestate(nr);
    return nr;
  }

  void onPreviousClick() {
    updateImages();
    widget.onPrevious?.call();
  }

  void onFinishClick() {
    if (_vignettes.length < _minimumPhotos) {
      setState(() => _manquePhotos = true);
      showToast(
        'Ajoutez au moins 2 photos.',
        second: 3,
        context,
        type: ToastificationType.warning,
      );
      return;
    }
    updateImages();
    widget.onFinish?.call();
  }

  void updateRealestate(Realestate realestate) {
    BlocProvider.of<AddModifyImmBloc>(context).add(UpdateRealestate(realestate));
  }

  Realestate getRealEstate() {
    Realestate? realestate =
        BlocProvider.of<AddModifyImmBloc>(context).state.realestate ?? Realestate();
    return realestate;
  }

  void remplirFields() {
    Realestate realestate = getRealEstate();
    setState(() {
      _vignettes = [
        ...(realestate.media ?? const <Media>[]).map(_VignetteBien.distante),
        ...(realestate.files ?? const <File>[]).map(_VignetteBien.locale),
      ];
      _corbeille = [...(realestate.trashImages ?? const <int>[])];
    });
  }
}
