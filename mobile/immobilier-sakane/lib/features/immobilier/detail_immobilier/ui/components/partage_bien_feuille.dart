import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:share_plus/share_plus.dart';

const Color _vertWhatsApp = Color(0xFF25D366);
const Color _bulleWhatsApp = Color(0xFFDCF8C6);

/// Feuille « Partager les informations de l'appartement » : l'agent coche
/// ce qu'il envoie, voit l'apercu du message, puis l'envoie.
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

class _FeuillePartageBienState extends State<FeuillePartageBien> {
  static const String _clePreferences = 'partage_bien_options';

  late OptionsPartage _options;
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
    _photos = PartageBien.photos(_bien);
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
      Dependencies.get<SharedPrefService>()
          .putValue(_clePreferences, _options.enChaine());
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
        for (var i = 0;
            i < _photos.length && i < PartageBien.maxImages;
            i++) {
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
        messenger.showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(fichiers.isEmpty
              ? "Aucune photo n'a pu être téléchargée"
                  "${texte.isEmpty ? "." : " : seul le texte sera envoyé."}"
              : "${resultat.echecs} photo${resultat.echecs > 1 ? 's' : ''} "
                  "non téléchargée${resultat.echecs > 1 ? 's' : ''} : "
                  "envoi des ${fichiers.length} autres."),
        ));
      }

      if (fichiers.isEmpty && texte.isEmpty) {
        messenger.clearSnackBars();
        setState(() {
          _progression = null;
          _alerte = "Aucune photo n'a pu être téléchargée. "
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
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const _TitreSection("Informations à inclure"),
                    ..._optionsTuiles(),
                    const SizedBox(height: 20),
                    _sectionPhotos(),
                    const SizedBox(height: 20),
                    _sectionApercu(),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _vertWhatsApp.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(FontAwesomeIcons.whatsapp,
                    color: _vertWhatsApp, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Partager les informations de l'appartement",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _bien.title ?? "Bien immobilier",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Fermer",
                onPressed: _enEnvoi ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _optionsTuiles() {
    final titre = _bien.title?.trim() ?? '';
    final adresse = PartageBien.adresseComplete(_bien);
    final description = _bien.description?.trim() ?? '';
    final caracteristiques = PartageBien.caracteristiques(_bien);

    return [
      if (_aCarte)
        _TuileOption(
          emoji: "📍",
          titre: "Localisation Google Maps",
          sousTitre: "Lien vers la position du bien",
          valeur: _options.carte,
          onChanged: (v) =>
              setState(() => _options = _options.copyWith(carte: v)),
        ),
      _TuileOption(
        emoji: "🏠",
        titre: "Nom / référence de l'appartement",
        sousTitre: [
          if (titre.isNotEmpty) titre,
          if (_bien.id != null) "Réf. #${_bien.id}",
        ].join(" · "),
        valeur: _options.nom,
        onChanged: (v) => setState(
            () => _options = _options.copyWith(nom: v, reference: v)),
      ),
      _TuileOption(
        emoji: "📌",
        titre: "Adresse complète et résidence",
        sousTitre: adresse.isEmpty
            ? "Non renseignée"
            : adresse.replaceAll("🏢 ", "").replaceAll("\n", " · "),
        valeur: _options.adresse,
        actif: adresse.isNotEmpty,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(adresse: v)),
      ),
      _TuileOption(
        emoji: "📝",
        titre: "Description",
        sousTitre: description.isEmpty ? "Non renseignée" : description,
        valeur: _options.description,
        actif: description.isNotEmpty,
        onChanged: (v) =>
            setState(() => _options = _options.copyWith(description: v)),
      ),
      _TuileOption(
        emoji: "🛏️",
        titre: "Caractéristiques",
        sousTitre: caracteristiques.isEmpty
            ? "Non renseignées"
            : caracteristiques
                .map((l) => l.replaceFirst(RegExp(r'^(• |✨ )'), ''))
                .join(" · "),
        valeur: _options.caracteristiques,
        actif: caracteristiques.isNotEmpty,
        onChanged: (v) => setState(
            () => _options = _options.copyWith(caracteristiques: v)),
      ),
    ];
  }

  Widget _sectionPhotos() {
    final total = _photos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _TitreSection("📷 Photos")),
            if (total > 0)
              TextButton(
                onPressed: _enEnvoi ? null : _basculerToutes,
                child: Text(_selection.isNotEmpty
                    ? "Aucune"
                    : "Tout sélectionner"),
              ),
          ],
        ),
        if (total == 0)
          Text("Aucune photo pour ce bien.",
              style: TextStyle(color: Colors.grey.shade600))
        else ...[
          Text(
            "${_selection.length} sélectionnée${_selection.length > 1 ? 's' : ''}"
            " sur $total · ${_auMaximum ? "maximum de ${PartageBien.maxImages} atteint" : "${PartageBien.maxImages} maximum"}",
            style: TextStyle(
              fontSize: 12.5,
              color: _auMaximum ? Colors.orange.shade800 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: total,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (_, i) => _TuilePhoto(
              url: _photos[i],
              rang: _selection.indexOf(i) + 1,
              onTap: _enEnvoi ? null : () => _basculerPhoto(i),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionApercu() {
    final texte = _texte;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _TitreSection("Aperçu du message")),
            if (texte.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: texte));
                  if (!mounted) return;
                  setState(() => _copie = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _copie = false);
                  });
                },
                icon: Icon(_copie ? Icons.check : Icons.copy_rounded,
                    size: 18),
                label: Text(_copie ? "Copié" : "Copier"),
              ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECE5DD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: texte.isEmpty ? Colors.white : _bulleWhatsApp,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: texte.isEmpty
                  ? Text(
                      _selection.isEmpty
                          ? "Cochez au moins une information ou une photo."
                          : "Seules les photos seront envoyées.",
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  : Text.rich(
                      _TexteWhatsApp.formater(texte),
                      style: const TextStyle(
                          fontSize: 14, height: 1.35, color: Colors.black87),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barreEnvoi() {
    final aPhotos = _selection.isNotEmpty;
    final possible = !_enEnvoi && (aPhotos || _texte.isNotEmpty);
    final progression = _progression;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_alerte != null) ...[
            Text(
              _alerte!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
            const SizedBox(height: 8),
          ],
          if (progression != null) ...[
            Text(
              "Téléchargement des photos… ${progression.$1}/${progression.$2}",
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progression.$2 == 0
                    ? null
                    : progression.$1 / progression.$2,
                color: _vertWhatsApp,
                backgroundColor: _vertWhatsApp.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 10),
          ] else if (aPhotos && _texte.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppColors.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Le texte part avec les photos, en légende de la première "
                      "(choisissez WhatsApp puis le contact). Il est aussi copié : "
                      "collez-le si la messagerie ne l'affiche pas.",
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _vertWhatsApp,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed:
                  possible ? () => _envoyer(viaWhatsApp: true) : null,
              icon: _enEnvoi
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
              label: const Text("Envoyer sur WhatsApp",
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed:
                  possible ? () => _envoyer(viaWhatsApp: false) : null,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text("Autres applications"),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String texte;

  const _TitreSection(this.texte);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texte,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TuileOption extends StatelessWidget {
  final String emoji;
  final String titre;
  final String sousTitre;
  final bool valeur;
  final bool actif;
  final ValueChanged<bool> onChanged;

  const _TuileOption({
    required this.emoji,
    required this.titre,
    required this.sousTitre,
    required this.valeur,
    required this.onChanged,
    this.actif = true,
  });

  @override
  Widget build(BuildContext context) {
    final coche = actif && valeur;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: coche
            ? AppColors.primaryColor.withValues(alpha: 0.06)
            : Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: coche
                ? AppColors.primaryColor.withValues(alpha: 0.5)
                : Colors.grey.shade200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: actif ? () => onChanged(!valeur) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Opacity(
              opacity: actif ? 1 : 0.5,
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        if (sousTitre.isNotEmpty)
                          Text(
                            sousTitre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: coche,
                    activeColor: AppColors.primaryColor,
                    onChanged: actif ? (v) => onChanged(v ?? false) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TuilePhoto extends StatelessWidget {
  final String url;

  /// Position dans l'envoi, 0 si la photo n'est pas choisie.
  final int rang;
  final VoidCallback? onTap;

  const _TuilePhoto({required this.url, required this.rang, this.onTap});

  @override
  Widget build(BuildContext context) {
    final choisie = rang > 0;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: choisie ? _vertWhatsApp : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey.shade200),
                errorWidget: (_, _, _) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.grey),
                ),
              ),
              if (!choisie)
                Container(color: Colors.white.withValues(alpha: 0.35)),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: choisie
                        ? _vertWhatsApp
                        : Colors.black.withValues(alpha: 0.25),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: choisie
                      ? Text("$rang",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))
                      : null,
                ),
              ),
            ],
          ),
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
      morceaux.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      debut = m.end;
    }
    if (debut < texte.length) {
      morceaux.add(TextSpan(text: texte.substring(debut)));
    }
    return TextSpan(children: morceaux);
  }
}
