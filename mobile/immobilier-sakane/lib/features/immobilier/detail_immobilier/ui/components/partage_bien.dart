import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/features/immobilier/detail_immobilier/ui/components/partage_bien_feuille.dart';
import 'package:immobilier/models/media.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Rubriques que l'agent choisit d'envoyer.
///
/// Le prix et les coordonnees du proprietaire n'en font jamais partie :
/// le prix se negocie de vive voix, le proprietaire est un tiers.
class OptionsPartage {
  /// Lien Google Maps vers la position du bien.
  final bool carte;

  /// Titre du bien.
  final bool nom;

  /// Numero de reference du bien, sous le titre.
  final bool reference;

  /// Ligne courte « Ville - Secteur », quand l'adresse complete n'est pas envoyee.
  final bool ville;

  /// Adresse complete, ville, secteur et residence.
  final bool adresse;

  final bool description;

  /// Type, chambres, salles de bain, surface, etage et equipements.
  final bool caracteristiques;

  const OptionsPartage({
    this.carte = true,
    this.nom = true,
    this.reference = false,
    this.ville = true,
    this.adresse = false,
    this.description = true,
    this.caracteristiques = false,
  });

  /// Choix proposes a la premiere ouverture de la feuille de partage.
  static const OptionsPartage feuille = OptionsPartage(
    reference: true,
    ville: false,
    adresse: true,
    caracteristiques: true,
  );

  OptionsPartage copyWith({
    bool? carte,
    bool? nom,
    bool? reference,
    bool? ville,
    bool? adresse,
    bool? description,
    bool? caracteristiques,
  }) {
    return OptionsPartage(
      carte: carte ?? this.carte,
      nom: nom ?? this.nom,
      reference: reference ?? this.reference,
      ville: ville ?? this.ville,
      adresse: adresse ?? this.adresse,
      description: description ?? this.description,
      caracteristiques: caracteristiques ?? this.caracteristiques,
    );
  }

  /// Forme courte pour les preferences : « carte,nom,adresse ».
  String enChaine() => [
    if (carte) 'carte',
    if (nom) 'nom',
    if (reference) 'reference',
    if (ville) 'ville',
    if (adresse) 'adresse',
    if (description) 'description',
    if (caracteristiques) 'caracteristiques',
  ].join(',');

  factory OptionsPartage.depuisChaine(String valeur) {
    final cles = valeur.split(',').toSet();
    return OptionsPartage(
      carte: cles.contains('carte'),
      nom: cles.contains('nom'),
      reference: cles.contains('reference'),
      ville: cles.contains('ville'),
      adresse: cles.contains('adresse'),
      description: cles.contains('description'),
      caracteristiques: cles.contains('caracteristiques'),
    );
  }
}

/// Resultat du rapatriement des photos : celles qui ont pu etre
/// telechargees, dans l'ordre demande, et le nombre d'echecs.
class PhotosTelechargees {
  final List<XFile> fichiers;
  final int echecs;

  const PhotosTelechargees(this.fichiers, this.echecs);
}

/// Partage les informations d'un bien, par WhatsApp ou une autre
/// application. L'agent choisit d'abord ce qu'il envoie.
class PartageBien {
  /// Au-dela, l'envoi devient trop lourd pour WhatsApp et la plupart
  /// des messageries refusent la piece jointe.
  static const int maxImages = 30;

  /// Ouvre la feuille « Partager les informations de l'appartement ».
  static Future<void> partager(BuildContext context, Realestate bien) {
    return FeuillePartageBien.ouvrir(context, bien);
  }

  /// Les photos du bien qui ont une adresse lisible.
  static List<Media> medias(Realestate bien) => (bien.media ?? const <Media>[])
      .where((m) => (m.pleineTaille ?? '').isNotEmpty)
      .toList();

  /// URL non vides des photos du bien, dans l'ordre de [medias].
  static List<String> photos(Realestate bien) =>
      medias(bien).map((m) => m.pleineTaille!).toList();

  // ---------------------------------------------------------------------
  // Envoi
  // ---------------------------------------------------------------------

  /// Envoie le texte et les photos choisis.
  ///
  /// Avec des photos, le texte part dans le meme envoi : WhatsApp le met en
  /// legende de la premiere photo. Il est aussi copie, pour le coller si
  /// une messagerie l'ignore.
  static Future<void> envoyer({
    required Realestate bien,
    required String texte,
    required List<XFile> photos,
    required bool viaWhatsApp,
  }) async {
    final sujet = bien.title ?? "Bien immobilier";
    Future<void> envoyerTexte() => viaWhatsApp
        ? _ouvrirWhatsApp(texte, sujet)
        : _partagerTexte(texte, sujet);

    if (photos.isEmpty) {
      if (texte.isNotEmpty) await envoyerTexte();
      return;
    }

    if (texte.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: texte));
    }
    await SharePlus.instance.share(
      ShareParams(
        files: photos,
        text: texte.isEmpty ? null : texte,
        subject: sujet,
      ),
    );
  }

  static Future<void> _partagerTexte(String texte, String sujet) async {
    await SharePlus.instance.share(ShareParams(text: texte, subject: sujet));
  }

  /// Ouvre WhatsApp avec le texte pret, sans destinataire : l'agent choisit
  /// le contact. Sans WhatsApp installe, la feuille de partage prend le relais.
  static Future<void> _ouvrirWhatsApp(String texte, String sujet) async {
    final uri = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(texte)}");
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // WhatsApp absent : on passe a la feuille de partage.
    }
    await _partagerTexte(texte, sujet);
  }

  /// Rapatrie les photos dans un dossier temporaire : les messageries
  /// attendent des fichiers locaux, pas des URL. Une photo en echec est
  /// ignoree sans bloquer les autres.
  static Future<PhotosTelechargees> telechargerPhotos(
    List<String> urls, {
    void Function(int faits, int total)? progression,
  }) async {
    final dossier = Directory(
      "${(await getTemporaryDirectory()).path}/partage",
    );
    if (dossier.existsSync()) dossier.deleteSync(recursive: true);
    dossier.createSync(recursive: true);

    final dio = Dio(
      BaseOptions(
        responseType: ResponseType.bytes,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    var faits = 0;
    progression?.call(0, urls.length);

    final resultats = await Future.wait(
      urls.asMap().entries.map((e) async {
        try {
          final reponse = await dio.get<List<int>>(e.value);
          final octets = reponse.data;
          if (octets == null || octets.isEmpty) return null;

          final chemin =
              "${dossier.path}/photo_${e.key + 1}${_extension(e.value)}";
          await File(chemin).writeAsBytes(octets);
          return XFile(chemin);
        } catch (_) {
          return null;
        } finally {
          faits++;
          progression?.call(faits, urls.length);
        }
      }),
    );

    final fichiers = resultats.whereType<XFile>().toList();
    return PhotosTelechargees(fichiers, urls.length - fichiers.length);
  }

  static String _extension(String url) {
    final chemin = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp']) {
      if (chemin.endsWith(ext)) return ext;
    }
    return '.jpg';
  }

  // ---------------------------------------------------------------------
  // Texte
  // ---------------------------------------------------------------------

  /// Longueur maximale d'une legende sur WhatsApp. La description, seule
  /// partie de longueur libre, est raccourcie pour tenir.
  static const int _limiteLegende = 1024;

  static const String _enteteDescription = "📝 *Description*\n";

  /// Le texte du message, limite aux rubriques choisies. Public : il se
  /// teste seul et sert d'apercu dans la feuille.
  static String construireTexte(
    Realestate bien, {
    OptionsPartage options = const OptionsPartage(),
  }) {
    final description = options.description
        ? (bien.description?.trim() ?? '')
        : '';
    final complet = _assembler(bien, options, description);
    if (complet.length <= _limiteLegende) return complet;

    // Place restante pour la description, entete, separateur et points
    // de suspension compris.
    final sansDescription = _assembler(bien, options, '');
    final place =
        _limiteLegende - sansDescription.length - _enteteDescription.length - 3;

    return _assembler(
      bien,
      options,
      place < 40 ? '' : _couper(description, place),
    );
  }

  static String _assembler(
    Realestate bien,
    OptionsPartage o,
    String description,
  ) {
    final sections = <String>[];

    if (o.nom) {
      final lignes = ["*${_texteOu(bien.title, "Bien immobilier")}*"];
      final ref = reference(bien);
      if (o.reference && ref.isNotEmpty) lignes.add("🔖 Réf. : $ref");
      sections.add(lignes.join("\n"));
    }

    if (o.adresse) {
      final bloc = adresseComplete(bien);
      if (bloc.isNotEmpty) sections.add("📌 *Adresse*\n$bloc");
    } else if (o.ville) {
      final lieu = localisation(bien);
      if (lieu.isNotEmpty) sections.add("🏙️ $lieu");
    }

    if (o.caracteristiques) {
      final lignes = caracteristiques(bien);
      if (lignes.isNotEmpty) {
        sections.add("🛏️ *Caractéristiques*\n${lignes.join("\n")}");
      }
    }

    if (description.isNotEmpty) {
      sections.add("$_enteteDescription$description");
    }

    if (o.carte) {
      final lien = carte(bien);
      if (lien.isNotEmpty) sections.add("📍 *Localisation*\n$lien");
    }

    return sections.join("\n\n");
  }

  /// Coupe sur un mot entier quand la place manque.
  static String _couper(String texte, int place) {
    if (texte.length <= place) return texte;
    final coupe = texte.substring(0, place);
    final dernierEspace = coupe.lastIndexOf(' ');
    return "${(dernierEspace > 40 ? coupe.substring(0, dernierEspace) : coupe).trimRight()}…";
  }

  static String _texteOu(String? valeur, String defaut) {
    final v = valeur?.trim() ?? '';
    return v.isEmpty ? defaut : v;
  }

  /// « AG-0001 », ou « #42 » quand le serveur ne donne pas la reference.
  static String reference(Realestate bien) {
    final ref = bien.reference?.trim() ?? '';
    if (ref.isNotEmpty) return ref;
    return bien.id == null ? '' : '#${bien.id}';
  }

  /// « Agadir - HAY FOUNTY ».
  static String localisation(Realestate bien) {
    final morceaux = <String>[
      if (bien.address?.city?.name?.trim().isNotEmpty == true)
        bien.address!.city!.name!.trim(),
      if (bien.secteur?.name?.trim().isNotEmpty == true)
        bien.secteur!.name!.trim(),
    ];
    return morceaux.join(" - ");
  }

  /// Rue, ville et secteur, puis la residence (nom du dossier).
  static String adresseComplete(Realestate bien) {
    final rue = bien.address?.address?.trim() ?? '';
    final lieu = localisation(bien);
    final residence = bien.dossier?.nom?.trim() ?? '';
    return [
      if (rue.isNotEmpty) rue,
      if (lieu.isNotEmpty) lieu,
      if (residence.isNotEmpty)
        residence.toLowerCase().startsWith("résidence") ||
                residence.toLowerCase().startsWith("residence")
            ? "🏢 $residence"
            : "🏢 Résidence : $residence",
    ].join("\n");
  }

  /// Une ligne par caracteristique renseignee.
  static List<String> caracteristiques(Realestate bien) {
    final lignes = <String>[];

    final type = bien.category?.name?.trim() ?? '';
    if (type.isNotEmpty) lignes.add("• Type : $type");

    final chambres = bien.nbRooms ?? 0;
    if (chambres > 0) {
      lignes.add("• $chambres chambre${chambres > 1 ? 's' : ''}");
    }

    final sdb = bien.nbBathroom ?? 0;
    if (sdb > 0) {
      lignes.add("• $sdb salle${sdb > 1 ? 's' : ''} de bain");
    }

    final surface = bien.surface;
    if (surface != null && surface > 0) {
      final valeur = surface == surface.roundToDouble()
          ? surface.round().toString()
          : surface.toString().replaceAll('.', ',');
      lignes.add("• Surface : $valeur m²");
    }

    final etage = bien.etage;
    if (etage != null) {
      final total = bien.nbEtages ?? 0;
      final niveau = etage == 0 ? "Rez-de-chaussée" : "$etage";
      lignes.add("• Étage : $niveau${total > 0 ? " / $total" : ""}");
    }

    final equipements = (bien.features ?? [])
        .map((f) => f.name?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (equipements.isNotEmpty) {
      lignes.add("✨ Équipements : ${equipements.join(", ")}");
    }

    return lignes;
  }

  /// Lien vers la position sur la carte, ouvrable depuis la messagerie.
  ///
  /// Sans coordonnees, on ne fabrique pas de lien a partir du nom de la
  /// ville : il designerait un centre-ville, pas le bien.
  static String carte(Realestate bien) {
    final lat = bien.location?.latitude;
    final lng = bien.location?.longitude;
    if (lat == null || lng == null) return '';
    if (lat == 0 && lng == 0) return '';

    return "https://maps.google.com/?q=$lat,$lng";
  }
}
