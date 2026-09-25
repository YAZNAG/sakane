import 'dart:convert';

import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/models/compte_memorise.dart';

/// La liste des comptes deja utilises sur cet appareil.
///
/// Elle sert a ouvrir l'application sur « Bienvenue Ahmed » plutot que
/// sur un formulaire vide, et a passer d'un compte a l'autre sans
/// retaper une adresse. Elle ne contient aucun secret : le mot de passe
/// n'est jamais ecrit, et le jeton de session vit dans le coffre de
/// l'appareil (voir ServiceBiometrie), pas ici.
class ComptesMemorisesService {
  /// La liste est rangee dans les preferences sous cette cle, au format
  /// JSON : un tableau ordonne de la connexion la plus recente a la plus
  /// ancienne.
  static const String cle = 'comptes_memorises';

  /// Au-dela, la feuille de choix devient une liste a faire defiler pour
  /// rien : les comptes les plus anciens sortent d'eux-memes.
  static const int maximum = 6;

  final SharedPrefService _prefs;

  ComptesMemorisesService._(this._prefs);

  factory ComptesMemorisesService() =>
      ComptesMemorisesService._(Dependencies.get<SharedPrefService>());

  /// Les comptes, du plus recemment utilise au plus ancien.
  ///
  /// Une liste illisible (mise a jour, ecriture interrompue) est traitee
  /// comme une liste vide : l'ecran de connexion reste utilisable.
  List<CompteMemorise> lire() {
    try {
      final brut = _prefs.getValue<String>(cle, '');
      if (brut.trim().isEmpty) return const [];
      final decode = jsonDecode(brut);
      if (decode is! List) return const [];
      final comptes = <CompteMemorise>[];
      for (final element in decode) {
        if (element is Map<String, dynamic>) {
          final compte = CompteMemorise.fromJson(element);
          if (compte.identifiant.trim().isNotEmpty) comptes.add(compte);
        }
      }
      comptes.sort((a, b) => b.derniereConnexion.compareTo(a.derniereConnexion));
      return comptes;
    } catch (_) {
      return const [];
    }
  }

  /// Le compte de la derniere connexion, celui que l'ecran affiche par
  /// defaut. Nul si personne ne s'est encore connecte ici.
  CompteMemorise? dernier() {
    final comptes = lire();
    return comptes.isEmpty ? null : comptes.first;
  }

  CompteMemorise? parIdentifiant(String identifiant) {
    final recherchee = identifiant.trim().toLowerCase();
    for (final compte in lire()) {
      if (compte.cle == recherchee) return compte;
    }
    return null;
  }

  /// Ajoute le compte, ou met a jour celui qui porte le meme identifiant.
  ///
  /// La couleur de l'avatar n'est jamais recalculee pour un compte connu :
  /// la pastille de quelqu'un ne change pas de teinte apres une connexion.
  void enregistrer(CompteMemorise compte) {
    if (compte.identifiant.trim().isEmpty) return;
    final comptes = lire();
    final ancien = _trouver(comptes, compte.cle);
    final aEcrire = ancien == null
        ? compte
        : compte.copyWith(couleurAvatar: ancien.couleurAvatar);
    comptes.removeWhere((c) => c.cle == compte.cle);
    comptes.insert(0, aEcrire);
    _ecrire(comptes);
  }

  /// Retire le compte de la liste. Le jeton biometrique, lui, s'efface
  /// par ServiceBiometrie : ce sont deux rangements distincts.
  void oublier(String identifiant) {
    final recherchee = identifiant.trim().toLowerCase();
    final comptes = lire()..removeWhere((c) => c.cle == recherchee);
    _ecrire(comptes);
  }

  CompteMemorise? _trouver(List<CompteMemorise> comptes, String cleCherchee) {
    for (final compte in comptes) {
      if (compte.cle == cleCherchee) return compte;
    }
    return null;
  }

  void _ecrire(List<CompteMemorise> comptes) {
    try {
      final gardes = comptes.length > maximum
          ? comptes.sublist(0, maximum)
          : comptes;
      _prefs.putValue(
        cle,
        jsonEncode(gardes.map((c) => c.toJson()).toList()),
      );
    } catch (_) {
      // Une liste non ecrite ne doit pas empecher la connexion : au pire
      // l'ecran repart sur le formulaire complet la prochaine fois.
    }
  }
}
