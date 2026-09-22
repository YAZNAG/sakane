import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:immobilier/core/services/transcription_arabe.dart';

/// Resultat de la lecture d'une carte nationale d'identite marocaine.
class CinScanResult {
  final String? cin;
  final String? firstName;
  final String? lastName;

  /// Nom et prenom en ecriture arabe, deduits du nom en lettres latines
  /// (voir [TranscriptionArabe]).
  final String? firstNameAr;
  final String? lastNameAr;

  final String rawText;

  const CinScanResult({
    this.cin,
    this.firstName,
    this.lastName,
    this.firstNameAr,
    this.lastNameAr,
    this.rawText = '',
  });

  /// Une copie enrichie des noms arabes.
  CinScanResult avecArabe(String? prenom, String? nom) => CinScanResult(
        cin: cin,
        firstName: firstName,
        lastName: lastName,
        firstNameAr: prenom,
        lastNameAr: nom,
        rawText: rawText,
      );

  /// Vrai si au moins une information exploitable a ete trouvee.
  bool get hasData =>
      (cin != null && cin!.isNotEmpty) ||
      (firstName != null && firstName!.isNotEmpty) ||
      (lastName != null && lastName!.isNotEmpty) ||
      (firstNameAr != null && firstNameAr!.isNotEmpty) ||
      (lastNameAr != null && lastNameAr!.isNotEmpty);

  /// Nombre de champs reconnus, pour informer l'agent.
  int get foundCount => [
        cin,
        firstName,
        lastName,
        firstNameAr,
        lastNameAr,
      ].where((e) => e != null && e.isNotEmpty).length;
}

/// Lecture d'une CIN marocaine par reconnaissance de texte (Google ML Kit).
///
/// Le traitement est entierement local : la photo ne quitte jamais le telephone
/// et le scan fonctionne sans connexion internet.
class CinScannerService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Mots figurant sur toutes les CIN : ils ne sont jamais un nom ou un prenom.
  static const List<String> _motsIgnores = [
    'ROYAUME', 'MAROC', 'CARTE', 'NATIONALE', 'IDENTITE', 'IDENTITÉ',
    'KINGDOM', 'MOROCCO', 'NATIONAL', 'CARD',
    'VALABLE', 'JUSQU', 'NE LE', 'NEE LE', 'NÉ LE', 'NÉE LE',
    'FILS', 'FILLE', 'SEXE', 'ADRESSE', 'DOMICILE',
    'PREFECTURE', 'PROVINCE', 'COMMUNE', 'ANNEXE', 'CERCLE',
    'DIRECTEUR', 'GENERAL', 'SURETE', 'SÛRETÉ', 'NATIONALE',
  ];

  /// Numero de CIN marocaine : une ou deux lettres suivies de 4 a 7 chiffres.
  /// Exemples : J123456, BE12345, AB1234567
  static final RegExp _regexCin = RegExp(r'\b([A-Z]{1,2})\s?(\d{4,7})\b');

  /// Dates au format 01.01.1990 ou 01/01/1990 : a exclure de la detection CIN.
  static final RegExp _regexDate =
      RegExp(r'\b\d{1,2}[./-]\d{1,2}[./-]\d{2,4}\b');

  /// Ligne susceptible de contenir un nom : lettres latines majuscules,
  /// espaces, apostrophes et traits d'union uniquement.
  static final RegExp _regexNom = RegExp(r"^[A-ZÀ-ÖØ-Þ' \-]{2,40}$");

  Future<CinScanResult> scan(File image) async {
    final recognized =
        await _recognizer.processImage(InputImage.fromFile(image));
    final lignes = recognized.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final (prenom, nom) = _chercherNoms(lignes);

    // L'arabe imprime sur la carte se lisait mal : il est deduit du nom
    // en lettres latines, bien lu, comme on l'ecrit au Maroc. La memoire
    // de l'agence affine ensuite la proposition (voir l'ecran client).
    return CinScanResult(
      cin: _chercherCin(recognized.text),
      firstName: prenom,
      lastName: nom,
      firstNameAr: TranscriptionArabe.proposer(prenom),
      lastNameAr: TranscriptionArabe.proposer(nom),
      rawText: recognized.text,
    );
  }

  /// Recherche le numero de CIN en ecartant les dates.
  String? _chercherCin(String texte) {
    final sansDates = texte.replaceAll(_regexDate, ' ');
    final majuscules = sansDates.toUpperCase();

    for (final m in _regexCin.allMatches(majuscules)) {
      final lettres = m.group(1)!;
      final chiffres = m.group(2)!;
      // Une CIN comporte au minimum 5 caracteres significatifs
      if (lettres.length + chiffres.length < 6) continue;
      return '$lettres$chiffres';
    }
    return null;
  }

  /// Recherche le prenom et le nom parmi les lignes en majuscules latines.
  ///
  /// Sur une CIN marocaine, le prenom precede le nom dans la partie latine.
  /// On retient les deux premieres lignes plausibles.
  (String?, String?) _chercherNoms(List<String> lignes) {
    final candidats = <String>[];

    for (final ligne in lignes) {
      final l = ligne.trim();
      if (l.length < 2 || l.length > 40) continue;
      if (!_regexNom.hasMatch(l)) continue;
      if (_regexCin.hasMatch(l)) continue;
      if (_regexDate.hasMatch(l)) continue;
      if (_motsIgnores.any((mot) => l.contains(mot))) continue;
      if (RegExp(r'\d').hasMatch(l)) continue;

      final propre = _capitaliser(l);
      if (!candidats.contains(propre)) candidats.add(propre);
      if (candidats.length >= 2) break;
    }

    if (candidats.isEmpty) return (null, null);
    if (candidats.length == 1) return (candidats.first, null);
    return (candidats[0], candidats[1]);
  }

  /// "EL AMRANI" -> "El Amrani"
  String _capitaliser(String valeur) {
    return valeur
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((mot) => mot.isNotEmpty)
        .map((mot) => mot[0].toUpperCase() + mot.substring(1))
        .join(' ');
  }

  void dispose() => _recognizer.close();
}
