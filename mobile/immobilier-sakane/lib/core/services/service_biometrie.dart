import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart'
    show AndroidAuthMessages;
import 'package:local_auth_darwin/local_auth_darwin.dart' show IOSAuthMessages;

import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';

/// Ce que l'appareil sait reconnaitre. « generique » couvre les appareils
/// qui annoncent une biometrie sans dire laquelle : le bouton doit rester
/// utilisable, avec un libelle neutre.
enum TypeBiometrie { aucune, visage, empreinte, generique }

/// Le deverrouillage rapide : l'empreinte ou le visage a la place du mot
/// de passe.
///
/// Le mot de passe n'est jamais garde, nulle part. Ce qui est range dans
/// le coffre de l'appareil, c'est le jeton de session rendu par le
/// serveur a la derniere connexion reussie, sous une cle propre au
/// compte. Un jeton refuse par le serveur est efface : la personne
/// retombe alors sur le mot de passe, et rien n'est bloque.
///
/// Toutes les methodes avalent leurs erreurs. Un appareil sans capteur,
/// un coffre illisible apres une restauration, un refus de l'utilisateur :
/// aucun de ces cas ne doit empecher d'entrer avec son mot de passe.
class ServiceBiometrie {
  ServiceBiometrie._();

  static final ServiceBiometrie instance = ServiceBiometrie._();

  final LocalAuthentication _local = LocalAuthentication();

  /// Le coffre de l'appareil : Keystore sur Android, Keychain sur iOS.
  static const FlutterSecureStorage _coffre = FlutterSecureStorage();

  static const String _prefixeJeton = 'jeton_biometrie_';
  static const String _prefixeProposition = 'biometrie_proposee_';

  /// Vrai si l'appareil sait reconnaitre son porteur, et si au moins une
  /// empreinte ou un visage y est enregistre. Sans cela le bouton ne doit
  /// pas apparaitre : il ouvrirait une fenetre qui echoue toujours.
  Future<TypeBiometrie> typeDisponible() async {
    try {
      if (!await _local.isDeviceSupported()) return TypeBiometrie.aucune;
      if (!await _local.canCheckBiometrics) return TypeBiometrie.aucune;
      final disponibles = await _local.getAvailableBiometrics();
      if (disponibles.isEmpty) return TypeBiometrie.aucune;
      if (disponibles.contains(BiometricType.face)) return TypeBiometrie.visage;
      if (disponibles.contains(BiometricType.fingerprint)) {
        return TypeBiometrie.empreinte;
      }
      // « strong » designe un capteur fiable sans dire lequel : sur les
      // appareils Android recents c'est le lecteur d'empreinte.
      if (disponibles.contains(BiometricType.strong)) {
        return TypeBiometrie.empreinte;
      }
      return TypeBiometrie.generique;
    } catch (_) {
      return TypeBiometrie.aucune;
    }
  }

  /// Vrai si un jeton attend dans le coffre pour ce compte.
  Future<bool> jetonMemorise(String identifiant) async {
    try {
      final jeton = await _coffre.read(key: _cleJeton(identifiant));
      return (jeton ?? '').trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Range le jeton de session de ce compte. Jamais le mot de passe.
  Future<bool> memoriserJeton(String identifiant, String jeton) async {
    if (identifiant.trim().isEmpty || jeton.trim().isEmpty) return false;
    try {
      await _coffre.write(key: _cleJeton(identifiant), value: jeton);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> lireJeton(String identifiant) async {
    try {
      return await _coffre.read(key: _cleJeton(identifiant));
    } catch (_) {
      return null;
    }
  }

  /// Efface le jeton de ce compte : deconnexion, compte oublie, ou jeton
  /// refuse par le serveur. Le compte reste dans la liste des comptes
  /// memorises, seul le raccourci disparait.
  Future<void> oublierJeton(String identifiant) async {
    try {
      await _coffre.delete(key: _cleJeton(identifiant));
    } catch (_) {
      // Rien a faire : le jeton sera de toute facon refuse au prochain essai.
    }
    _oublierProposition(identifiant);
  }

  /// Demande l'empreinte ou le visage. Faux si l'utilisateur refuse,
  /// annule, ou si l'appareil ne peut pas repondre.
  Future<bool> controler(String raison) async {
    try {
      return await _local.authenticate(
        localizedReason: raison,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Connexion',
            biometricHint: '',
            biometricNotRecognized: 'Non reconnu, réessayez',
            biometricRequiredTitle: 'Biométrie non configurée',
            cancelButton: 'Utiliser le mot de passe',
            goToSettingsButton: 'Réglages',
            goToSettingsDescription:
                'Enregistrez une empreinte ou un visage dans les réglages de '
                'votre appareil pour utiliser ce raccourci.',
          ),
          IOSAuthMessages(
            cancelButton: 'Utiliser le mot de passe',
            goToSettingsButton: 'Réglages',
            goToSettingsDescription:
                'Activez Face ID ou Touch ID dans les réglages de votre '
                'appareil pour utiliser ce raccourci.',
            lockOut:
                'Déverrouillez votre appareil avec son code pour réactiver la '
                'biométrie.',
          ),
        ],
      );
    } catch (_) {
      return false;
    }
  }

  /// L'offre « se connecter plus vite la prochaine fois » n'est faite
  /// qu'une seule fois par compte : une question refusee ne doit pas
  /// revenir a chaque connexion.
  bool propositionFaite(String identifiant) {
    try {
      return Dependencies.get<SharedPrefService>()
          .getValue<bool>(_cleProposition(identifiant), false);
    } catch (_) {
      // Sans preferences lisibles, mieux vaut ne rien demander.
      return true;
    }
  }

  void marquerPropositionFaite(String identifiant) {
    try {
      Dependencies.get<SharedPrefService>()
          .putValue(_cleProposition(identifiant), true);
    } catch (_) {
      // Au pire la question reviendra une fois.
    }
  }

  /// Le raccourci n'existe plus : la question pourra etre reposee a la
  /// prochaine connexion avec mot de passe.
  void _oublierProposition(String identifiant) {
    try {
      Dependencies.get<SharedPrefService>()
          .removeRecord(_cleProposition(identifiant));
    } catch (_) {
      // Sans consequence.
    }
  }

  /// Le libelle du bouton, adapte a ce que l'appareil propose et au
  /// vocabulaire de la plateforme : « Face ID » sur iPhone, « visage »
  /// ailleurs.
  String libelle(TypeBiometrie type) {
    switch (type) {
      case TypeBiometrie.visage:
        return estApple
            ? 'Se connecter avec Face ID'
            : 'Se connecter avec la reconnaissance faciale';
      case TypeBiometrie.empreinte:
        return estApple
            ? 'Se connecter avec Touch ID'
            : "Se connecter avec l'empreinte";
      case TypeBiometrie.generique:
      case TypeBiometrie.aucune:
        return 'Déverrouiller';
    }
  }

  /// Le texte affiche par le systeme pendant la demande.
  String raison(TypeBiometrie type) {
    switch (type) {
      case TypeBiometrie.visage:
        return 'Confirmez votre identité pour ouvrir votre session';
      case TypeBiometrie.empreinte:
        return 'Posez votre doigt pour ouvrir votre session';
      case TypeBiometrie.generique:
      case TypeBiometrie.aucune:
        return 'Confirmez votre identité pour ouvrir votre session';
    }
  }

  /// Le nom du raccourci dans une phrase : « Activer Face ID ».
  String nomCourt(TypeBiometrie type) {
    switch (type) {
      case TypeBiometrie.visage:
        return estApple ? 'Face ID' : 'la reconnaissance faciale';
      case TypeBiometrie.empreinte:
        return estApple ? 'Touch ID' : "l'empreinte";
      case TypeBiometrie.generique:
      case TypeBiometrie.aucune:
        return 'le déverrouillage rapide';
    }
  }

  /// Vrai sur iPhone et iPad, ou les noms commerciaux d'Apple sont ceux
  /// que l'utilisateur connait. Faux, et sans planter, sur les autres
  /// plateformes.
  bool get estApple {
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  String _cleJeton(String identifiant) =>
      '$_prefixeJeton${identifiant.trim().toLowerCase()}';

  String _cleProposition(String identifiant) =>
      '$_prefixeProposition${identifiant.trim().toLowerCase()}';
}
