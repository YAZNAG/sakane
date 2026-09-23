import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/detail_bien_commun.dart'
    show CercleFlottant;
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/features/immobilier/home_immobilier/ui/components/fiche_bien_commun.dart'
    show SurTitre;
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:share_plus/share_plus.dart';

/// Feuille « Partager la fiche » : l'agent coche ce qu'il envoie, choisit
/// ses photos, lit l'aperçu du message, puis l'envoie.
///
/// Le prix et le contact du propriétaire n'en font jamais partie : le prix
/// se négocie de vive voix, le propriétaire est un tiers. La feuille le
/// dit, pour qu'on ne le cherche pas.
class FeuillePartageBien extends StatefulWidget {
  final Realestate bien;

  const FeuillePartageBien({super.key, required this.bien});

  static Future<void> ouvrir(BuildContext context, Realestate bien) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeuillePartageBien(bien: bien),
    );
  }

  @override
  State<FeuillePartageBien> createState() => _FeuillePartageBienState();
}

/// Le vert de la pastille « choisie » d'une vignette.
const Color _vertCoche = vertAccueil;

class _FeuillePartageBienState extends State<FeuillePartageBien> {
  static const String _clePreferences = 'partage_bien_options';

  late OptionsPartage _options;
  late final List<Media> _medias;
  late final List<String> _photos;

  /// Indices des photos choisies, dans l'ordre d'envoi.
  final List<int> _selection = [];

  /// Avancement du telechargement ; null hors envoi.
  (int, int)? _progression;

  /// Message affiche dans la feuille : un SnackBar resterait cache dessous.
  String? _alerte;
  bool _copie = false;

  Realestate get _bien => widget.bien;
  bool get _aCarte => PartageBien.carte(_bien).isNotEmpty;
  bool get _enEnvoi => _progression != null;
  bool get _auMaximum => _selection.length >= PartageBien.maxImages;

  @override
  void initState() {
    super.initState();
    _options = _lireOptions();
    _medias = PartageBien.medias(_bien);
    _photos = _medias.map((m) => m.pleineTaille!).toList();
    // Toutes les photos sont proposees, dans la limite du maximum.
    for (var i = 0; i < _photos.length && i < PartageBien.maxImages; i++) {
      _selection.add(i);
    }
  }

  OptionsPartage _lireOptions() {
    try {
      final prefs = Dependencies.get<SharedPrefService>();
      final valeur = prefs.getValue<String>(_clePreferences, '');
      if (valeur.isNotEmpty) {
        // La ligne courte n'a pas sa place dans la feuille : l'adresse la couvre.
        return OptionsPartage.depuisChaine(valeur).copyWith(ville: false);
      }
    } catch (_) {
      // Preferences indisponibles : choix par defaut.
    }
    return OptionsPartage.feuille;
  }

  void _sauverOptions() {
    try {
      Dependencies.get<SharedPrefService>().putValue(
        _clePreferences,
        _options.enChaine(),
      );
    } catch (_) {
      // Sans consequence : les choix par defaut reviendront.
    }
  }

  String get _texte => PartageBien.construireTexte(
    _bien,
    options: _aCarte ? _options : _options.copyWith(carte: false),
  );

  void _basculerPhoto(int index) {
    setState(() {
      if (_selection.contains(index)) {
        _selection.remove(index);
      } else if (_selection.length < PartageBien.maxImages) {
        _selection.add(index);
      }
    });
  }

  void _basculerToutes() {
    setState(() {
      if (_selection.isNotEmpty) {
        _selection.clear();
      } else {
        for (var i = 0; i < _photos.length && i < PartageBien.maxImages; i++) {
          _selection.add(i);
        }
      }
    });
  }

  Future<void> _envoyer({required bool viaWhatsApp}) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final texte = _texte;
    _sauverOptions();
    setState(() => _alerte = null);

    List<XFile> fichiers = const [];
    if (_selection.isNotEmpty) {
      final urls = _selection.map((i) => _photos[i]).toList();
      setState(() => _progression = (0, urls.length));

      final resultat = await PartageBien.telechargerPhotos(
        urls,
        progression: (faits, total) {
          if (mounted) setState(() => _progression = (faits, total));
        },
      );
      // Feuille fermee pendant le telechargement : l'envoi est abandonne.
      if (!mounted) return;

      fichiers = resultat.fichiers;
      if (resultat.echecs > 0) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(
              fichiers.isEmpty
                  ? "Aucune photo n'a pu être téléchargée"
                        "${texte.isEmpty ? "." : " : seul le texte sera envoyé."}"
                  : "${resultat.echecs} photo${resultat.echecs > 1 ? 's' : ''} "
                        "non téléchargée${resultat.echecs > 1 ? 's' : ''} : "
                        "envoi des ${fichiers.length} autres.",
            ),
          ),
        );
      }

      if (fichiers.isEmpty && texte.isEmpty) {
        messenger.clearSnackBars();
        setState(() {
          _progression = null;
          _alerte =
              "Aucune photo n'a pu être téléchargée. "
              "Vérifiez la connexion et réessayez.";
        });
        return;
      }
    }

    navigator.pop();
    await PartageBien.envoyer(
      bien: _bien,
      texte: texte,
      photos: fichiers,
      viaWhatsApp: viaWhatsApp,
    );
  }

  // ── La feuille ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_enEnvoi,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _entete(),
              const Divider(height: 1, color: bordureAccueil),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  children: [
                    const SurTitre('Informations à inclure'),
                    const SizedBox(height: 8),
                    ..._cases(),
                    const SizedBox(height: 12),
                    const _NoteConfidentielle(),
                    const SizedBox(height: 20),
                    ..._sectionPhotos(),
                    const SizedBox(height: 20),
                    ..._sectionApercu(),
                  ],
                ),
              ),
              _barreEnvoi(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: bordureAccueil,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partager la fiche',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: texteAccueil,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (_bien.title ?? '').trim().isEmpty
                          ? 'Bien immobilier'
                          : _bien.title!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: texteDouxAccueil,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _enEnvoi ? null : () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: const CercleFlottant(
                  taille: 36,
                  enfant: Icon(Icons.close, size: 18, color: texteAccueil),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Informations à inclure ──────────────────────────────────────

  /// Quatre cases, pas sept : « Nom et adresse » commande à la fois le
  /// titre, la référence et l'adresse — trois lignes qui vont ensemble.
  List<Widget> _cases() {
    final titre = (_bien.title ?? '').trim();
    final adresse = PartageBien.adresseComplete(_bien);
    final description = _bien.description?.trim() ?? '';
    final caracteristiques = PartageBien.caracteristiques(_bien);

    return [
      _CaseAcocher(
        libelle: 'Nom et adresse',
        valeur: _options.nom,
        actif: titre.isNotEmpty || adresse.isNotEmpty,
        onChanged: (v) => setState(
          () => _options = _options.copyWith(
            nom: v,
            reference: v,
            adresse: v && adresse.isNotEmpty,
          ),
        ),
      ),
      _CaseAcocher(
        libelle: 'Description',
        valeur: _options.description,
        actif: description.isNotEmpty,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(description: v)),
      ),
      _CaseAcocher(
        libelle: 'Caractéristiques (surface, chambres…)',
        valeur: _options.caracteristiques,
        actif: caracteristiques.isNotEmpty,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(caracteristiques: v)),
      ),
      _CaseAcocher(
        libelle: 'Lien Google Maps',
        valeur: _options.carte,
        actif: _aCarte,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(carte: v)),
      ),
    ];
  }

  // ── Photos ──────────────────────────────────────────────────────

  List<Widget> _sectionPhotos() {
    final total = _photos.length;
    if (total == 0) {
      return const [
        SurTitre('Photos'),
        SizedBox(height: 8),
        Text(
          'Aucune photo pour ce bien.',
          style: TextStyle(fontSize: 13, color: texteDouxAccueil),
        ),
      ];
    }

    return [
      Row(
        children: [
          Expanded(child: SurTitre('Photos · ${_selection.length} sur $total')),
          TextButton(
            onPressed: _enEnvoi ? null : _basculerToutes,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              _selection.isNotEmpty ? 'Aucune' : 'Toutes',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      if (_auMaximum) ...[
        const SizedBox(height: 2),
        Text(
          'Maximum de ${PartageBien.maxImages} photos atteint.',
          style: const TextStyle(fontSize: 11.5, color: orangeAccueil),
        ),
      ],
      const SizedBox(height: 10),
      SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: total,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _Vignette(
            url: _medias[i].vignette ?? _photos[i],
            choisie: _selection.contains(i),
            onTap: _enEnvoi ? null : () => _basculerPhoto(i),
          ),
        ),
      ),
    ];
  }

  // ── Aperçu ──────────────────────────────────────────────────────

  List<Widget> _sectionApercu() {
    final texte = _texte;
    return [
      Row(
        children: [
          const Expanded(child: SurTitre('Aperçu du message')),
          if (texte.isNotEmpty)
            TextButton.icon(
              onPressed: _copier,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(_copie ? Icons.check : Icons.copy_rounded, size: 15),
              label: Text(
                _copie ? 'Copié' : 'Copier',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F6),
          border: Border.all(color: bordureAccueil),
          borderRadius: BorderRadius.circular(rayonAccueil),
        ),
        child: texte.isEmpty
            ? Text(
                _selection.isEmpty
                    ? 'Cochez au moins une information ou une photo.'
                    : 'Seules les photos seront envoyées.',
                style: const TextStyle(fontSize: 13, color: texteDouxAccueil),
              )
            : Text.rich(
                _TexteWhatsApp.formater(texte),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: texteAccueil,
                ),
              ),
      ),
    ];
  }

  Future<void> _copier() async {
    await Clipboard.setData(ClipboardData(text: _texte));
    if (!mounted) return;
    setState(() => _copie = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copie = false);
    });
  }

  // ── Envoi ───────────────────────────────────────────────────────

  Widget _barreEnvoi() {
    final aPhotos = _selection.isNotEmpty;
    final possible = !_enEnvoi && (aPhotos || _texte.isNotEmpty);
    final progression = _progression;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: bordureAccueil)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_alerte != null) ...[
            Text(
              _alerte!,
              style: const TextStyle(fontSize: 12.5, color: rougeAccueil),
            ),
            const SizedBox(height: 8),
          ],
          if (progression != null) ...[
            Text(
              'Téléchargement des photos… ${progression.$1}/${progression.$2}',
              style: const TextStyle(
                fontSize: 12.5,
                color: texteDouxAccueil,
                fontFeatures: chiffresTabulaires,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progression.$2 == 0
                    ? null
                    : progression.$1 / progression.$2,
                color: AppColors.primaryColor,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: possible
                        ? () => _envoyer(viaWhatsApp: false)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: texteAccueil,
                      side: const BorderSide(color: bordureAccueil),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text(
                      'Autres apps',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: possible
                        ? () => _envoyer(viaWhatsApp: true)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _enEnvoi
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une case à cocher carrée et son libellé, sur toute la largeur.
class _CaseAcocher extends StatelessWidget {
  final String libelle;
  final bool valeur;
  final bool actif;
  final ValueChanged<bool> onChanged;

  const _CaseAcocher({
    required this.libelle,
    required this.valeur,
    required this.onChanged,
    this.actif = true,
  });

  @override
  Widget build(BuildContext context) {
    final coche = actif && valeur;
    return InkWell(
      onTap: actif ? () => onChanged(!valeur) : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: actif ? 1 : .45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: coche,
                  activeColor: AppColors.primaryColor,
                  side: const BorderSide(color: Color(0xFFC3CDD3), width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: actif ? (v) => onChanged(v ?? false) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  libelle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: texteAccueil,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La règle, écrite une fois pour toutes : le prix et le propriétaire
/// restent à l'agence.
class _NoteConfidentielle extends StatelessWidget {
  const _NoteConfidentielle();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, size: 17, color: texteDouxAccueil),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Le prix et le contact du propriétaire ne sont jamais partagés.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: texteDouxAccueil,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une vignette carrée de la rangée des photos.
class _Vignette extends StatelessWidget {
  final String url;
  final bool choisie;
  final VoidCallback? onTap;

  const _Vignette({required this.url, required this.choisie, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: choisie ? AppColors.primaryColor : bordureAccueil,
                  width: choisie ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFFE7ECEF)),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE7ECEF),
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: Color(0xFFA9B6BD),
                        ),
                      ),
                    ),
                    if (!choisie)
                      ColoredBox(color: Colors.white.withValues(alpha: .4)),
                  ],
                ),
              ),
            ),
            if (choisie)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _vertCoche,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rendu du gras WhatsApp (*texte*) dans l'apercu.
class _TexteWhatsApp {
  static final RegExp _gras = RegExp(r'\*([^*\n]+)\*');

  static TextSpan formater(String texte) {
    final morceaux = <InlineSpan>[];
    var debut = 0;
    for (final m in _gras.allMatches(texte)) {
      if (m.start > debut) {
        morceaux.add(TextSpan(text: texte.substring(debut, m.start)));
      }
      morceaux.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      debut = m.end;
    }
    if (debut < texte.length) {
      morceaux.add(TextSpan(text: texte.substring(debut)));
    }
    return TextSpan(children: morceaux);
  }
}
