import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:immobilier/config.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/offline/coupure_reseau.dart';
import 'package:immobilier/core/offline/file_attente.dart';
import 'package:immobilier/core/offline/operation_en_attente.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:toastification/toastification.dart';

/// Ce que l'application affiche a l'utilisateur sur l'etat du reseau.
enum EtatSynchro {
  enLigne,
  horsConnexion,
  enAttente,
  enCours,
  synchronise,
}

extension EtatSynchroLibelle on EtatSynchro {
  String get libelle {
    switch (this) {
      case EtatSynchro.enLigne:
        return "En ligne";
      case EtatSynchro.horsConnexion:
        return "Hors connexion";
      case EtatSynchro.enAttente:
        return "Synchronisation en attente";
      case EtatSynchro.enCours:
        return "Synchronisation…";
      case EtatSynchro.synchronise:
        return "Synchronisé";
    }
  }
}

/// Signale a l'appelant que l'operation n'a pas ete envoyee mais
/// enregistree sur le telephone, et qu'elle partira toute seule.
class OperationMiseEnFileException implements Exception {
  final String message;
  OperationMiseEnFileException([
    this.message =
        "Enregistré sur le téléphone. L'envoi se fera dès le retour de la connexion.",
  ]);

  @override
  String toString() => message;
}

/// Surveille la connexion et vide la file d'attente des que possible.
///
/// Un seul envoi a la fois, dans l'ordre de creation. Chaque operation part
/// avec le jeton du compte qui l'a faite et sa cle d'idempotence : un renvoi
/// ne cree jamais de doublon, et n'est jamais attribue a un autre compte.
class Synchronisation extends ChangeNotifier with WidgetsBindingObserver {
  static final Synchronisation instance = Synchronisation._();
  Synchronisation._();

  Dio? _dio;

  /// Sonde sans cache : seule une vraie reponse du serveur prouve la connexion.
  final Dio _sonde = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    sendTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    validateStatus: (_) => true,
  ));

  /// Permet d'afficher un message sans dependre d'un ecran precis.
  /// Renseigne au demarrage a partir du routeur de l'application.
  BuildContext? Function()? fournisseurContexte;
  bool _enLigne = true;
  bool _envoiEnCours = false;
  bool _observateurInstalle = false;
  DateTime? _dernierEssai;
  Timer? _minuteurSynchronise;
  Timer? _minuteurReseau;
  StreamSubscription? _abonnement;

  bool get enLigne => _enLigne;
  int get nombreEnAttente => FileAttente.instance.nombreEnAttente;
  List<OperationEnAttente> get enAttente => FileAttente.instance.enAttente;
  List<OperationEnAttente> get refusees => FileAttente.instance.refusees;

  EtatSynchro _etat = EtatSynchro.enLigne;
  EtatSynchro get etat => _etat;

  /// A appeler au demarrage, une fois le client HTTP construit.
  Future<void> demarrer(Dio dio) async {
    _dio = dio;
    await FileAttente.instance.charger();

    _enLigne = await _verifierConnexion();
    _recalculerEtat();

    _ecouteConnectivite();
    _surveillanceReguliere();
    if (!_observateurInstalle) {
      WidgetsBinding.instance.addObserver(this);
      _observateurInstalle = true;
    }

    if (_enLigne) synchroniser();
  }

  /// Apres une connexion (ou a l'ouverture d'une session deja active) :
  /// le client HTTP porte le bon jeton, et les actions de ce compte en
  /// attente de reconnexion repartent.
  Future<void> apresConnexion(Dio dio, {int? managerId, String? jeton}) async {
    _dio = dio;
    if (jeton != null && jeton.isNotEmpty) {
      await FileAttente.instance.rattacherSession(managerId, jeton);
    }
    _recalculerEtat();
    synchroniser();
  }

  /// Le jeton de la session en cours.
  String jetonCourant() {
    try {
      return Dependencies.get<SharedPrefService>()
          .getValue(SharedPrefService.token, "");
    } catch (_) {
      return "";
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour dans l'application : on retente ce qui reste a envoyer.
    if (state == AppLifecycleState.resumed &&
        FileAttente.instance.envoyables.isNotEmpty) {
      synchroniser();
    }
  }

  /// Ecoute les changements de reseau signales par le systeme.
  void _ecouteConnectivite() {
    try {
      _abonnement?.cancel();
      _abonnement = Connectivity().onConnectivityChanged.listen((_) async {
        final avant = _enLigne;
        _enLigne = await _verifierConnexion();
        _recalculerEtat();
        if (_enLigne && (!avant || FileAttente.instance.envoyables.isNotEmpty)) {
          synchroniser();
        }
      });
    } catch (_) {
      // Sans notification systeme, la surveillance periodique prend le relais.
    }
  }

  /// Tant qu'il reste des actions a envoyer, on retente chaque minute ;
  /// sinon on se contente de suivre l'etat de la connexion.
  void _surveillanceReguliere() {
    _minuteurReseau?.cancel();
    _minuteurReseau = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_envoiEnCours) return;
      if (FileAttente.instance.envoyables.isNotEmpty) {
        synchroniser();
        return;
      }
      final avant = _enLigne;
      _enLigne = await _verifierConnexion();
      if (avant != _enLigne) _recalculerEtat();
    });
  }

  @override
  void dispose() {
    if (_observateurInstalle) WidgetsBinding.instance.removeObserver(this);
    _abonnement?.cancel();
    _minuteurReseau?.cancel();
    _minuteurSynchronise?.cancel();
    super.dispose();
  }

  /// La connexion n'existe que si NOTRE serveur repond : une interface
  /// reseau active ou un site tiers joignable ne suffisent pas.
  Future<bool> _verifierConnexion() async {
    try {
      final resultats = await Connectivity().checkConnectivity();
      if (resultats.every((r) => r == ConnectivityResult.none)) return false;
    } catch (_) {
      // Plugin indisponible : on s'en remet a la sonde ci-dessous.
    }

    try {
      await _sonde.get('$baseUrlApiVersion/$packageName');
      return true;
    } on DioException catch (ex) {
      return ex.response != null;
    } catch (_) {
      return false;
    }
  }

  /// Prend acte d'une coupure constatee lors d'un appel a l'API.
  void signalerCoupure() {
    if (_enLigne) {
      _enLigne = false;
      _recalculerEtat();
    }
  }

  /// Prend acte d'un echange reussi avec le serveur.
  void signalerSucces() {
    if (!_enLigne) {
      _enLigne = true;
      _recalculerEtat();
      synchroniser();
      return;
    }
    // Deja en ligne avec des actions en attente : on retente, sans
    // relancer a chaque reponse.
    final recent = _dernierEssai != null &&
        DateTime.now().difference(_dernierEssai!) < const Duration(seconds: 20);
    if (!recent && FileAttente.instance.envoyables.isNotEmpty) synchroniser();
  }

  Future<void> ajouterOperation(OperationEnAttente operation) async {
    await FileAttente.instance.ajouter(operation);
    _recalculerEtat();
    _prevenir(
      "Enregistré hors connexion",
      "L'envoi se fera automatiquement dès le retour de la connexion.",
    );
  }

  void _prevenir(String titre, String detail,
      {ToastificationType type = ToastificationType.info}) {
    final contexte = fournisseurContexte?.call();
    if (contexte == null) return;
    try {
      showToast(titre, contexte,
          description: detail, type: type, second: 4);
    } catch (_) {
      // Aucun ecran disponible : le bandeau suffit a informer.
    }
  }

  Future<void> oublierRefusees() async {
    await FileAttente.instance.viderRefusees();
    _recalculerEtat();
  }

  Future<void> oublier(String id) async {
    await FileAttente.instance.retirer(id);
    _recalculerEtat();
  }

  void _recalculerEtat() {
    final attente = FileAttente.instance.nombreEnAttente;
    EtatSynchro nouveau;

    if (!_enLigne) {
      nouveau = EtatSynchro.horsConnexion;
    } else if (_envoiEnCours) {
      nouveau = EtatSynchro.enCours;
    } else if (attente > 0) {
      nouveau = EtatSynchro.enAttente;
    } else if (_etat == EtatSynchro.enCours || _etat == EtatSynchro.synchronise) {
      nouveau = EtatSynchro.synchronise;
    } else {
      nouveau = EtatSynchro.enLigne;
    }

    // "Synchronisé" est un message de confirmation : il s'efface de lui-meme.
    _minuteurSynchronise?.cancel();
    if (nouveau == EtatSynchro.synchronise) {
      _minuteurSynchronise = Timer(const Duration(seconds: 5), () {
        if (_etat == EtatSynchro.synchronise) {
          _etat = _enLigne ? EtatSynchro.enLigne : EtatSynchro.horsConnexion;
          notifyListeners();
        }
      });
    }

    _etat = nouveau;
    notifyListeners();
  }

  /// Envoie les operations en attente, une par une, dans l'ordre.
  Future<void> synchroniser() async {
    if (_envoiEnCours || _dio == null) return;
    // Pose immediatement : deux declencheurs simultanes ne lancent
    // jamais deux envois.
    _envoiEnCours = true;

    try {
      await FileAttente.instance.charger();
      if (FileAttente.instance.envoyables.isEmpty) return;

      if (!await _verifierConnexion()) {
        _enLigne = false;
        return;
      }
      _enLigne = true;
      _recalculerEtat();

      for (final operation in FileAttente.instance.envoyables) {
        final continuer = await _envoyer(operation);
        if (!continuer) break; // coupure ou incident : on reprendra plus tard
      }
    } finally {
      _dernierEssai = DateTime.now();
      _envoiEnCours = false;
      _recalculerEtat();
    }
  }

  /// Renvoie false s'il faut interrompre la file (coupure, incident
  /// serveur) : l'ordre des operations est ainsi preserve.
  Future<bool> _envoyer(OperationEnAttente operation) async {
    operation.statut = StatutOperation.envoiEnCours;
    operation.tentatives++;
    await FileAttente.instance.mettreAJour(operation);
    notifyListeners();

    try {
      dynamic corps;
      if (operation.fichiers.isEmpty) {
        corps = operation.donnees;
      } else {
        final champs = Map<String, dynamic>.from(operation.donnees);
        for (final entree in operation.fichiers.entries) {
          final pieces = <MultipartFile>[];
          for (final chemin in entree.value) {
            final fichier = await FileAttente.instance.retrouverPiece(chemin);
            if (fichier != null) {
              pieces.add(await MultipartFile.fromFile(
                fichier,
                filename: fichier.split(RegExp(r'[\\/]')).last,
              ));
            }
          }
          if (pieces.isEmpty) continue;
          // Un champ dont le nom se termine par [] attend une liste.
          champs[entree.key] =
              entree.key.endsWith('[]') ? pieces : pieces.first;
        }
        corps = FormData.fromMap(champs);
      }

      final jeton = (operation.jeton ?? '').isNotEmpty
          ? operation.jeton!
          : jetonCourant();

      await _dio!.request(
        operation.chemin,
        data: corps,
        options: Options(
          method: operation.methode,
          headers: {
            // Le serveur memorise cette cle : un renvoi ne cree pas de doublon.
            'X-Idempotency-Key': operation.id,
            if (jeton.isNotEmpty) 'Authorization': 'Bearer $jeton',
          },
        ),
      );

      await FileAttente.instance.retirer(operation.id);
      return true;
    } on DioException catch (ex) {
      final code = ex.response?.statusCode ?? 0;

      if (code == 0 || estCoupureReseau(ex)) {
        operation.statut = StatutOperation.enAttente;
        await FileAttente.instance.mettreAJour(operation);
        _enLigne = false;
        return false;
      }

      if (code == 409 &&
          ex.response?.headers.value('x-idempotent-en-cours') != null) {
        // Le serveur traite deja cette operation : on verifiera plus tard.
        operation.statut = StatutOperation.enAttente;
        await FileAttente.instance.mettreAJour(operation);
        return false;
      }

      if (code == 401) {
        // Session expiree : l'action attend que ce compte se reconnecte.
        operation.statut = StatutOperation.enAttente;
        operation.aReconnecter = true;
        operation.message = "Session expirée : reconnectez-vous"
            "${(operation.managerNom ?? '').isNotEmpty ? ' avec le compte ${operation.managerNom}' : ''}"
            " pour envoyer cette action.";
        await FileAttente.instance.mettreAJour(operation);
        return true;
      }

      if (code >= 500 || code == 429) {
        operation.statut = StatutOperation.enAttente;
        operation.message =
            "Le serveur n'a pas pu traiter l'opération. Nouvel essai dans une minute.";
        await FileAttente.instance.mettreAJour(operation);
        return false;
      }

      // Refus definitif : dates deja prises, donnees invalides, droits
      // insuffisants. L'utilisateur doit en etre informe.
      operation.statut = StatutOperation.refusee;
      operation.message = _motifRefus(ex);
      await FileAttente.instance.mettreAJour(operation);
      _prevenir(
        "Opération refusée",
        "${operation.libelle} : ${operation.message}",
        type: ToastificationType.error,
      );
      return true;
    } catch (_) {
      operation.statut = StatutOperation.enAttente;
      await FileAttente.instance.mettreAJour(operation);
      return false;
    }
  }

  String _motifRefus(DioException ex) {
    try {
      final erreur = ex.response?.data["error"];
      if (erreur is Map) {
        final premier = erreur.values.first;
        if (premier is List && premier.isNotEmpty) return premier.first.toString();
        return premier.toString();
      }
      final message = ex.response?.data["message"];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      // Reponse inattendue : message generique ci-dessous.
    }
    return "Opération refusée par le serveur.";
  }
}
