import 'dart:convert';
import 'dart:io';

import 'package:immobilier/core/offline/operation_en_attente.dart';
import 'package:path_provider/path_provider.dart';

/// Conserve sur le telephone les operations effectuees hors connexion.
///
/// Le stockage est un simple fichier JSON dans le dossier de l'application :
/// la file reste courte et n'a pas besoin d'une base de donnees.
class FileAttente {
  static const _nomFichier = 'file_attente.json';
  static const _dossierPieces = 'pieces_jointes';

  static FileAttente? _instance;
  static FileAttente get instance => _instance ??= FileAttente._();
  FileAttente._();

  List<OperationEnAttente> _operations = [];
  Directory? _dossier;
  bool _charge = false;

  List<OperationEnAttente> get operations => List.unmodifiable(_operations);

  /// Operations qui partiront des le retour de la connexion.
  List<OperationEnAttente> get enAttente =>
      _operations.where((o) => !o.estRefusee).toList();

  /// Operations refusees par le serveur, en attente d'une decision.
  List<OperationEnAttente> get refusees =>
      _operations.where((o) => o.estRefusee).toList();

  int get nombreEnAttente => enAttente.length;

  /// Operations pretes a partir : ni refusees, ni en attente de reconnexion.
  List<OperationEnAttente> get envoyables =>
      _operations.where((o) => !o.estRefusee && !o.aReconnecter).toList();

  Future<Directory> get _racine async =>
      _dossier ??= await getApplicationDocumentsDirectory();

  Future<void> charger() async {
    if (_charge) return;
    _charge = true;
    try {
      final f = File('${(await _racine).path}/$_nomFichier');
      if (!await f.exists()) return;
      final brut = jsonDecode(await f.readAsString());
      _operations = (brut as List)
          .map((e) => OperationEnAttente.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // Une operation interrompue en plein envoi repart en attente.
      var corrige = false;
      for (final o in _operations) {
        if (o.statut == StatutOperation.envoiEnCours) {
          o.statut = StatutOperation.enAttente;
        }
        // Refusees a tort par le passe, faute d'un jeton a jour : elles
        // repartent avec la session en cours.
        final motif = (o.message ?? '').toLowerCase();
        if (o.estRefusee && (motif.contains('unauthenticated') || motif.contains('authentifi'))) {
          o.statut = StatutOperation.enAttente;
          o.message = null;
          o.jeton = null;
          corrige = true;
        }
      }
      if (corrige) await _enregistrer();
    } catch (_) {
      // Fichier illisible : on repart d'une file vide plutot que de bloquer.
      _operations = [];
    }
  }

  Future<void> _enregistrer() async {
    try {
      final f = File('${(await _racine).path}/$_nomFichier');
      await f.writeAsString(
          jsonEncode(_operations.map((o) => o.toJson()).toList()));
    } catch (_) {
      // Ecriture impossible : la file reste en memoire pour cette session.
    }
  }

  Future<void> ajouter(OperationEnAttente operation) async {
    await charger();
    _operations.add(operation);
    await _enregistrer();
  }

  Future<void> mettreAJour(OperationEnAttente operation) async {
    final i = _operations.indexWhere((o) => o.id == operation.id);
    if (i >= 0) {
      _operations[i] = operation;
      await _enregistrer();
    }
  }

  Future<void> retirer(String id) async {
    final op = _operations.where((o) => o.id == id).firstOrNull;
    _operations.removeWhere((o) => o.id == id);
    await _enregistrer();
    if (op != null) await _supprimerPieces(op);
  }

  /// Une session vient de s'ouvrir : les actions de ce compte (ou sans
  /// compte connu) reprennent le jeton courant et peuvent repartir.
  Future<void> rattacherSession(int? managerId, String jeton) async {
    await charger();
    var change = false;
    for (final o in _operations) {
      if (o.estRefusee) continue;
      final memeCompte =
          o.managerId == null || managerId == null || o.managerId == managerId;
      if (!memeCompte) continue;
      if (o.aReconnecter || (o.jeton ?? '').isEmpty) {
        o.jeton = jeton;
        o.aReconnecter = false;
        o.message = null;
        o.managerId ??= managerId;
        change = true;
      }
    }
    if (change) await _enregistrer();
  }

  /// Retrouve une piece jointe, meme si le dossier de l'application a
  /// change d'emplacement (mise a jour sur iPhone).
  Future<String?> retrouverPiece(String chemin) async {
    if (await File(chemin).exists()) return chemin;
    final repere = '/$_dossierPieces/';
    final i = chemin.replaceAll('\\', '/').indexOf(repere);
    if (i < 0) return null;
    final relatif = chemin.replaceAll('\\', '/').substring(i + 1);
    final nouveau = '${(await _racine).path}/$relatif';
    return await File(nouveau).exists() ? nouveau : null;
  }

  /// Supprime toutes les operations refusees et leurs pieces jointes.
  Future<void> viderRefusees() async {
    final refus = refusees;
    _operations.removeWhere((o) => o.estRefusee);
    await _enregistrer();
    for (final o in refus) {
      await _supprimerPieces(o);
    }
  }

  /// Copie un fichier choisi par l'utilisateur dans un dossier durable :
  /// les fichiers temporaires de l'appareil photo peuvent disparaitre
  /// avant le retour de la connexion.
  Future<String?> conserverPiece(String cheminSource, String idOperation) async {
    try {
      final source = File(cheminSource);
      if (!await source.exists()) return null;

      final dossier =
          Directory('${(await _racine).path}/$_dossierPieces/$idOperation');
      await dossier.create(recursive: true);

      final nom = cheminSource.split(Platform.pathSeparator).last.split('/').last;
      final destination = '${dossier.path}/$nom';
      await source.copy(destination);
      return destination;
    } catch (_) {
      return null;
    }
  }

  /// Conserve un contenu deja en memoire (signature manuscrite par exemple).
  Future<String?> conserverOctets(
      List<int> octets, String nomFichier, String idOperation) async {
    try {
      final dossier =
          Directory('${(await _racine).path}/$_dossierPieces/$idOperation');
      await dossier.create(recursive: true);
      final destination = '${dossier.path}/$nomFichier';
      await File(destination).writeAsBytes(octets);
      return destination;
    } catch (_) {
      return null;
    }
  }

  Future<void> _supprimerPieces(OperationEnAttente operation) async {
    try {
      final dossier =
          Directory('${(await _racine).path}/$_dossierPieces/${operation.id}');
      if (await dossier.exists()) await dossier.delete(recursive: true);
    } catch (_) {
      // Sans consequence : le dossier sera nettoye au prochain passage.
    }
  }
}

extension _PremierOuNul<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
