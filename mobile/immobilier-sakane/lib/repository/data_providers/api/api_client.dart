import 'package:immobilier/models/bien_desactive.dart';
import 'package:immobilier/models/reception_whatsapp.dart';
import 'package:immobilier/models/module_accueil.dart';
import 'package:immobilier/models/categories_immobilier.dart';
import 'package:immobilier/models/apercu_famille.dart';
import 'package:immobilier/models/apercu_bien.dart';
import 'package:immobilier/models/resume_accueil.dart';
import 'dart:typed_data';
import 'package:immobilier/models/charge_annulee.dart';

import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/features/immobilier/list_immobilier/bloc/realestate_cubit.dart';
import 'package:immobilier/models/application.dart';
import 'package:immobilier/core/services/transcription_arabe.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/reservation_supprimee.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/contract.dart';
import 'package:immobilier/models/feature.dart';
import 'package:immobilier/models/financial_stats.dart';
import 'package:immobilier/models/global_stats.dart';
import 'package:immobilier/models/immobilier_overview.dart';

import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/programed_charge.dart';
import 'package:immobilier/models/rapport.dart';
import 'package:immobilier/models/reclamation.dart';
import 'package:immobilier/models/realestate_stats.dart';

import 'package:immobilier/models/region.dart';

import 'package:immobilier/models/city.dart';

import 'package:immobilier/models/etat.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:immobilier/models/category.dart';
import 'package:immobilier/models/type_transaction.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';

import '../../../core/utils/helper_functions.dart';
import '../../../exceptions/network_connectivity_exception.dart';
import '../../../exceptions/unauthenticated_exception.dart';
import '../../../models/charge.dart';
import '../../../models/manager.dart';
import '../../../models/slider.dart';
import 'package:immobilier/models/secteur.dart';
import 'package:immobilier/core/offline/file_attente.dart';
import 'package:immobilier/core/offline/operation_en_attente.dart';
import 'package:immobilier/core/offline/synchronisation.dart';
import 'package:immobilier/core/offline/cache_lecture.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:immobilier/models/numero_campagnes.dart';
import 'package:immobilier/models/modele_message.dart';
import 'dart:convert';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/models/contrat_proprietaire.dart';
import 'package:immobilier/models/apercu_suppression.dart';
import 'package:immobilier/core/offline/coupure_reseau.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/models/facture_reservation.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/models/envoi_historique_syndic.dart';
import 'package:immobilier/models/permissions_roles.dart';

class ApiClient {
  late Dio _dio;
  late Dio _dioAppsVersion;

  /// Utilise par le service de synchronisation pour rejouer la file.
  Dio get dio => _dio;

  /// Conserve une ecriture impossible faute de reseau, puis previent
  /// l'appelant. L'envoi se fera tout seul au retour de la connexion.
  ///
  /// [octets] sert aux contenus deja en memoire (signature manuscrite).
  Future<Never> _mettreEnFile({
    required String type,
    required String libelle,
    required String chemin,
    String methode = "POST",
    Map<String, dynamic> donnees = const {},
    Map<String, List<String>> fichiers = const {},
    Map<String, List<int>> octets = const {},
    String? id,
  }) async {
    // La cle d'idempotence du premier envoi est reprise : si le serveur
    // l'avait deja traite, le renvoi ne cree pas de doublon.
    id ??= OperationEnAttente.nouvelId();
    final pieces = <String, List<String>>{};

    for (final champ in fichiers.entries) {
      final copies = <String>[];
      for (final chemin in champ.value) {
        final copie = await FileAttente.instance.conserverPiece(chemin, id);
        if (copie != null) copies.add(copie);
      }
      if (copies.isNotEmpty) pieces[champ.key] = copies;
    }

    for (final champ in octets.entries) {
      final copie = await FileAttente.instance
          .conserverOctets(champ.value, "${champ.key}.png", id);
      if (copie != null) pieces[champ.key] = [copie];
    }

    await Synchronisation.instance.ajouterOperation(OperationEnAttente(
      id: id,
      type: type,
      libelle: libelle,
      methode: methode,
      chemin: chemin,
      donnees: donnees,
      fichiers: pieces,
      jeton: Synchronisation.instance.jetonCourant(),
      managerId: _managerCourant()?.id,
      managerNom: _nomManagerCourant(),
    ));
    Synchronisation.instance.signalerCoupure();

    throw OperationMiseEnFileException();
  }

  Manager? _managerCourant() {
    try {
      return Dependencies.get<Manager>();
    } catch (_) {
      return null;
    }
  }

  String? _nomManagerCourant() {
    final m = _managerCourant();
    if (m == null) return null;
    final nom = "${m.firstName ?? ''} ${m.lastName ?? ''}".trim();
    return nom.isEmpty ? null : nom;
  }

  ApiClient({required String baseUrl,String? apiAppsVersion, String? token}) {
    _dio =
        Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: Duration(seconds: 20),
              // Au-dela, l'envoi est considere comme coupe : il est mis en file.
              sendTimeout: Duration(seconds: 120),
              receiveTimeout: Duration(seconds: 120),
              contentType: "application/json",
              headers: {
                "Accept": "application/json",
                "Authorization": "Bearer ${token}",
              },
            ),
          )
          ..interceptors.add(CacheLecture())
          ..interceptors.add(
            LogInterceptor(
              error: true,
              responseHeader: true,
              responseBody: true,
              requestHeader: true,
              requestBody: true,
              request: true,
            ),
          );

    _dioAppsVersion =
    Dio(
      BaseOptions(
        baseUrl: apiAppsVersion??"",
        connectTimeout: Duration(seconds: 20),
        contentType: "application/json",
        headers: {
          "Accept": "application/json",
        },
      ),
    )
      ..interceptors.add(CacheLecture())
      ..interceptors.add(
        LogInterceptor(
          error: true,
          responseHeader: true,
          responseBody: true,
          requestHeader: true,
          requestBody: true,
          request: true,
        ),
      );


  }

  /// Mot de passe oublie - etape 1 : demande d'envoi du code par WhatsApp.
  Future<String> forgetPassword(String email) async {
    try {
      var response = await _dio.post('/forget-password', data: {"email": email});
      return response.data["data"]?["phone"] ?? "";
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            (ex.response?.data["data"] ?? {}) as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  /// Mot de passe oublie - etape 2 : verification du code recu.
  Future<void> checkOtp(String email, String otp) async {
    try {
      await _dio.post('/check-otp', data: {"email": email, "otp": otp});
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            (ex.response?.data["data"] ?? {}) as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  /// Mot de passe oublie - etape 3 : enregistrement du nouveau mot de passe.
  Future<void> resetPassword(
      String email, String otp, String password, String confirmation) async {
    try {
      await _dio.post('/reset-password', data: {
        "email": email,
        "otp": otp,
        "password": password,
        "password_confirmation": confirmation,
      });
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            (ex.response?.data["data"] ?? {}) as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Manager> login(Manager manager) async {
    try {
      var response = await _dio.post('/login', data: manager.toJson());
      Manager managerR = Manager.fromJson(response.data["data"]);
      return managerR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      final code = ex.response?.statusCode ?? 0;
      // Le serveur dit lui-meme pourquoi il refuse. Son message vaut mieux
      // qu'un texte generique, surtout depuis qu'un identifiant peut etre
      // une adresse e-mail comme un numero de telephone.
      if (code == 401 || code == 422) {
        throw UnAuthenticatedException(_messageRefusConnexion(ex));
      }
      if (code == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  /// Le message de refus renvoye par le serveur, s'il en donne un.
  String? _messageRefusConnexion(DioException ex) {
    final donnees = ex.response?.data;
    if (donnees is Map) {
      final message = donnees['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      final erreurs = donnees['errors'];
      if (erreurs is Map && erreurs.isNotEmpty) {
        final premiere = erreurs.values.first;
        if (premiere is List && premiere.isNotEmpty) {
          return premiere.first.toString();
        }
        if (premiere is String && premiere.trim().isNotEmpty) {
          return premiere.trim();
        }
      }
    }
    return null;
  }

  Future<Manager> me() async {
    try {
      var response = await _dio.get('/me');
      Manager managerR = Manager.fromJson(response.data["data"]);
      return managerR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<Realestate>> getRealestates(
      {String? status, String? type, String? dossier}) async {
    try {
      var response = await _dio.get("/realestates", queryParameters: {
        if (status != null) "status": status,
        // Famille de biens : le serveur restreint la liste.
        if (type != null) "type": type,
        // Dossier de rangement ; « aucun » vise les biens non rangés.
        if (dossier != null) "dossier": dossier,
      });
      List<Realestate> realestates = (response.data["data"] as List)
          .map((obj) => Realestate.fromJson(obj))
          .toList();
      return realestates;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<Category>> fetchCategories() async {
    try {
      var response = await _dio.get('/realestates/categories');
      List<Category> categories = (response.data["data"] as List)
          .map((obj) => Category.fromJson(obj))
          .toList();
      return categories;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<TypeTransaction>> fetchTransactionTypes() async {
    try {
      var response = await _dio.get('/realestates/transaction-types');
      List<TypeTransaction> types = (response.data["data"] as List)
          .map((obj) => TypeTransaction.fromJson(obj))
          .toList();
      return types;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<Etat>> fetchEtats() async {
    try {
      var response = await _dio.get('/realestates/etats');
      List<Etat> etats = (response.data["data"] as List)
          .map((obj) => Etat.fromJson(obj))
          .toList();
      return etats;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  // ================= Dossiers de biens =================

  Future<List<Dossier>> fetchDossiers({String? type}) async {
    try {
      final reponse = await _dio.get(
        '/dossiers',
        queryParameters: type != null ? {'type': type} : null,
      );
      return (reponse.data["data"] as List)
          .map((o) => Dossier.fromJson(o))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Cree un dossier, avec eventuellement les biens qui le rejoignent.
  Future<Dossier> creerDossier(String nom,
      {String? description, String? type, List<int>? biens}) async {
    try {
      final reponse = await _dio.post('/dossiers', data: {
        "nom": nom,
        if (description != null && description.isNotEmpty)
          "description": description,
        // La famille rattache le dossier : il n'apparaitra pas ailleurs.
        if (type != null) "type": type,
        if (biens != null && biens.isNotEmpty) "biens": biens,
      });
      return Dossier.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<Dossier> renommerDossier(int id, String nom,
      {String? description}) async {
    try {
      final reponse = await _dio.put('/dossiers/$id', data: {
        "nom": nom,
        if (description != null) "description": description,
      });
      return Dossier.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Supprime le dossier. Les biens qu'il contenait redeviennent libres.
  Future<void> supprimerDossier(int id) async {
    try {
      await _dio.delete('/dossiers/$id');
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Agents autorises sur un dossier. Remplace l'affectation existante.
  Future<List<AgentDuDossier>> affecterAgentsDossier(
      int dossierId, List<int> agents) async {
    try {
      final reponse = await _dio.post('/dossiers/$dossierId/agents',
          data: {"agents": agents});
      return (reponse.data["data"]["agents"] as List)
          .map((e) => AgentDuDossier.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Dossiers accessibles a un agent.
  Future<List<Dossier>> dossiersDeLAgent(int managerId) async {
    try {
      final reponse = await _dio.get('/managers/$managerId/dossiers');
      return (reponse.data["data"]["dossiers"] as List)
          .map((e) => Dossier.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<List<Dossier>> majDossiersDeLAgent(
      int managerId, List<int> dossiers) async {
    try {
      final reponse = await _dio.put('/managers/$managerId/dossiers',
          data: {"dossiers": dossiers});
      return (reponse.data["data"]["dossiers"] as List)
          .map((e) => Dossier.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Range des biens dans un dossier ; [dossier] a null les en sort.
  Future<int> affecterAuDossier(List<int> biens, int? dossier) async {
    try {
      final reponse = await _dio.post('/dossiers/affecter', data: {
        "biens": biens,
        "dossier": dossier,
      });
      return reponse.data["data"]["biensDeplaces"] ?? 0;
    } on DioException catch (ex) {
      // Le serveur explique un refus (réservations en cours ou à venir,
      // droits…) : son message est affiché tel quel.
      throw Exception(messageServeur(ex, "Le déplacement a échoué."));
    }
  }

  /// Secteurs existants, eventuellement limites a une ville.
  Future<List<Secteur>> fetchSecteurs({int? cityId}) async {
    try {
      var response = await _dio.get(
        '/secteurs',
        queryParameters: cityId != null ? {'city': cityId} : null,
      );
      return (response.data["data"] as List)
          .map((obj) => Secteur.fromJson(obj))
          .toList();
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  /// Cree un secteur. Le serveur renvoie l'existant si le nom est deja pris.
  Future<Secteur> addSecteur(String nom, {int? cityId}) async {
    try {
      var response = await _dio.post('/secteurs', data: {
        'nom': nom,
        if (cityId != null) 'city': cityId,
      });
      return Secteur.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  // ================= Apercu du contrat =================

  /// Genere l'apercu du bulletin avant signature et l'enregistre dans un
  /// fichier temporaire. Retourne son chemin, a ouvrir avec le lecteur
  /// PDF du telephone.
  Future<String> apercuContrat({
    required String checkin,
    required String checkout,
    required int guest,
    required int realestate,
    required int client,
    required num nightPrice,
    required String typeGuest,
    num? avance,
    num? caution,
    String? heureArrivee,
    String? heureDepart,
  }) async {
    try {
      final reponse = await _dio.post('/bookings/apercu-contrat', data: {
        "checkin": checkin,
        "checkout": checkout,
        "guest": guest,
        "realestate": realestate,
        "client": client,
        "nightPrice": nightPrice,
        "typeGuest": typeGuest,
        if (heureArrivee != null) "heureArrivee": heureArrivee,
        if (heureDepart != null) "heureDepart": heureDepart,
        if (avance != null) "avance": avance,
        if (caution != null) "caution": caution,
      });

      final octets = base64Decode(reponse.data["data"]["pdf"]);
      final dossier = await getTemporaryDirectory();
      final chemin = '${dossier.path}/apercu-contrat.pdf';
      await File(chemin).writeAsBytes(octets, flush: true);
      return chemin;
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  // ================= Factures =================

  /// La facture d'une reservation, deposee dans un fichier temporaire.
  /// Non appliquee, le serveur rend un apercu sans numero.
  Future<FactureReservation> factureReservation(int id) async {
    try {
      final reponse = await _dio.get('/bookings/$id/facture');
      final donnees = Map<String, dynamic>.from(reponse.data["data"] as Map);

      final octets = base64Decode(donnees["pdf"]);
      final dossier = await getTemporaryDirectory();
      // Horodate : le visualiseur garderait sinon l'ancienne version en cache
      final nom = (donnees["nom"] ?? "facture.pdf").toString().replaceAll(RegExp(r'\.pdf$'), '');
      final chemin = '${dossier.path}/${nom}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await File(chemin).writeAsBytes(octets, flush: true);
      return FactureReservation.fromJson(donnees, chemin);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "La facture n'a pas pu être préparée."));
    }
  }

  /// Envoie la facture (appliquee) au client, par WhatsApp ; rend le
  /// numero utilise.
  Future<String> envoyerFacture(int id) async {
    try {
      final reponse = await _dio.post('/bookings/$id/facture/envoyer');
      final donnees = reponse.data is Map ? reponse.data["data"] : null;
      return (donnees is Map ? donnees["envoyeA"] ?? '' : '').toString();
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "La facture n'a pas pu être envoyée."));
    }
  }

  // ================= Detail, prix et facture d'une reservation =================

  /// 401 deconnecte ; le reste (403 compris) garde le message du serveur.
  Exception _erreurReservation(DioException ex, String defaut) {
    if ((ex.response?.statusCode ?? 0) == 401) return UnAuthenticatedException();
    return Exception(messageServeur(ex, defaut));
  }

  Map<String, dynamic> _donneesReservation(dynamic data) {
    final corps = data is Map && data['data'] is Map ? data['data'] : data;
    return Map<String, dynamic>.from(corps as Map);
  }

  /// Tout sur une reservation : montants, historique, caisse, facture.
  Future<DetailReservation> detailReservation(int id) async {
    try {
      final reponse = await _dio.get('/bookings/$id/detail');
      return DetailReservation.fromJson(_donneesReservation(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReservation(ex, "La rÃ©servation n'a pas pu Ãªtre chargÃ©e.");
    }
  }

  /// Nouveau prix par nuit. [encaisse] : ce qui entre dans ma caisse
  /// quand le total augmente ; [rembourser] : rendre le trop-percu
  /// depuis ma caisse quand il baisse.
  Future<DetailReservation> modifierPrixReservation(int id,
      {required double prixNuit, double? encaisse, bool? rembourser}) async {
    try {
      final reponse = await _dio.post('/bookings/$id/modifier-prix', data: {
        'prixNuit': prixNuit,
        if (encaisse != null) 'encaisse': encaisse,
        if (rembourser != null) 'rembourser': rembourser,
      });
      return DetailReservation.fromJson(_donneesReservation(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReservation(ex, "Le prix n'a pas pu Ãªtre modifiÃ©.");
    }
  }

  Future<ResumeFacture> resumeFacture(int id) async {
    try {
      final reponse = await _dio.get('/bookings/$id/facture/resume');
      return ResumeFacture.fromJson(_donneesReservation(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReservation(ex, "La facture n'a pas pu être chargée.");
    }
  }

  /// Applique la facture, une fois pour toutes : la TVA entre dans la
  /// caisse de l'utilisateur connecte. Deja appliquee : 422.
  Future<ResumeFacture> appliquerFacture(
    int id, {
    double? tva,
    String? clientNom,
    String? clientIce,
    String? clientAdresse,
  }) async {
    try {
      final reponse = await _dio.post('/bookings/$id/facture/appliquer', data: {
        if (tva != null) 'tva': tva,
        if (clientNom != null) 'clientNom': clientNom,
        if (clientIce != null) 'clientIce': clientIce,
        if (clientAdresse != null) 'clientAdresse': clientAdresse,
      });
      return ResumeFacture.fromJson(_donneesReservation(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReservation(ex, "La facture n'a pas pu être appliquée.");
    }
  }

  // ================= Heures par defaut =================

  Future<HeuresParDefaut> heuresParDefaut() async {
    try {
      final reponse = await _dio.get('/reglages/heures');
      return HeuresParDefaut.fromJson(_donneesReservation(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReservation(ex, "Les heures par dÃ©faut n'ont pas pu Ãªtre chargÃ©es.");
    }
  }

  /// Reserve a l'administrateur (403 sinon).
  Future<HeuresParDefaut> enregistrerHeuresParDefaut({String? arrivee, String? depart}) async {
    try {
      final reponse = await _dio.put('/reglages/heures', data: {
        if (arrivee != null) 'arrivee': arrivee,
        if (depart != null) 'depart': depart,
      });
      final data = reponse.data;
      final corps = data is Map ? data['data'] : null;
      if (corps is Map) return HeuresParDefaut.fromJson(Map<String, dynamic>.from(corps));
      return HeuresParDefaut(arrivee: arrivee ?? '14:00', depart: depart ?? '12:00');
    } on DioException catch (ex) {
      throw _erreurReservation(ex, "Les heures n'ont pas pu Ãªtre enregistrÃ©es.");
    }
  }

  // ================= Modeles de messages =================

  Future<List<ModeleMessage>> fetchModelesMessages() async {
    try {
      final response = await _dio.get('/modeles-messages');
      return (response.data["data"] as List)
          .map((obj) => ModeleMessage.fromJson(obj))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<ModeleMessage> fetchModeleMessage(int id) async {
    try {
      final response = await _dio.get('/modeles-messages/$id');
      return ModeleMessage.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<List<VariableModele>> fetchVariablesModeles() async {
    try {
      final response = await _dio.get('/modeles-messages/variables');
      return (response.data["data"] as List)
          .map((obj) => VariableModele.fromJson(obj))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Rendu du texte avec des valeurs d'exemple, avant enregistrement.
  Future<ApercuModele> apercuModele(String contenu) async {
    try {
      final response = await _dio.post('/modeles-messages/apercu',
          data: {"contenu": contenu});
      return ApercuModele.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<ModeleMessage> majModeleMessage(int id, String contenu,
      {bool? actif}) async {
    try {
      final response = await _dio.put('/modeles-messages/$id', data: {
        "contenu": contenu,
        if (actif != null) "actif": actif ? 1 : 0,
      });
      return ModeleMessage.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Revient au texte fourni avec l'application.
  /// Joint une image au modele : elle partira avec le message.
  Future<ModeleMessage> deposerImageModele(int id, File image) async {
    try {
      final donnees = FormData.fromMap({
        "image": await MultipartFile.fromFile(
          image.path,
          filename: image.path.split('/').last,
        ),
      });
      final reponse = await _dio.post('/modeles-messages/$id/image', data: donnees);
      return ModeleMessage.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Retire l'image : le message repart en texte seul.
  Future<ModeleMessage> retirerImageModele(int id) async {
    try {
      final reponse = await _dio.delete('/modeles-messages/$id/image');
      return ModeleMessage.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<ModeleMessage> restaurerModeleMessage(int id) async {
    try {
      final response = await _dio.patch('/modeles-messages/$id/restaurer');
      return ModeleMessage.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  // ================= Campagnes / diffusion clients =================

  Future<List<Campagne>> fetchCampagnes() async {
    try {
      final response = await _dio.get('/campagnes');
      return (response.data["data"] as List)
          .map((obj) => Campagne.fromJson(obj))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<Campagne> fetchCampagne(int id) async {
    try {
      final response = await _dio.get('/campagnes/$id');
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Segments proposes par le serveur, avec leur libelle.
  Future<List<Map<String, String>>> fetchSegmentsCampagne() async {
    try {
      final response = await _dio.get('/campagnes/segments');
      return (response.data["data"] as List)
          .map((e) => {
                "code": (e["code"] ?? '').toString(),
                "name": (e["name"] ?? '').toString(),
              })
          .toList();
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Nombre de clients vises, avant de creer la campagne.
  Future<EstimationSegment> estimerSegment(SegmentClients segment) async {
    try {
      final response = await _dio.post('/campagnes/estimer',
          data: {"segment": segment.toJson()});
      return EstimationSegment.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<Campagne> addCampagne(Campagne campagne,
      {bool envoyerMaintenant = false}) async {
    try {
      final champs = <String, dynamic>{
        "titre": campagne.titre,
        "message": campagne.message,
        if (campagne.lien != null && campagne.lien!.isNotEmpty)
          "lien": campagne.lien,
        "segment": campagne.segment.toJson(),
        if (campagne.planifieeA != null)
          "planifieeA": campagne.planifieeA!.toIso8601String(),
        "envoyer": envoyerMaintenant ? 1 : 0,
      };

      if (campagne.image != null) {
        champs["image"] = await MultipartFile.fromFile(
          campagne.image!.path,
          filename: campagne.image!.path.split('/').last,
        );
      }

      // Le segment est un objet : FormData ne sait pas l'aplatir seul.
      final donnees = FormData();
      champs.forEach((cle, valeur) {
        if (cle == "segment") {
          (valeur as Map<String, dynamic>).forEach((k, v) {
            if (v is List) {
              for (final e in v) {
                donnees.fields.add(MapEntry("segment[$k][]", e.toString()));
              }
            } else {
              donnees.fields.add(MapEntry("segment[$k]", v.toString()));
            }
          });
        } else if (valeur is MultipartFile) {
          donnees.files.add(MapEntry(cle, valeur));
        } else if (valeur != null) {
          donnees.fields.add(MapEntry(cle, valeur.toString()));
        }
      });

      final response = await _dio.post('/campagnes', data: donnees);
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Envoi test vers un numero choisi, sans toucher aux clients.
  Future<void> envoyerTestCampagne({
    required String telephone,
    required String message,
    String? lien,
    int? campagneId,
  }) async {
    try {
      await _dio.post('/campagnes/test', data: {
        "telephone": telephone,
        "message": message,
        if (lien != null && lien.isNotEmpty) "lien": lien,
        if (campagneId != null) "campagne": campagneId,
      });
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<Campagne> lancerCampagne(int id) async {
    try {
      final response = await _dio.patch('/campagnes/$id/envoyer');
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<Campagne> annulerCampagne(int id) async {
    try {
      final response = await _dio.patch('/campagnes/$id/annuler');
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<Campagne> relancerEchecsCampagne(int id) async {
    try {
      final response = await _dio.patch('/campagnes/$id/relancer-echecs');
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Suspend l'envoi : les messages restants gardent leur ordre.
  Future<Campagne> pauseCampagne(int id) async {
    try {
      final response = await _dio.patch('/campagnes/$id/pause');
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Reprend l'envoi la ou il s'etait arrete.
  Future<Campagne> reprendreCampagne(int id) async {
    try {
      final response = await _dio.patch('/campagnes/$id/reprendre');
      return Campagne.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  Future<void> supprimerCampagne(int id) async {
    try {
      await _dio.delete('/campagnes/$id');
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  /// Autorise ou refuse les messages promotionnels pour un client.
  Future<bool> majPromotionsClient(int clientId, bool accepte) async {
    try {
      final response = await _dio.patch('/clients/$clientId/promotions',
          data: {"accepte": accepte ? 1 : 0});
      return response.data["data"]["acceptePromotions"] == true;
    } on DioException catch (ex) {
      throw _erreurCampagne(ex);
    }
  }

  // ---- Numero WhatsApp dedie aux campagnes (session Wasender) ----

  Future<NumeroCampagnes> fetchNumeroCampagnes() async {
    try {
      final response = await _dio.get('/campagnes-whatsapp');
      return NumeroCampagnes.fromJson(
          Map<String, dynamic>.from(response.data["data"] as Map));
    } on DioException catch (ex) {
      throw _erreurNumeroCampagnes(
          ex, "Le numéro des campagnes n'a pas pu être chargé.");
    }
  }

  /// Enregistre la cle API d'une session Wasender : le serveur la verifie
  /// puis la garde chiffree. Seule sa version masquee revient.
  Future<NumeroCampagnes> enregistrerNumeroCampagnes(String cle) async {
    try {
      final response =
          await _dio.put('/campagnes-whatsapp', data: {"cle": cle});
      return NumeroCampagnes.fromJson(
          Map<String, dynamic>.from(response.data["data"] as Map));
    } on DioException catch (ex) {
      throw _erreurNumeroCampagnes(
          ex, "La clé n'a pas pu être enregistrée.");
    }
  }

  /// Les campagnes repartent du numero principal.
  Future<NumeroCampagnes> retirerNumeroCampagnes() async {
    try {
      final response = await _dio.delete('/campagnes-whatsapp');
      return NumeroCampagnes.fromJson(
          Map<String, dynamic>.from(response.data["data"] as Map));
    } on DioException catch (ex) {
      throw _erreurNumeroCampagnes(
          ex, "Le numéro principal n'a pas pu être rétabli.");
    }
  }

  Exception _erreurNumeroCampagnes(DioException ex, String defaut) {
    if ((ex.response?.statusCode ?? 0) == 401) return UnAuthenticatedException();
    if ((ex.response?.statusCode ?? 0) == 403) {
      return Exception(messageServeur(
          ex, "Réservé aux administrateurs."));
    }
    return Exception(messageServeur(ex, defaut));
  }

  /// Traduit une erreur reseau en exception connue de l'application.
  Object _erreurCampagne(DioException ex) {
    if (estCoupureReseau(ex)) {
      return NetworkConnectivityException();
    }
    final code = ex.response?.statusCode ?? 0;
    if (code == 401) return UnAuthenticatedException();
    if (code == 403) return UnAuthorizedException();
    if (code == 422) {
      final erreurs = ex.response?.data["error"];
      if (erreurs is Map<String, dynamic>) return ValidatorException(erreurs);
    }
    return ex;
  }

  Future<List<City>> fetchCities({required int regionId}) async {
    try {
      var response = await _dio.get(
        '/cities',
        queryParameters: {'region': regionId},
      );
      List<City> cities = (response.data["data"] as List)
          .map((obj) => City.fromJson(obj))
          .toList();
      return cities;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<Region>> fetchRegions() async {
    try {
      var response = await _dio.get('/regions');
      List<Region> regions = (response.data["data"] as List)
          .map((obj) => Region.fromJson(obj))
          .toList();
      return regions;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<Owner>> fetchOwners() async {
    try {
      var response = await _dio.get('/owners');
      List<Owner> owners = (response.data["data"] as List)
          .map((obj) => Owner.fromJson(obj))
          .toList();
      return owners;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<List<Feature>> fetchFeatures() async {
    try {
      var response = await _dio.get('/features');
      List<Feature> features = (response.data["data"] as List)
          .map((obj) => Feature.fromJson(obj))
          .toList();
      return features;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<Realestate> fetchRealestate(int id) async {
    try {
      var response = await _dio.get('/realestates/${id}');
      Realestate realestate = Realestate.fromJson(response.data["data"]);
      return realestate;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<Realestate> addRealestate(Realestate realestate) async {
    try {
      final json = await realestate.toJson();
      FormData formData = FormData.fromMap(json);
      print("============data:${realestate.toJson()}");

      var response = await _dio.post('/realestates', data: formData);
      Realestate realestateR = Realestate.fromJson(response.data["data"]);
      return realestateR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;

    }
  }

  Future<Realestate> updateRealestate(Realestate realestate) async {
    try {
      final json = await realestate.toJson();
      FormData formData = FormData.fromMap(json);

      var response = await _dio.post(
        '/realestates/${realestate.id}',
        data: formData,
      );
      Realestate realestateR = Realestate.fromJson(response.data["data"]);
      return realestateR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;

    }
  }

  Future<Owner> addOwner(Owner owner) async {
    try {
      var response = await _dio.post("/owners", data: owner.toJson());
      Owner ownerRes = Owner.fromJson(response.data["data"]);
      return ownerRes;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }

      rethrow;
    }
  }

  Future<Owner> updateOwner(Owner owner) async {
    try {
      var response = await _dio.put("/owners/${owner.id}", data: owner.toJson());
      return Owner.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  /// [airbnbSejour] : sejour Airbnb dont cette reservation est le contrat.
  Future<Booking> addBooking(Booking booking, {int? airbnbSejour}) async {
    // Meme cle au premier envoi et aux renvois : jamais de doublon.
    final cle = OperationEnAttente.nouvelId();
    try {
      final json=await booking.toJson();
      if (airbnbSejour != null) {
        json["airbnbSejour"] = airbnbSejour;
        // Contrat Airbnb : le client a deja paye sur Airbnb, l'agent
        // n'encaisse rien. Le montant va seul a la caisse Airbnb.
        json
          ..remove("avance")
          ..remove("caution")
          ..remove("appliquerFacture")
          ..remove("tvaFacture");
      }
      print(json);
      final formData=FormData.fromMap(json);
      var response = await _dio.post("/bookings", data: formData, options: Options(headers: {'X-Idempotency-Key': cle}));
      Booking bookingRes = Booking.fromJson(response.data["data"]);
      return bookingRes;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        // La disponibilite ne peut etre verifiee que par le serveur :
        // la reservation reste en attente de synchronisation.
        if (booking.realestate?.id == null || booking.client?.id == null) {
          throw NetworkConnectivityException();
        }
        await _mettreEnFile(
          id: cle,
          type: "booking",
          libelle:
              "Réservation — ${booking.realestate?.title ?? 'bien'} "
              "du ${booking.checkin?.formattedDateEn} au ${booking.checkout?.formattedDateEn}",
          chemin: "/bookings",
          donnees: {
            "checkin": booking.checkin?.formattedDateEn,
            "checkout": booking.checkout?.formattedDateEn,
            "guest": booking.nbGuest,
            "realestate": booking.realestate?.id,
            "client": booking.client?.id,
            "nightPrice": booking.nightPrice,
            "typeGuest": booking.typeGuest,
            if (booking.heureArrivee != null)
              "heureArrivee": booking.heureArrivee,
            if (booking.heureDepart != null)
              "heureDepart": booking.heureDepart,
            if (airbnbSejour == null && booking.avance != null)
              "avance": booking.avance,
            if (airbnbSejour == null && booking.caution != null)
              "caution": booking.caution,
            if (booking.remarques != null) "remarques": booking.remarques,
            if (airbnbSejour == null && booking.appliquerFacture == true) ...{
              "appliquerFacture": 1,
              "tvaFacture": booking.tvaFacture ?? 20,
            },
            if (airbnbSejour != null) "airbnbSejour": airbnbSejour,
          },
          octets: booking.signature != null
              ? {"signature": booking.signature!}
              : const {},
        );
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      // Sans detail de validation, le message du serveur est lu par le cubit.
      final erreurs = ex.response?.data is Map ? ex.response?.data["error"] : null;
      if ((ex.response?.statusCode ?? 0) == 422 && erreurs is Map) {
        throw ValidatorException(Map<String, dynamic>.from(erreurs));
      }
      rethrow;
    }
  }

  /// [search] : recherche cote serveur (prenom, nom, telephone, CIN,
  /// e-mail) ; sans elle, la liste complete est renvoyee.
  Future<List<Client>> getClients({String? search}) async {
    try {
      final recherche = (search ?? '').trim();
      var response = await _dio.get(
        "/clients",
        queryParameters: recherche.isEmpty ? null : {"search": recherche},
      );
      List<Client> clients = (response.data["data"] as List)
          .map((obj) => Client.fromJson(obj))
          .toList();
      return clients;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Client> addClient(Client client) async {
    // Meme cle au premier envoi et aux renvois : jamais de doublon.
    final cle = OperationEnAttente.nouvelId();
    try {
      final json = await client.toJson();
      print("add client data : ${json}");
      FormData formData = FormData.fromMap(json);
      var response = await _dio.post("/clients", data: formData, options: Options(headers: {'X-Idempotency-Key': cle}));
      Client clientRes = Client.fromJson(response.data["data"]);
      return clientRes;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        await _mettreEnFile(
          id: cle,
          type: "client",
          libelle: "Client — ${client.firstName ?? ''} ${client.lastName ?? ''}".trim(),
          chemin: "/clients",
          donnees: {
            "email": client.email,
            "firstName": client.firstName,
            "lastName": client.lastName,
            "firstNameAr": client.firstNameAr,
            "lastNameAr": client.lastNameAr,
            "identityNumber": client.identityNumber,
            "nationalite": client.nationalite,
            "tel": client.tel,
            "countryCode": client.countryCode,
            "documentsProvided[]": client.documentsProvided,
          },
          fichiers: {
            "documents[]":
                (client.documents ?? []).map((f) => f.path).toList(),
          },
        );
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Booking>> fetchBookings(
    String from,
    String to, {
    String? type,
    int? id,
  }) async {
    try {
      final params = cleanMap({
        "from": from,
        "to": to,
        "type": type,
        "realestate": id,
      });
      final response = await _dio.get("/bookings", queryParameters: params);
      List<Booking> bookings = (response.data["data"] as List)
          .map((e) => Booking.fromJson(e))
          .toList();
      return bookings;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Contract> addContract(Contract contract) async {
    try {
      final json = await contract.toJson();
      final formData = FormData.fromMap(json);
      var response = await _dio.post("/contracts", data: formData);
      Contract contractR = Contract.fromJson(response.data["data"]);
      return contractR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Contract>> getContracts(int realestate) async {
    try {
      var response = await _dio.get(
        "/contracts",
        queryParameters: {"realestate": realestate},
      );
      List<Contract> contracts = (response.data["data"] as List)
          .map((e) => Contract.fromJson(e))
          .toList();
      return contracts;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Charge> addCharge(Charge charge) async {
    // Meme cle au premier envoi et aux renvois : jamais de doublon.
    final cle = OperationEnAttente.nouvelId();
    try {
      final json = await charge.toJson();
      print("=======charge======$json");
      final form=FormData.fromMap(json);
      final response = await _dio.post("/charges", data: form, options: Options(headers: {'X-Idempotency-Key': cle}));
      Charge chargeR =  Charge.fromJson(response.data["data"]);
      return chargeR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        await _mettreEnFile(
          id: cle,
          type: "charge",
          libelle: "Charge — ${charge.nom ?? ''} (${charge.amount ?? 0} MAD)",
          chemin: "/charges",
          donnees: {
            "nom": charge.nom,
            "description": charge.description,
            "amount": charge.amount,
            "realestate": charge.realEstate?.id,
            if (charge.status != null) "status": charge.status,
          },
          fichiers: charge.document != null
              ? {"document": [charge.document!.path]}
              : const {},
        );
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Charge> validate(Charge charge) async {
    try {
      final json = await charge.toJson();
      final form=FormData.fromMap(json);
      final response = await _dio.post("/charges/${charge.id}/validate", data: form);
      Charge chargeR =  Charge.fromJson(response.data["data"]);
      return chargeR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Charge>> fetchCharges({String? status,String? type,String? from,String? to,Object? realestate})async{
    try {
      final response = await _dio.get(
        "/charges",
        queryParameters: {
          "from": from,
          "to": to,
          "type":type,
          "status":status,
          "realestate":realestate
        },
      );
      List<Charge> charges = (response.data["data"] as List)
          .map((e) => Charge.fromJson(e))
          .toList();
      return charges;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }


  Future<List<Charge>> getCharges(
    String from,
    String to,
      {int? realestate}
  ) async {
    try {
      final response = await _dio.get(
        "/charges",
        queryParameters: {
          if(realestate!=null)
          "realestate": realestate,
          "from": from,
          "to": to},
      );
      List<Charge> charges = (response.data["data"] as List)
          .map((e) => Charge.fromJson(e))
          .toList();
      return charges;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<RealestateStats> getRealestateStats(
    String from,
    String to,
    String groupBy,
    int realestate,
  ) async {
    try {
      var response = await _dio.get(
        "/stats",
        queryParameters: {
          "from": from,
          "to": to,
          "groupBy": groupBy,
          "realestate": realestate,
        },
      );
      RealestateStats realestateStats=RealestateStats.fromJson(response.data["data"]);
      return realestateStats;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Realestate>> getPendingAnnoces() async {
    try {
      var response=await _dio.get("/anounces");
      List<Realestate> realestates=(response.data["data"] as List).map((e)=>Realestate.fromJson(e)).toList();
      return realestates;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Realestate> acceptAnnounce(int id) async {
    try {
      var response=await _dio.patch("/anounces/${id}/accept");
      Realestate realestate=Realestate.fromJson(response.data["data"] );
      return realestate;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Realestate> refuseAnnounce(int id) async {
    try {
      var response=await _dio.patch("/anounces/${id}/refuse");
      Realestate realestate=Realestate.fromJson(response.data["data"] );
      return realestate;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }


  Future<List<SliderModel>> getSliders() async {
    try {
      var response=await _dio.get("/sliders");
      List<SliderModel> sliders=(response.data["data"] as List).map((e)=>SliderModel.fromJson(e)).toList();
      return sliders;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<SliderModel> activateSlider(int id) async {
    try {
      var response=await _dio.patch("/sliders/${id}/activate");
      SliderModel slider=SliderModel.fromJson(response.data["data"] );
      return slider;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<SliderModel> addSlider(SliderModel slider) async {
    try {
      final json=await slider.toJson();
      final formData=FormData.fromMap(json);
      var response=await _dio.post("/sliders",data: formData);
      SliderModel sliderR=SliderModel.fromJson(response.data["data"] );
      return sliderR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }


  Future<List<Manager>> fetchManagers() async {
    try {
      var response=await _dio.get("/managers",);
      List<Manager> managers=(response.data["data"] as List).map((e)=>Manager.fromJson(e)).toList();
      return managers;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Manager> addUser(Manager manager) async {
    try {
      var response=await _dio.post("/managers",data: manager.toJson());
      Manager managerR=Manager.fromJson(response.data["data"]);
      return managerR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }


  Future<GlobalStats> getGlobalStats(
      String from,
      String to,
      String groupBy,

      ) async {
    try {
      var response = await _dio.get(
        "/global-stats",
        queryParameters: {
          "from": from,
          "to": to,
          "groupBy": groupBy,
        },
      );
      GlobalStats realestateStats=GlobalStats.fromJson(response.data["data"]);
      return realestateStats;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }


  Future<AppVersion> getApplicationVersion(String packageName) async {
    try {
      var response = await _dioAppsVersion.get("/$packageName");
      AppVersion app=AppVersion.fromJson(response.data);
      return app;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Client> fetchClientDetails(int id) async {
    try {
      var response = await _dio.get("/clients/$id");
      Client client=Client.fromJson(response.data["data"]);
      return client;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Owner> fetchOwnerDetails(int id) async {
    try {
      var response = await _dio.get("/owners/$id");
      Owner owner=Owner.fromJson(response.data["data"]);
      return owner;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Rapport>> fetchRapports(int id) async {
    try {
      var response = await _dio.get("/rapports",queryParameters:{"realestate":id} );
      List<Rapport> rapports=(response.data["data"] as List).map((r)=>Rapport.fromJson(r)).toList();
      return rapports;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Rapport> addRapport(Rapport rapport) async {
    try {
      final json=await rapport.toJson();
      final form=FormData.fromMap(json);
      var response=await _dio.post("/rapports",data: form);
      Rapport rapportR=Rapport.fromJson(response.data["data"]);
      return rapportR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Realestate>> fetchRealestateByStatus(String status) async {
    try {
      var response=await _dio.get("/realestates-by-status",queryParameters: {"status":status});
      List<Realestate> realestates=(response.data["data"] as List).map((e)=>Realestate.fromJson(e)).toList();
      return realestates;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<ImmobilierOverview> fetchImmobilierOverview() async {
    try {
      var response=await _dio.get("/realestates-overview");
      ImmobilierOverview immobilierOverview=ImmobilierOverview.fromMap(response.data["data"]);
      return immobilierOverview;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<void> confirmDepart(int id) async {
    try {
      var response=await _dio.patch("/realestates/${id}/confirm-depart");
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<void> confirmCheckin(int id) async {
    try {
      var response=await _dio.patch("/realestates/${id}/confirm-checkin");
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  /// La femme de menage declare qu'elle commence le nettoyage.
  Future<void> startCleaning(int id) async {
    // Meme cle au premier envoi et aux renvois : jamais de doublon.
    final cle = OperationEnAttente.nouvelId();
    try {
      await _dio.patch("/realestates/$id/start-cleaning", options: Options(headers: {'X-Idempotency-Key': cle}));
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        await _mettreEnFile(
          id: cle,
          type: "cleaning_start",
          libelle: "Début de nettoyage — bien n° ${id}",
          methode: "PATCH",
          chemin: "/realestates/${id}/start-cleaning",
        );
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  /// Remet un appartement en nettoyage (menage juge insuffisant).
  Future<void> returnToCleaning(int id, {String? motif}) async {
    try {
      await _dio.patch(
        "/realestates/$id/return-to-cleaning",
        data: motif != null && motif.isNotEmpty ? {"motif": motif} : null,
      );
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  /// Telecharge l'export des statistiques (xlsx ou pdf) et renvoie le chemin local.
  Future<String> telechargerExportStatistiques({
    required String format,
    String? from,
    String? to,
    int? realestate,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final dossier = await getTemporaryDirectory();
      final horodatage = DateTime.now().millisecondsSinceEpoch;
      final chemin = "${dossier.path}/statistiques_$horodatage.$format";

      await _dio.download(
        "/statistiques/export",
        chemin,
        queryParameters: {
          "format": format,
          if (from != null) "from": from,
          if (to != null) "to": to,
          if (realestate != null) "realestate": realestate,
        },
        onReceiveProgress: onProgress,
      );
      return chemin;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  Future<void> finishCleaning(int id) async {
    // Meme cle au premier envoi et aux renvois : jamais de doublon.
    final cle = OperationEnAttente.nouvelId();
    try {
      var response=await _dio.patch("/realestates/${id}/finish-cleaning", options: Options(headers: {'X-Idempotency-Key': cle}));
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        await _mettreEnFile(
          id: cle,
          type: "cleaning_end",
          libelle: "Fin de nettoyage — bien n° ${id}",
          methode: "PATCH",
          chemin: "/realestates/${id}/finish-cleaning",
        );
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<String>> getRoles() async {
    try {
      var response=await _dio.get("/roles");
      List<String> roles=(response.data["data"] as List).map((s)=>s.toString()).toList();
      return roles;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  /// Prolonge un séjour. Le supplément entre en caisse côté serveur :
  /// il n'y a plus de montant à transmettre.
  Future<void> extendBooking(DateTime newCheckout, double price, int id) async {
    try {
      var response=await _dio.post("/bookings/${id}/extend",data: {
        "checkout":newCheckout.formattedDateEn,
        "price":price
      });
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<void> shrinkBooking(DateTime newCheckout,double price,int id) async {
    try {
      var response=await _dio.post("/bookings/${id}/shrink",data: {
        "checkout":newCheckout.formattedDateEn,
        "refundPrice":price
      });
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<void> deleteBooking(int id, {bool? rembourse, double? montantRembourse}) async {
    try {
      // La question du remboursement accompagne la suppression.
      await _dio.delete("/bookings/${id}", data: {
        if (rembourse != null) 'rembourse': rembourse,
        if (rembourse == true && montantRembourse != null) 'montantRembourse': montantRembourse,
      });
    } on DioException catch (ex) {
      if ((ex.response?.statusCode ?? 0) == 422) {
        throw Exception(messageServeur(ex, "La suppression a échoué."));
      }
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Manager> updateUser(Manager manager) async {
    try {
      final json=manager.toJson();
      json.removeWhere((key,val)=>val==null);
      var response=await _dio.put("/managers/${manager.id}",data: json);
      Manager managerR=Manager.fromJson(response.data["data"]);
      return managerR;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<void> deleteUser(Manager manager) async {
    try {
      var response=await _dio.delete("/managers/${manager.id}");
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Client> updateClient(Client client) async {
    try {
      final json = await client.toJson();
      json['_method'] = 'PUT';
      FormData formData = FormData.fromMap(json);
      var response = await _dio.post("/clients/${client.id}", data: formData);
      return Client.fromJson(response.data["data"]);
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
            ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      await _dio.delete("/clients/$id");
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<Manager> fetchManager(int id) async {
    try {
      var response=await _dio.get("/managers/${id}");
      Manager manager=Manager.fromJson(response.data["data"]);
      return manager;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<ProgramedCharge>> fetchProgramedCharges({int? realestate})async{
    try {
      var response=await _dio.get("/programed-charges",queryParameters: realestate!=null?{"realestate":realestate}:null);
      List<ProgramedCharge> programedCharges=(response.data['data'] as List).map((e)=>ProgramedCharge.fromJson(e)).toList();
      return programedCharges;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }


  Future<ProgramedCharge> addProgramedCharge(ProgramedCharge charge)async{
    try {
      var response=await _dio.post("/programed-charges",data: charge.toJson());
     ProgramedCharge programedCharge=ProgramedCharge.fromJson(response.data['data'] );
      return programedCharge;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }



  Future<ProgramedCharge> updateProgramedCharge(ProgramedCharge charge)async{
    try {
      var response=await _dio.put("/programed-charges",data: charge.toJson());
      ProgramedCharge programedCharge=ProgramedCharge.fromJson(response.data['data'] );
      return programedCharge;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<List<Reclamation>> getReclamations({int? realestateId}) async {
    try {
      var response = await _dio.get(
        '/reclamations',
        queryParameters: realestateId != null ? {'realestate': realestateId} : null,
      );
      return (response.data['data'] as List)
          .map((e) => Reclamation.fromJson(e))
          .toList();
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<Reclamation> createReclamation(Reclamation reclamation) async {
    // Meme cle au premier envoi et aux renvois : jamais de doublon.
    final cle = OperationEnAttente.nouvelId();
    try {
      final json = await reclamation.toJson();
      final formData = FormData.fromMap(json);
      var response = await _dio.post('/reclamations', data: formData, options: Options(headers: {'X-Idempotency-Key': cle}));
      return Reclamation.fromJson(response.data['data']);
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        await _mettreEnFile(
          id: cle,
          type: "reclamation",
          libelle: "Réclamation — ${reclamation.note ?? ''}",
          chemin: "/reclamations",
          donnees: {
            "note": reclamation.note,
            "realestate": reclamation.realestateId,
          },
          fichiers: {
            "images[]":
                (reclamation.files ?? []).map((f) => f.path).toList(),
          },
        );
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors = ex.response?.data['error'] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<Reclamation> resolveReclamation(int id) async {
    try {
      var response = await _dio.patch('/reclamations/$id/resolve');
      return Reclamation.fromJson(response.data['data']);
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<ProgramedCharge> fetchProgramedCharge(int id)async{
    try {
      var response=await _dio.get("/programed-charges/${id}",);
      ProgramedCharge programedCharge=ProgramedCharge.fromJson(response.data['data'] );
      return programedCharge;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) {
        throw UnAuthenticatedException();
      }
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      if ((ex.response?.statusCode ?? 0) == 422) {
        Map<String, dynamic> errors =
        ex.response?.data["error"] as Map<String, dynamic>;
        throw ValidatorException(errors);
      }
      rethrow;
    }
  }

  Future<FinancialStats> getFinancialStats({
    required String from,
    required String to,
    String groupBy = 'month',
    List<int> realestateIds = const [],
    String repartition = 'encaissement',
  }) async {
    try {
      final params = <String, dynamic>{
        'from': from,
        'to': to,
        'groupBy': groupBy,
        'repartition': repartition,
      };
      for (int i = 0; i < realestateIds.length; i++) {
        params['realestate[$i]'] = realestateIds[i];
      }
      final response = await _dio.get('/financial-stats', queryParameters: params);
      return FinancialStats.fromJson(response.data['data']);
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  /// Annule une charge. Le montant rendu, s'il y en a un, revient
  /// dans la caisse de celui qui annule.
  Future<void> annulerCharge(int id, {double? montant, String? motif}) async {
    try {
      await _dio.post('/charges/$id/cancel', data: FormData.fromMap({
        if (montant != null) 'montant': montant,
        if (motif != null && motif.isNotEmpty) 'motif': motif,
      }));
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      // Le serveur explique pourquoi il refuse : le message compte plus
      // qu'un code.
      final message = ex.response?.data is Map
          ? ex.response?.data["message"]?.toString()
          : null;
      if (message != null && message.isNotEmpty) throw Exception(message);
      rethrow;
    }
  }

  /// L'historique des charges annulees.
  /// Les reservations qui arrivent aujourd'hui ('today') ou les prochaines
  /// ('upcoming'), par date d'arrivee.
  Future<List<Booking>> fetchArrivees(String quand, {String? type, String? dossier}) async {
    final reponse = await _dio.get('/bookings/arrivees', queryParameters: {
      'quand': quand,
      if (type != null) 'type': type,
      if (dossier != null) 'dossier': dossier,
    });
    return ((reponse.data['data'] ?? []) as List).map((e) => Booking.fromJson(e)).toList();
  }

  /// Le resume de l'accueil : l'utilisateur, l'agence, sa caisse et les
  /// compteurs du jour. Une seule lecture pour toute la page d'accueil.
  Future<ResumeAccueil> resumeAccueil() async {
    try {
      final reponse = await _dio.get('/accueil/resume');
      return ResumeAccueil.depuis(reponse.data);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le résumé n'a pas pu être chargé."));
    }
  }

  /// Les trois familles de biens et leurs compteurs, pour l'ecran
  /// « Gestion Immobilier ».
  Future<CategoriesImmobilier> categoriesImmobilier() async {
    try {
      final reponse = await _dio.get('/dashboard/immobilier/categories');
      return CategoriesImmobilier.depuis(reponse.data);
    } on DioException catch (ex) {
      throw Exception(
          messageServeur(ex, "Les catégories n'ont pas pu être chargées."));
    }
  }

  /// L'apercu d'une famille de biens : ses compteurs, ses arrivees et ses
  /// departs du jour. [code] vaut rent-short, rent-long ou selle.
  Future<ApercuFamille> apercuFamille(String code) async {
    try {
      final reponse = await _dio.get('/dashboard/immobilier/famille/$code');
      return ApercuFamille.depuis(reponse.data);
    } on DioException catch (ex) {
      throw Exception(
          messageServeur(ex, "Cette famille n'a pas pu être chargée."));
    }
  }

  /// L'apercu d'un bien pour sa page de gestion : identite, etat du jour,
  /// sejour en cours, liaison Airbnb.
  Future<ApercuBien> apercuBien(int bienId) async {
    try {
      final reponse = await _dio.get('/dashboard/immobilier/bien/$bienId/apercu');
      return ApercuBien.depuis(reponse.data);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le bien n'a pas pu être chargé."));
    }
  }

  /// L'organisation de l'accueil enregistree pour l'utilisateur connecte.
  Future<Map<String, dynamic>?> lireDispositionAccueil() async {
    final reponse = await _dio.get('/accueil/disposition');
    final data = reponse.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> enregistrerDispositionAccueil(Map<String, dynamic> corps) async {
    await _dio.put('/accueil/disposition', data: corps);
  }

  /// Modules de l'accueil masqués ou renommés par l'utilisateur connecté.
  Future<List<ModuleAccueil>> lireModulesAccueil() async {
    try {
      final reponse = await _dio.get('/accueil/modules');
      return ModuleAccueil.listeDepuis(reponse.data);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Les modules de l'accueil n'ont pas pu être chargés."));
    }
  }

  /// Enregistre la liste complète des réglages ; rend celle du serveur.
  Future<List<ModuleAccueil>> enregistrerModulesAccueil(List<ModuleAccueil> modules) async {
    try {
      final reponse = await _dio.put('/accueil/modules', data: {
        'modules': modules.map((m) => m.toJson()).toList(),
      });
      return ModuleAccueil.listeDepuis(reponse.data);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Les modules de l'accueil n'ont pas pu être enregistrés."));
    }
  }

  /// Rend leur nom d'origine à tous les modules et les réaffiche.
  Future<void> reinitialiserModulesAccueil() async {
    try {
      await _dio.delete('/accueil/modules');
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "La réinitialisation n'a pas abouti."));
    }
  }

  /// Le fichier Excel ou PDF d'un tableau affiche par une page.
  /// Le message d'erreur que le serveur renvoie, lisible par l'utilisateur.
  static String messageServeur(DioException ex, String defaut) {
    final data = ex.response?.data;
    if (data is Map) {
      final erreurs = data['error'] ?? data['errors'];
      if (erreurs is Map && erreurs.isNotEmpty) {
        final premier = erreurs.values.first;
        if (premier is List && premier.isNotEmpty) return premier.first.toString();
        if (premier is String) return premier;
      }
      // Refus explique en une phrase (ex. dates reservees sur Airbnb).
      if (erreurs is String && erreurs.isNotEmpty) return erreurs;
      if (erreurs is List && erreurs.isNotEmpty) return erreurs.first.toString();
      final message = data['message'];
      if (message is String && message.isNotEmpty && message != 'OK') return message;
    }
    if (estCoupureReseau(ex)) {
      return "Pas de connexion. Vérifiez le réseau puis réessayez.";
    }
    return defaut;
  }

  /// Les dates bloquees a venir d'un bien.
  Future<List<Map<String, dynamic>>> fetchBlocages(int realestateId) async {
    try {
      final reponse = await _dio.get('/realestates/$realestateId/blocages');
      final liste = (reponse.data['data']?['blocages'] ?? []) as List;
      return liste.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Les dates bloquées n'ont pas pu être chargées."));
    }
  }

  Future<void> ajouterBlocage(int realestateId, {required String du, required String au, String? motif}) async {
    try {
      await _dio.post('/realestates/$realestateId/blocages', data: {
        'du': du,
        'au': au,
        if (motif != null) 'motif': motif,
      });
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le blocage n'a pas pu être enregistré."));
    }
  }

  Future<void> supprimerBlocage(int id) async {
    try {
      await _dio.delete('/blocages/$id');
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le déblocage a échoué."));
    }
  }

  /// Les clients deja enregistres qui ressemblent a celui qu'on saisit.
  Future<List<Map<String, dynamic>>> chercherDoublonsClient({String? tel, String? cin, String? prenom, String? nom}) async {
    final reponse = await _dio.get('/clients/doublons', queryParameters: {
      if ((tel ?? '').trim().isNotEmpty) 'tel': tel!.trim(),
      if ((cin ?? '').trim().isNotEmpty) 'cin': cin!.trim(),
      if ((prenom ?? '').trim().isNotEmpty) 'prenom': prenom!.trim(),
      if ((nom ?? '').trim().isNotEmpty) 'nom': nom!.trim(),
    });
    final liste = (reponse.data['data'] ?? []) as List;
    return liste.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Le numero et le message par defaut du syndic.
  Future<Map<String, dynamic>> reglagesSyndic({int? bookingId}) async {
    final reponse = await _dio.get('/reglages/syndic',
        queryParameters: {if (bookingId != null) 'booking': bookingId});
    return Map<String, dynamic>.from(reponse.data['data'] as Map);
  }

  /// Envoie le contrat public au syndic ; renvoie le numero utilise.
  Future<String> partagerContratSyndic(int bookingId,
      {required String telephone, required String message, bool enregistrer = false}) async {
    try {
      final reponse = await _dio.post('/bookings/$bookingId/partager-syndic', data: {
        'telephone': telephone,
        'message': message,
        'enregistrer': enregistrer,
      });
      return (reponse.data['data']?['envoyeA'] ?? telephone).toString();
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "L'envoi au syndic a échoué."));
    }
  }

  /// Ce qu'implique la suppression d'une réservation.
  Future<ApercuSuppression> apercuSuppression(int bookingId) async {
    try {
      final reponse = await _dio.get('/bookings/$bookingId/apercu-suppression');
      return ApercuSuppression.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Impossible de préparer la suppression."));
    }
  }

  /// Met un client sur liste noire : il ne peut plus réserver.
  Future<Client> ajouterListeNoire(int clientId, String motif) async {
    try {
      final reponse = await _dio.post('/clients/$clientId/liste-noire', data: {'motif': motif});
      return Client.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le client n'a pas pu être mis sur liste noire."));
    }
  }

  Future<Client> retirerListeNoire(int clientId) async {
    try {
      final reponse = await _dio.delete('/clients/$clientId/liste-noire');
      return Client.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le client n'a pas pu être retiré de la liste noire."));
    }
  }

  Future<List<Syndic>> fetchSyndics() async {
    try {
      final reponse = await _dio.get('/syndics');
      return ((reponse.data['data'] ?? []) as List)
          .map((e) => Syndic.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Les syndics n'ont pas pu être chargés."));
    }
  }

  Future<Syndic> fetchSyndic(int id) async {
    try {
      final reponse = await _dio.get('/syndics/$id');
      return Syndic.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le syndic n'a pas pu être chargé."));
    }
  }

  /// Les biens de l'agence, avec le syndic auquel chacun est rattaché.
  Future<List<BienDuSyndic>> fetchBiensPourSyndic() async {
    try {
      final reponse = await _dio.get('/syndics/biens');
      return ((reponse.data['data'] ?? []) as List)
          .map((e) => BienDuSyndic.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Les biens n'ont pas pu être chargés."));
    }
  }

  Future<Syndic> enregistrerSyndic({
    int? id,
    required String nom,
    required String telephone,
    bool actif = true,
    String? notes,
    required List<int> biens,
  }) async {
    final corps = {
      'nom': nom,
      'telephone': telephone,
      'actif': actif,
      'notes': notes,
      'biens': biens,
    };
    try {
      final reponse = id == null
          ? await _dio.post('/syndics', data: corps)
          : await _dio.put('/syndics/$id', data: corps);
      return Syndic.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le syndic n'a pas pu être enregistré."));
    }
  }

  Future<void> supprimerSyndic(int id) async {
    try {
      await _dio.delete('/syndics/$id');
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le syndic n'a pas pu être supprimé."));
    }
  }

  // ── Historique des envois aux syndics ─────────────────────────────

  Map<String, dynamic> _filtresEnvoisSyndics(
      {String? du, String? au, int? syndic, String? statut}) => {
        if (du != null) 'du': du,
        if (au != null) 'au': au,
        if (syndic != null) 'syndic': syndic,
        if (statut != null) 'statut': statut,
      };

  /// Le corps utile d'une reponse : « data » quand il existe, sinon la
  /// reponse elle-meme. Rend null si ce n'est pas un objet lisible.
  Map<String, dynamic>? _corpsEnvoisSyndics(dynamic brut) {
    final donnees = brut is Map && brut['data'] is Map ? brut['data'] : brut;
    if (donnees is! Map) return null;
    try {
      return Map<String, dynamic>.from(donnees);
    } catch (_) {
      return null;
    }
  }

  Future<HistoriqueEnvoisSyndic> fetchEnvoisSyndics(
      {String? du, String? au, int? syndic, String? statut}) async {
    try {
      final reponse = await _dio.get('/syndics/envois',
          queryParameters: _filtresEnvoisSyndics(du: du, au: au, syndic: syndic, statut: statut));
      final donnees = _corpsEnvoisSyndics(reponse.data);
      if (donnees == null) {
        throw Exception("La réponse du serveur n'a pas pu être lue.");
      }
      return HistoriqueEnvoisSyndic.fromJson(donnees);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "L'historique des envois n'a pas pu être chargé."));
    }
  }

  Future<EnvoiHistoriqueSyndic> fetchEnvoiSyndic(int id) async {
    try {
      final reponse = await _dio.get('/syndics/envois/$id');
      final donnees = _corpsEnvoisSyndics(reponse.data);
      if (donnees == null) {
        throw Exception("La réponse du serveur n'a pas pu être lue.");
      }
      return EnvoiHistoriqueSyndic.fromJson(donnees);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "L'envoi n'a pas pu être chargé."));
    }
  }

  /// Renvoie le meme contrat, avec le meme message, au meme numero.
  Future<EnvoiHistoriqueSyndic> renvoyerEnvoiSyndic(int id) async {
    try {
      final reponse = await _dio.post('/syndics/envois/$id/renvoyer');
      final donnees = _corpsEnvoisSyndics(reponse.data);
      if (donnees == null) {
        throw Exception("La réponse du serveur n'a pas pu être lue.");
      }
      return EnvoiHistoriqueSyndic.fromJson(donnees);
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le renvoi au syndic a échoué."));
    }
  }

  /// L'historique en PDF ou Excel, dans un fichier temporaire.
  Future<String> exporterEnvoisSyndics(
      {String? du, String? au, int? syndic, String? statut, required String format}) async {
    try {
      final reponse = await _dio.get<List<int>>(
        '/syndics/envois/export',
        queryParameters: {
          ..._filtresEnvoisSyndics(du: du, au: au, syndic: syndic, statut: statut),
          'format': format,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final dir = await getTemporaryDirectory();
      final horodate = DateTime.now().millisecondsSinceEpoch;
      final chemin = '${dir.path}${Platform.pathSeparator}envois_syndics_$horodate.$format';
      await File(chemin).writeAsBytes(reponse.data ?? const [], flush: true);
      return chemin;
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "L'export a échoué. Vérifiez la connexion puis réessayez."));
    }
  }

  /// Le contrat joint a un envoi, telecharge pour la visionneuse.
  Future<String> telechargerContratEnvoiSyndic(String url, int envoiId) async {
    try {
      final reponse = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final dir = await getTemporaryDirectory();
      final horodate = DateTime.now().millisecondsSinceEpoch;
      final chemin = '${dir.path}${Platform.pathSeparator}contrat_envoi_${envoiId}_$horodate.pdf';
      await File(chemin).writeAsBytes(reponse.data ?? const [], flush: true);
      return chemin;
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le contrat n'a pas pu être téléchargé."));
    }
  }

  /// Joint un contrat (PDF ou photo) à un propriétaire, pour un appartement.
  Future<ContratProprietaire> ajouterContratProprietaire(
    int ownerId,
    File fichier, {
    int? bienId,
    String? titre,
    String? dateDebut,
    String? dateFin,
  }) async {
    try {
      final nom = fichier.path.split(RegExp(r'[\\/]')).last;
      final formulaire = FormData.fromMap({
        'fichier': await MultipartFile.fromFile(fichier.path, filename: nom),
        if (bienId != null) 'bien': bienId,
        if ((titre ?? '').trim().isNotEmpty) 'titre': titre!.trim(),
        if (dateDebut != null) 'dateDebut': dateDebut,
        if (dateFin != null) 'dateFin': dateFin,
      });
      final reponse = await _dio.post('/owners/$ownerId/contrats', data: formulaire);
      return ContratProprietaire.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le contrat n'a pas pu être joint."));
    }
  }

  Future<void> supprimerContratProprietaire(int id) async {
    try {
      await _dio.delete('/contrats-proprietaires/$id');
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le contrat n'a pas pu être supprimé."));
    }
  }

  // ── Airbnb (liens de calendrier iCal) ─────────────────────────────

  Exception _erreurAirbnb(DioException ex, String defaut) {
    if (estCoupureReseau(ex)) return NetworkConnectivityException();
    final code = ex.response?.statusCode ?? 0;
    if (code == 401) return UnAuthenticatedException();
    if (code == 403) return UnAuthorizedException();
    return Exception(messageServeur(ex, defaut));
  }

  LienAirbnb _lienAirbnb(dynamic data) {
    final corps = data is Map && data['data'] is Map ? data['data'] : data;
    return LienAirbnb.fromJson(Map<String, dynamic>.from(corps as Map));
  }

  Future<LienAirbnb> fetchAirbnb(int bienId) async {
    try {
      final reponse = await _dio.get('/realestates/$bienId/airbnb');
      return _lienAirbnb(reponse.data);
    } on DioException catch (ex) {
      throw _erreurAirbnb(ex, "La liaison Airbnb n'a pas pu être chargée.");
    }
  }

  /// Lien vide : le bien n'est plus relie. Le serveur importe aussitot.
  Future<LienAirbnb> enregistrerLienAirbnb(int bienId, String urlImport) async {
    try {
      final reponse = await _dio.put('/realestates/$bienId/airbnb', data: {'urlImport': urlImport});
      return _lienAirbnb(reponse.data);
    } on DioException catch (ex) {
      throw _erreurAirbnb(ex, "Le lien Airbnb n'a pas pu être enregistré.");
    }
  }

  Future<LienAirbnb> synchroniserAirbnb(int bienId) async {
    try {
      final reponse = await _dio.post('/realestates/$bienId/airbnb/synchroniser');
      return _lienAirbnb(reponse.data);
    } on DioException catch (ex) {
      throw _erreurAirbnb(ex, "La synchronisation avec Airbnb a échoué.");
    }
  }

  /// Nouveau lien d'export : l'ancien cesse de fonctionner.
  Future<LienAirbnb> nouveauLienExportAirbnb(int bienId) async {
    try {
      final reponse = await _dio.post('/realestates/$bienId/airbnb/nouveau-lien');
      return _lienAirbnb(reponse.data);
    } on DioException catch (ex) {
      throw _erreurAirbnb(ex, "Le nouveau lien n'a pas pu être généré.");
    }
  }

  /// Tous les biens, relies a Airbnb ou non.
  Future<List<BienAirbnb>> fetchBiensAirbnb() async {
    try {
      final reponse = await _dio.get('/airbnb/biens');
      final data = reponse.data;
      final liste = (data is Map ? data['data'] : data) as List? ?? const [];
      return liste.map((e) => BienAirbnb.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } on DioException catch (ex) {
      throw _erreurAirbnb(ex, "La liste des biens Airbnb n'a pas pu être chargée.");
    }
  }

  /// Reservations Airbnb a venir et des 30 derniers jours, tous biens
  /// ou un seul ([bienId]).
  Future<List<SejourAirbnb>> fetchSejoursAirbnb({int? bienId}) async {
    try {
      final reponse = await _dio.get('/airbnb/sejours',
          queryParameters: bienId == null ? null : {'bien': bienId});
      final data = reponse.data;
      final liste = (data is Map ? data['data'] : data) as List? ?? const [];
      return liste
          .whereType<Map>()
          .map((e) => SejourAirbnb.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurAirbnb(ex, "Les réservations Airbnb n'ont pas pu être chargées.");
    }
  }

  /// Le calendrier de gestion d'un bien entre deux dates (incluses).
  Future<CalendrierBien> fetchCalendrier(int bienId, {required DateTime du, required DateTime au}) async {
    try {
      final reponse = await _dio.get('/realestates/$bienId/calendrier',
          queryParameters: {'du': _jourIso(du), 'au': _jourIso(au)});
      return CalendrierBien.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le calendrier n'a pas pu être chargé."));
    }
  }

  /// Fixe le prix des nuits du..au (incluses).
  Future<void> definirPrixNuits(int bienId, {required DateTime du, required DateTime au, required double prix}) async {
    try {
      await _dio.post('/realestates/$bienId/prix',
          data: {'du': _jourIso(du), 'au': _jourIso(au), 'prix': prix});
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le prix n'a pas pu être enregistré."));
    }
  }

  /// Revient au prix habituel pour les nuits du..au (incluses).
  Future<void> effacerPrixNuits(int bienId, {required DateTime du, required DateTime au}) async {
    try {
      await _dio.delete('/realestates/$bienId/prix',
          data: {'du': _jourIso(du), 'au': _jourIso(au)});
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le prix habituel n'a pas pu être rétabli."));
    }
  }

  /// Prix d'un sejour (arrivee, depart non compris).
  Future<TarifSejour> tarifSejour(int bienId, {required DateTime arrivee, required DateTime depart}) async {
    try {
      final reponse = await _dio.get('/realestates/$bienId/tarif',
          queryParameters: {'du': _jourIso(arrivee), 'au': _jourIso(depart)});
      return TarifSejour.fromJson(Map<String, dynamic>.from(reponse.data['data'] as Map));
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le prix du séjour n'a pas pu être calculé."));
    }
  }

  /// Rend reservables les nuits du..au (incluses), meme au milieu d'un blocage.
  Future<void> debloquerPeriode(int bienId, {required DateTime du, required DateTime au}) async {
    try {
      await _dio.post('/realestates/$bienId/debloquer',
          data: {'du': _jourIso(du), 'au': _jourIso(au)});
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Les dates n'ont pas pu être débloquées."));
    }
  }

  /// Nouvelles dates et nouveau prix par nuit d'une reservation.
  /// Renvoie l'ecart avec l'ancien montant (positif : le client doit plus).
  Future<double> modifierReservation(int reservationId,
      {required DateTime arrivee, required DateTime depart, required double prixNuit}) async {
    try {
      final reponse = await _dio.post('/bookings/$reservationId/modifier', data: {
        'checkin': _jourIso(arrivee),
        'checkout': _jourIso(depart),
        'prixNuit': prixNuit,
      });
      return ((reponse.data['data'] as Map)['ecart'] as num?)?.toDouble() ?? 0;
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "La réservation n'a pas pu être modifiée."));
    }
  }

  Future<Uint8List> exporterTableau(Map<String, dynamic> corps) async {
    final reponse = await _dio.post(
      '/export',
      data: corps,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return Uint8List.fromList(List<int>.from(reponse.data as List));
  }

  Future<List<ChargeAnnulee>> chargesAnnulees() async {
    try {
      final reponse = await _dio.get('/charges/annulees');
      return ((reponse.data["data"]?["charges"] ?? []) as List)
          .map((e) => ChargeAnnulee.fromJson(e))
          .toList();
    } on DioException catch (ex) {
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<void> deleteCharge(int id) async {
    try {
      await _dio.delete('/charges/$id');
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) throw NetworkConnectivityException();
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<void> deleteOwner(int id) async {
    try {
      await _dio.delete('/owners/$id');
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) throw NetworkConnectivityException();
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<void> deleteProgramedCharge(int id) async {
    try {
      await _dio.delete('/programed-charges/$id');
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) throw NetworkConnectivityException();
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  Future<void> deleteRealestate(int id) async {
    try {
      await _dio.delete('/realestates/$id');
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) throw NetworkConnectivityException();
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  /// Telecharge la liste des reservations, par bien ou par client.
  ///
  /// Les deux selections sont cumulables ; vides, elles laissent le
  /// serveur decider de ce que l'agent a le droit de voir.
  // ─── Caisses ──────────────────────────────────────────────────────

  Future<MaCaisse> maCaisse() async {
    try {
      final reponse = await _dio.get("/caisses/ma-caisse");
      return MaCaisse.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  /// Reserve a l'administrateur : un agent recoit un refus, qui n'est
  /// pas une panne mais une reponse.
  /// L'écriture arabe déjà enregistrée par l'agence pour ce prénom et ce
  /// nom. Sans réponse (hors connexion, serveur lent), rien : la
  /// transcription se fait alors sur le téléphone seul.
  Future<(MemoireNom?, MemoireNom?)> nomsArabes(String? prenom, String? nom) async {
    try {
      final reponse = await _dio.get(
        "/noms-arabes",
        queryParameters: {"prenom": prenom ?? "", "nom": nom ?? ""},
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final data = reponse.data["data"];
      if (data is! Map) return (null, null);
      return (
        MemoireNom.depuisJson(data["prenom"]),
        MemoireNom.depuisJson(data["nom"]),
      );
    } catch (_) {
      return (null, null);
    }
  }

  Future<VueCaisses> toutesLesCaisses() async {
    try {
      final reponse = await _dio.get("/caisses");
      return VueCaisses.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  /// Ouvre une nouvelle caisse. Sans montant, le solde compté à la
  /// clôture précédente est reporté.
  Future<void> ouvrirCaisse({double? montant, bool reporter = false}) async {
    try {
      await _dio.post("/caisses/ouvrir", data: {
        if (montant != null) "montant": montant,
        if (reporter) "reporter": true,
      });
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  /// Les caisses vers lesquelles on peut transférer.
  /// Les réservations supprimées dans la semaine.
  Future<List<ReservationSupprimee>> corbeilleReservations() async {
    try {
      final reponse = await _dio.get("/bookings/corbeille");
      return ((reponse.data["data"]?["reservations"] ?? []) as List)
          .map((e) => ReservationSupprimee.fromJson(e))
          .toList();
    } on DioException catch (ex) {
      if ((ex.response?.statusCode ?? 0) == 403) {
        throw UnAuthorizedException();
      }
      rethrow;
    }
  }

  /// Sort une réservation de la corbeille. Aucun message n'est envoyé.
  Future<void> restaurerReservation(int id) async {
    await _dio.post("/bookings/$id/restaurer");
  }

  Future<List<CaisseDestinataire>> destinatairesCaisse() async {
    try {
      final reponse = await _dio.get("/caisses/destinataires");
      return ((reponse.data["data"]?["caisses"] ?? []) as List)
          .map((e) => CaisseDestinataire.fromJson(e))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  /// Un transfert vers une autre caisse, photo jointe si elle existe.
  ///
  /// Sans caisse indiquée, l'argent va à celle de l'agence.
  Future<void> declarerRemise(
    double montant,
    String? commentaire, {
    int? caisse,
    File? piece,
  }) async {
    try {
      // La photo voyage en pièce jointe : la requête devient alors un
      // formulaire, comme pour les documents d'une charge.
      final champs = <String, dynamic>{
        "montant": montant,
        if (commentaire != null) "commentaire": commentaire,
        if (caisse != null) "caisse": caisse,
        if (piece != null)
          "piece": await MultipartFile.fromFile(piece.path,
              filename: piece.path.split(Platform.pathSeparator).last),
      };

      await _dio.post(
        "/caisses/remises",
        data: piece == null ? champs : FormData.fromMap(champs),
      );
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  Future<void> confirmerRemise(
      int id, double montantRecu, String? commentaire) async {
    try {
      await _dio.post("/caisses/remises/$id/confirmer", data: {
        "montantRecu": montantRecu,
        if (commentaire != null) "commentaire": commentaire,
      });
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  /// Le journal d'une caisse donnée. Réservé à l'administrateur.
  Future<MaCaisse> mouvementsDeLaCaisse(int id) async {
    try {
      final reponse = await _dio.get("/caisses/$id/mouvements");
      return MaCaisse.fromJson(reponse.data["data"]);
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  Future<Cloturage> cloturerCaisse(double montantCompte, String? commentaire) async {
    try {
      final reponse = await _dio.post("/caisses/cloturer", data: {
        "montantCompte": montantCompte,
        if (commentaire != null) "commentaire": commentaire,
      });
      final d = reponse.data["data"];
      return Cloturage(
        id: d["id"] ?? 0,
        caisse: "",
        montantDepart: (d["montantDepart"] as num?)?.toDouble() ?? 0,
        totalEntrees: (d["totalEntrees"] as num?)?.toDouble() ?? 0,
        totalSorties: (d["totalSorties"] as num?)?.toDouble() ?? 0,
        totalRemis: (d["totalRemis"] as num?)?.toDouble() ?? 0,
        soldeTheorique: (d["soldeTheorique"] as num?)?.toDouble() ?? 0,
        montantCompte: (d["montantCompte"] as num?)?.toDouble() ?? 0,
        ecart: (d["ecart"] as num?)?.toDouble() ?? 0,
        juste: ((d["ecart"] as num?)?.toDouble() ?? 0).abs() < 0.005,
      );
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  Future<List<Cloturage>> cloturages({int? caisse}) async {
    try {
      final reponse = await _dio.get("/caisses/cloturages",
          queryParameters: {if (caisse != null) "caisse": caisse});
      return (reponse.data["data"] as List)
          .map((e) => Cloturage.fromJson(e))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  /// Les caisses successives d'un detenteur, chacune avec son journal.
  Future<List<SessionCaisse>> sessionsCaisse({int? caisse}) async {
    try {
      final reponse = await _dio.get("/caisses/sessions",
          queryParameters: {if (caisse != null) "caisse": caisse});
      return ((reponse.data["data"]["sessions"] as List?) ?? const [])
          .map((e) => SessionCaisse.fromJson(e))
          .toList();
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  Future<void> viderCaisse(int id, String motif) async {
    try {
      await _dio.post("/caisses/$id/vider", data: {"motif": motif});
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  Future<void> mouvementCaisse({
    required String sens,
    required double montant,
    required String motif,
    String? commentaire,
  }) async {
    try {
      await _dio.post("/caisses/mouvements", data: {
        "sens": sens,
        "montant": montant,
        "motif": motif,
        if (commentaire != null) "commentaire": commentaire,
      });
    } on DioException catch (ex) {
      throw _erreurCaisse(ex);
    }
  }

  // ─── Caisse Airbnb (administrateur) ──────────────────────────────

  /// La caisse qui reçoit le montant des séjours payés sur Airbnb.
  /// [depuis] (Y-m-d) borne l'historique ; par défaut, 3 derniers mois.
  Future<CaisseAirbnb> caisseAirbnb({String? depuis}) async {
    try {
      final reponse = await _dio.get("/caisse-airbnb",
          queryParameters: {if (depuis != null) "depuis": depuis});
      final data = reponse.data is Map ? reponse.data["data"] : null;
      return CaisseAirbnb.fromJson(
          data is Map ? Map<String, dynamic>.from(data) : const {});
    } on DioException catch (ex) {
      throw Exception(
          messageServeur(ex, "La caisse Airbnb n'a pas pu être chargée."));
    }
  }

  /// Transfère une somme de la caisse Airbnb vers une autre caisse.
  Future<CaisseAirbnb> transfererCaisseAirbnb({
    required int caisse,
    required double montant,
    String? commentaire,
  }) async {
    try {
      final reponse = await _dio.post("/caisse-airbnb/transferer", data: {
        "caisse": caisse,
        "montant": montant,
        if (commentaire != null && commentaire.isNotEmpty)
          "commentaire": commentaire,
      });
      final data = reponse.data is Map ? reponse.data["data"] : null;
      return CaisseAirbnb.fromJson(
          data is Map ? Map<String, dynamic>.from(data) : const {});
    } on DioException catch (ex) {
      throw Exception(messageServeur(ex, "Le transfert n'a pas abouti."));
    }
  }

  /// Le serveur explique pourquoi il refuse - caisse deja ouverte,
  /// remise superieure au solde, droit manquant. On remonte sa phrase
  /// plutot qu'un message generique.
  Exception _erreurCaisse(DioException ex) {
    if (estCoupureReseau(ex)) {
      return NetworkConnectivityException();
    }
    if ((ex.response?.statusCode ?? 0) == 401) return UnAuthenticatedException();

    final message = ex.response?.data is Map
        ? ex.response?.data["message"]
        : null;

    if (message is String && message.isNotEmpty) {
      return Exception(message);
    }
    if ((ex.response?.statusCode ?? 0) == 403) return UnAuthorizedException();

    return Exception("L'opération n'a pas abouti.");
  }

  Future<String> exportReservations({
    required String format,
    List<int> realestateIds = const [],
    List<int> clientIds = const [],
    DateTime? du,
    DateTime? au,
  }) async {
    try {
      final params = <String, dynamic>{"format": format};
      for (int i = 0; i < realestateIds.length; i++) {
        params["realestates[$i]"] = realestateIds[i];
      }
      for (int i = 0; i < clientIds.length; i++) {
        params["clients[$i]"] = clientIds[i];
      }
      if (du != null) params["du"] = _jourIso(du);
      if (au != null) params["au"] = _jourIso(au);

      final dir = await getTemporaryDirectory();
      final horodate = DateTime.now().millisecondsSinceEpoch;
      final chemin = "${dir.path}/reservations_$horodate.$format";

      await _dio.download("/reservations/export", chemin,
          queryParameters: params);
      return chemin;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  static String _jourIso(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  /// Le rapport des statistiques (PDF ou Excel) sur une periode, fabrique
  /// par le serveur. Rend le chemin du fichier telecharge.
  Future<String> telechargerRapportStatistiques({
    required DateTime du,
    required DateTime au,
    List<int> biens = const [],
    required String repartition,
    required bool detail,
    required String format,
  }) async {
    final debut = du.formattedDateEn;
    final fin = au.formattedDateEn;
    try {
      final params = <String, dynamic>{
        'from': debut,
        'to': fin,
        'repartition': repartition,
        'detail': detail ? 1 : 0,
        'format': format,
      };
      for (int i = 0; i < biens.length; i++) {
        params['realestate[$i]'] = biens[i];
      }
      final reponse = await _dio.get<List<int>>(
        '/financial-stats/rapport',
        queryParameters: params,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/rapport_statistiques_${debut}_$fin.$format';
      await File(filePath).writeAsBytes(reponse.data ?? const [], flush: true);
      return filePath;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      // L'erreur arrive en octets : on la relit en JSON pour son message.
      final brut = ex.response?.data;
      if (ex.response != null && brut is List<int>) {
        try {
          ex.response!.data = jsonDecode(utf8.decode(brut));
        } catch (_) {}
      }
      throw Exception(messageServeur(ex, "Le rapport n'a pas pu être préparé."));
    }
  }

  Future<String> exportFinancialStats({
    required String from,
    required String to,
    List<int> realestateIds = const [],
  }) async {
    try {
      final params = <String, dynamic>{'from': from, 'to': to};
      for (int i = 0; i < realestateIds.length; i++) {
        params['realestate[$i]'] = realestateIds[i];
      }
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/comparatif_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      await _dio.download('/financial-stats/export', filePath, queryParameters: params);
      return filePath;
    } on DioException catch (ex) {
      if (estCoupureReseau(ex)) {
        throw NetworkConnectivityException();
      }
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      if ((ex.response?.statusCode ?? 0) == 403) throw UnAuthorizedException();
      rethrow;
    }
  }

  // ─── Location longue duree ────────────────────────────────────────

  /// Les erreurs des baux : coupure et session comme ailleurs, puis la
  /// phrase du serveur (compte de demonstration en lecture seule compris).
  Exception _erreurBail(DioException ex, String defaut) {
    if (estCoupureReseau(ex)) return NetworkConnectivityException();
    final code = ex.response?.statusCode ?? 0;
    if (code == 401) return UnAuthenticatedException();
    // Un PDF refuse arrive en octets : on le relit en JSON pour son message.
    final brut = ex.response?.data;
    if (ex.response != null && brut is List<int>) {
      try {
        ex.response!.data = jsonDecode(utf8.decode(brut));
      } catch (_) {}
    }
    if (code == 403) {
      final message = messageServeur(ex, '');
      return message.isEmpty ? UnAuthorizedException() : Exception(message);
    }
    return Exception(messageServeur(ex, defaut));
  }

  Map<String, dynamic> _donneesBail(Response reponse) =>
      Map<String, dynamic>.from(reponse.data['data'] as Map);

  String? _avertissement(Response reponse) {
    final data = reponse.data;
    final brut = data is Map
        ? (data['avertissement'] ?? (data['data'] is Map ? data['data']['avertissement'] : null))
        : null;
    final texte = brut?.toString().trim();
    return (texte == null || texte.isEmpty) ? null : texte;
  }

  Future<List<Bail>> fetchBaux({
    String statut = 'actif',
    String? recherche,
    int? bien,
    int? client,
    bool impayes = false,
  }) async {
    try {
      final reponse = await _dio.get('/baux', queryParameters: {
        'statut': statut,
        if ((recherche ?? '').trim().isNotEmpty) 'q': recherche!.trim(),
        if (bien != null) 'realestate': bien,
        if (client != null) 'client': client,
        if (impayes) 'impayes': 1,
      });
      return ((reponse.data['data'] ?? []) as List)
          .map((e) => Bail.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Les baux n'ont pas pu être chargés.");
    }
  }

  Future<TableauBaux> fetchTableauBaux() async {
    try {
      final reponse = await _dio.get('/baux/tableau');
      return TableauBaux.fromJson(_donneesBail(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le tableau de bord n'a pas pu être chargé.");
    }
  }

  Future<List<BienLongueDuree>> fetchBiensLongueDuree() async {
    try {
      final reponse = await _dio.get('/baux/biens');
      return ((reponse.data['data'] ?? []) as List)
          .map((e) => BienLongueDuree.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Les logements n'ont pas pu être chargés.");
    }
  }

  Future<Bail> fetchBail(int id) async {
    try {
      final reponse = await _dio.get('/baux/$id');
      return Bail.fromJson(_donneesBail(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le bail n'a pas pu être chargé.");
    }
  }

  /// Ajoute des fichiers a un formulaire sous un meme nom de champ.
  Future<void> _joindreFichiers(FormData formulaire, String champ, List<File> fichiers) async {
    for (final f in fichiers) {
      formulaire.files.add(MapEntry(
        champ,
        await MultipartFile.fromFile(f.path, filename: f.path.split(RegExp(r'[\\/]')).last),
      ));
    }
  }

  /// Les occupants a plat, pour un envoi multipart : colocataires[0][nom]...
  void _joindreColocataires(FormData formulaire, List<Colocataire> colocataires) {
    var i = 0;
    for (final c in colocataires) {
      if (c.nom.trim().isEmpty) continue;
      c.toJson().forEach((cle, valeur) => formulaire.fields.add(MapEntry('colocataires[$i][$cle]', valeur)));
      i++;
    }
  }

  List<Map<String, String>> _colocatairesJson(List<Colocataire> colocataires) =>
      colocataires.where((c) => c.nom.trim().isNotEmpty).map((c) => c.toJson()).toList();

  Future<AvecAvertissement<Bail>> creerBail({
    required int bien,
    required int client,
    required DateTime dateDebut,
    DateTime? dateFin,
    int? dureeMois,
    required double loyer,
    double? charges,
    double? depot,
    bool depotRecu = false,
    String? compteurEauEntree,
    String? compteurElecEntree,
    String? remarques,
    bool relancesActives = true,
    bool envoyerContrat = false,
    List<File> photos = const [],
    List<Colocataire> colocataires = const [],
    List<File> cinPhotos = const [],
  }) async {
    try {
      final champs = <String, dynamic>{
        'realestate': bien,
        'client': client,
        'dateDebut': _jourIso(dateDebut),
        // Le serveur calcule la duree depuis la date de fin.
        if (dateFin != null) 'dateFin': _jourIso(dateFin) else 'dureeMois': dureeMois,
        'loyer': loyer,
        if (charges != null) 'charges': charges,
        if (depot != null) 'depot': depot,
        'depotRecu': depotRecu ? 1 : 0,
        if ((compteurEauEntree ?? '').trim().isNotEmpty) 'compteurEauEntree': compteurEauEntree!.trim(),
        if ((compteurElecEntree ?? '').trim().isNotEmpty) 'compteurElecEntree': compteurElecEntree!.trim(),
        if ((remarques ?? '').trim().isNotEmpty) 'remarques': remarques!.trim(),
        'relancesActives': relancesActives ? 1 : 0,
        'envoyerContrat': envoyerContrat ? 1 : 0,
      };
      final occupants = _colocatairesJson(colocataires);
      Object corps = {...champs, if (occupants.isNotEmpty) 'colocataires': occupants};
      if (photos.isNotEmpty || cinPhotos.isNotEmpty) {
        final formulaire = FormData.fromMap(champs);
        _joindreColocataires(formulaire, colocataires);
        await _joindreFichiers(formulaire, 'photos[]', photos);
        await _joindreFichiers(formulaire, 'cinPhotos[]', cinPhotos);
        corps = formulaire;
      }
      final reponse = await _dio.post('/baux', data: corps);
      return AvecAvertissement(Bail.fromJson(_donneesBail(reponse)), _avertissement(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le bail n'a pas pu être créé.");
    }
  }

  Future<Bail> modifierBail(
    int id, {
    String? remarques,
    bool? relancesActives,
    String? compteurEauEntree,
    String? compteurElecEntree,
    double? loyer,
    double? charges,
    bool depotRecu = false,
    List<Colocataire>? colocataires,
    List<File> cinPhotos = const [],
  }) async {
    try {
      final champs = <String, dynamic>{
        if (remarques != null) 'remarques': remarques.trim(),
        if (relancesActives != null) 'relancesActives': relancesActives ? 1 : 0,
        if (compteurEauEntree != null) 'compteurEauEntree': compteurEauEntree.trim(),
        if (compteurElecEntree != null) 'compteurElecEntree': compteurElecEntree.trim(),
        if (loyer != null) 'loyer': loyer,
        if (charges != null) 'charges': charges,
        if (depotRecu) 'depotRecu': 1,
        // Une liste vide retire tous les occupants.
        if (colocataires != null) 'colocataires': _colocatairesJson(colocataires),
      };
      Response? reponse;
      if (champs.isNotEmpty || cinPhotos.isEmpty) {
        reponse = await _dio.put('/baux/$id', data: champs);
      }
      // Les photos passent en multipart : POST avec _method=PUT, lu par Laravel.
      if (cinPhotos.isNotEmpty) {
        final formulaire = FormData.fromMap({'_method': 'PUT'});
        await _joindreFichiers(formulaire, 'cinPhotos[]', cinPhotos);
        reponse = await _dio.post('/baux/$id', data: formulaire);
      }
      return Bail.fromJson(_donneesBail(reponse!));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le bail n'a pas pu être modifié.");
    }
  }

  Future<AvecAvertissement<Bail>> prolongerBail(int id,
      {required int mois, double? loyer, bool envoyerContrat = false}) async {
    try {
      final reponse = await _dio.post('/baux/$id/prolonger', data: {
        'mois': mois,
        if (loyer != null) 'loyer': loyer,
        'envoyerContrat': envoyerContrat ? 1 : 0,
      });
      return AvecAvertissement(Bail.fromJson(_donneesBail(reponse)), _avertissement(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le bail n'a pas pu être prolongé.");
    }
  }

  Future<Bail> terminerBail(
    int id, {
    required DateTime dateSortie,
    String? motif,
    double? depotRendu,
    String? compteurEauSortie,
    String? compteurElecSortie,
  }) async {
    try {
      final reponse = await _dio.post('/baux/$id/terminer', data: {
        'dateSortie': _jourIso(dateSortie),
        if ((motif ?? '').trim().isNotEmpty) 'motif': motif!.trim(),
        if (depotRendu != null) 'depotRendu': depotRendu,
        if ((compteurEauSortie ?? '').trim().isNotEmpty) 'compteurEauSortie': compteurEauSortie!.trim(),
        if ((compteurElecSortie ?? '').trim().isNotEmpty) 'compteurElecSortie': compteurElecSortie!.trim(),
      });
      return Bail.fromJson(_donneesBail(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le bail n'a pas pu être terminé.");
    }
  }

  Future<void> supprimerBail(int id) async {
    try {
      await _dio.delete('/baux/$id');
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le bail n'a pas pu être supprimé.");
    }
  }

  /// Telecharge un PDF du serveur dans le dossier temporaire ; rend son chemin.
  Future<String> _pdfBail(String chemin, String fichier, String defaut) async {
    try {
      final reponse = await _dio.get<List<int>>(
        chemin,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final dir = await getTemporaryDirectory();
      final horodate = DateTime.now().millisecondsSinceEpoch;
      final destination = '${dir.path}${Platform.pathSeparator}${fichier}_$horodate.pdf';
      await File(destination).writeAsBytes(reponse.data ?? const [], flush: true);
      return destination;
    } on DioException catch (ex) {
      throw _erreurBail(ex, defaut);
    }
  }

  Future<String> telechargerContratBail(int id) =>
      _pdfBail('/baux/$id/contrat', 'bail_$id', "Le contrat n'a pas pu être préparé.");

  Future<String?> envoyerContratBail(int id) async {
    try {
      final reponse = await _dio.post('/baux/$id/envoyer-contrat');
      final data = reponse.data['data'];
      return data is Map ? data['contratUrl']?.toString() : null;
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le contrat n'a pas pu être envoyé.");
    }
  }

  Future<Loyer> modifierMontantLoyer(int id, double montant) async {
    try {
      final reponse = await _dio.put('/loyers/$id', data: {'montant': montant});
      return Loyer.fromJson(_donneesBail(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le montant n'a pas pu être modifié.");
    }
  }

  Future<PaiementEnregistre> encaisserLoyer(
    int loyerId, {
    required double montant,
    DateTime? payeLe,
    String mode = 'especes',
    String? reference,
    String? remarque,
    bool envoyerQuittance = true,
  }) async {
    try {
      final reponse = await _dio.post('/loyers/$loyerId/paiements', data: {
        'montant': montant,
        if (payeLe != null) 'payeLe': _jourIso(payeLe),
        'mode': mode,
        if ((reference ?? '').trim().isNotEmpty) 'reference': reference!.trim(),
        if ((remarque ?? '').trim().isNotEmpty) 'remarque': remarque!.trim(),
        'envoyerQuittance': envoyerQuittance ? 1 : 0,
      });
      final data = _donneesBail(reponse);
      return PaiementEnregistre(
        loyer: Loyer.fromJson(Map<String, dynamic>.from(data['loyer'] as Map)),
        paiement: PaiementLoyer.fromJson(Map<String, dynamic>.from(data['paiement'] as Map)),
        avertissement: _avertissement(reponse),
      );
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le paiement n'a pas pu être enregistré.");
    }
  }

  Future<Loyer> annulerPaiementLoyer(int paiementId, {String? motif}) async {
    try {
      final reponse = await _dio.delete('/loyer-paiements/$paiementId', data: {
        if ((motif ?? '').trim().isNotEmpty) 'motif': motif!.trim(),
      });
      return Loyer.fromJson(_donneesBail(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le paiement n'a pas pu être annulé.");
    }
  }

  Future<String> telechargerQuittance(int paiementId) => _pdfBail('/loyer-paiements/$paiementId/quittance',
      'quittance_$paiementId', "La quittance n'a pas pu être préparée.");

  Future<String?> envoyerQuittance(int paiementId) async {
    try {
      final reponse = await _dio.post('/loyer-paiements/$paiementId/envoyer-quittance');
      final data = reponse.data['data'];
      return data is Map ? data['quittanceUrl']?.toString() : null;
    } on DioException catch (ex) {
      throw _erreurBail(ex, "La quittance n'a pas pu être envoyée.");
    }
  }

  // ─── Vente de biens ───────────────────────────────────────────────

  /// Le corps utile d'une reponse : data, ou la reponse elle-meme.
  Map<String, dynamic> _donneesVente(Response reponse) {
    final data = reponse.data;
    final corps = data is Map && data['data'] is Map ? data['data'] : data;
    return Map<String, dynamic>.from(corps as Map);
  }

  List<Map<String, dynamic>> _listeVente(Response reponse) {
    final data = reponse.data;
    final liste = data is Map ? data['data'] : data;
    return (liste as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<TableauVentes> fetchTableauVentes() async {
    try {
      final reponse = await _dio.get('/ventes/tableau');
      return TableauVentes.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le tableau des ventes n'a pas pu être chargé.");
    }
  }

  /// [filtre] : tous, a_vendre, compromis, vendu ou sans_mandat.
  Future<List<BienVente>> fetchBiensVente({String filtre = 'tous', String? recherche, String? dossier}) async {
    try {
      final reponse = await _dio.get('/ventes/biens', queryParameters: {
        'filtre': filtre,
        if ((recherche ?? '').trim().isNotEmpty) 'q': recherche!.trim(),
        if ((dossier ?? '').isNotEmpty) 'dossier': dossier,
      });
      return _listeVente(reponse).map(BienVente.fromJson).toList();
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Les biens en vente n'ont pas pu être chargés.");
    }
  }

  Future<DossierVente> fetchDossierVente(int bien) async {
    try {
      final reponse = await _dio.get('/ventes/biens/$bien');
      return DossierVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le dossier de vente n'a pas pu être chargé.");
    }
  }

  Future<void> changerStatutVente(int bien, String statut) async {
    try {
      await _dio.put('/ventes/biens/$bien/statut', data: {'statut': statut});
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le statut n'a pas pu être modifié.");
    }
  }

  Future<MandatVente> creerMandatVente(int bien, Map<String, dynamic> champs) async {
    try {
      final reponse = await _dio.post('/ventes/biens/$bien/mandats', data: champs);
      return MandatVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être enregistré.");
    }
  }

  /// Donnees du bien et de son proprietaire pour pre-remplir un nouveau mandat.
  Future<MandatPrerempli> fetchMandatPrerempli(int bien) async {
    try {
      final reponse = await _dio.get('/ventes/biens/$bien/mandat-prerempli');
      return MandatPrerempli.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Les données du mandat n'ont pas pu être chargées.");
    }
  }

  /// Cree le mandat du bien en une fois (multipart) ; [signature] : PNG du
  /// proprietaire, absent si la signature est remise a plus tard.
  Future<MandatVente> creerMandatAvecSignature(int bien, Map<String, dynamic> champs, {Uint8List? signature}) async {
    try {
      final formulaire = FormData.fromMap({
        for (final e in champs.entries)
          if (e.value != null) e.key: '${e.value}',
        if (signature != null) 'signature': MultipartFile.fromBytes(signature, filename: 'signature_mandat_bien_$bien.png'),
      });
      final reponse = await _dio.post('/ventes/biens/$bien/mandats', data: formulaire);
      return MandatVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être enregistré.");
    }
  }

  Future<void> supprimerMandatVente(int id) async {
    try {
      await _dio.delete('/ventes/mandats/$id');
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être supprimé.");
    }
  }

  Future<String> telechargerMandatVente(int id) =>
      _pdfBail('/ventes/mandats/$id/pdf', 'mandat_$id', "Le mandat n'a pas pu être préparé.");

  /// Rend l'avertissement du serveur, s'il y en a un.
  Future<String?> envoyerMandatVente(int id) async {
    try {
      final reponse = await _dio.post('/ventes/mandats/$id/envoyer');
      return _avertissement(reponse);
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être envoyé.");
    }
  }

  /// Mandats. [libres] : seulement ceux qui ne sont lies a aucun bien.
  Future<List<MandatVente>> fetchMandatsVente({bool libres = false, String? recherche}) async {
    try {
      final reponse = await _dio.get('/ventes/mandats', queryParameters: {
        if (libres) 'libres': 1,
        if ((recherche ?? '').trim().isNotEmpty) 'q': recherche!.trim(),
      });
      return _listeVente(reponse).map(MandatVente.fromJson).toList();
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Les mandats n'ont pas pu être chargés.");
    }
  }

  Future<FicheMandat> fetchMandatVente(int id) async {
    try {
      final reponse = await _dio.get('/ventes/mandats/$id');
      return FicheMandat.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être chargé.");
    }
  }

  /// Mandat sans bien : le bien sera lie apres sa creation.
  Future<MandatVente> creerMandatLibre(Map<String, dynamic> champs) async {
    try {
      final reponse = await _dio.post('/ventes/mandats', data: champs);
      return MandatVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être enregistré.");
    }
  }

  /// Refuse par le serveur une fois le mandat signe.
  Future<MandatVente> modifierMandatVente(int id, Map<String, dynamic> champs) async {
    try {
      final reponse = await _dio.put('/ventes/mandats/$id', data: champs);
      return MandatVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être modifié.");
    }
  }

  /// [png] : la signature du proprietaire.
  Future<MandatVente> signerMandatVente(int id, Uint8List png) async {
    try {
      final formulaire = FormData.fromMap({
        'signature': MultipartFile.fromBytes(png, filename: 'signature_mandat_$id.png'),
      });
      final reponse = await _dio.post('/ventes/mandats/$id/signature', data: formulaire);
      return MandatVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "La signature n'a pas pu être enregistrée.");
    }
  }

  /// Lie le mandat au bien ; rend le dossier de vente du bien.
  Future<DossierVente> lierMandatVente(int id, int bien) async {
    try {
      final reponse = await _dio.put('/ventes/mandats/$id/bien', data: {'bien': bien});
      return DossierVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le mandat n'a pas pu être lié au bien.");
    }
  }

  Future<VisiteVente> creerVisiteVente(int bien, Map<String, dynamic> champs) async {
    try {
      final reponse = await _dio.post('/ventes/biens/$bien/visites', data: champs);
      return VisiteVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "La visite n'a pas pu être enregistrée.");
    }
  }

  /// [png] : la signature du client sur le recu de visite.
  Future<VisiteVente> signerVisiteVente(int id, Uint8List png) async {
    try {
      final formulaire = FormData.fromMap({
        'signature': MultipartFile.fromBytes(png, filename: 'signature_visite_$id.png'),
      });
      final reponse = await _dio.post('/ventes/visites/$id/signature', data: formulaire);
      return VisiteVente.fromJson(_donneesVente(reponse));
    } on DioException catch (ex) {
      throw _erreurBail(ex, "La signature n'a pas pu être enregistrée.");
    }
  }

  Future<void> modifierVisiteVente(int id, {String? suite, String? remarques}) async {
    try {
      await _dio.put('/ventes/visites/$id', data: {
        if (suite != null) 'suite': suite,
        if (remarques != null) 'remarques': remarques.trim(),
      });
    } on DioException catch (ex) {
      throw _erreurBail(ex, "La visite n'a pas pu être modifiée.");
    }
  }

  Future<void> supprimerVisiteVente(int id) async {
    try {
      await _dio.delete('/ventes/visites/$id');
    } on DioException catch (ex) {
      throw _erreurBail(ex, "La visite n'a pas pu être supprimée.");
    }
  }

  Future<String> telechargerRecuVisite(int id) =>
      _pdfBail('/ventes/visites/$id/pdf', 'visite_$id', "Le reçu de visite n'a pas pu être préparé.");

  Future<String?> envoyerRecuVisite(int id) async {
    try {
      final reponse = await _dio.post('/ventes/visites/$id/envoyer');
      return _avertissement(reponse);
    } on DioException catch (ex) {
      throw _erreurBail(ex, "Le reçu n'a pas pu être envoyé.");
    }
  }

  // ── Reception des notifications WhatsApp ──

  /// Erreur lisible ; 401 deconnecte, le reste (403 compris) garde le message du serveur.
  Exception _erreurReceptionWhatsapp(DioException ex, String defaut) {
    if (estCoupureReseau(ex)) return NetworkConnectivityException();
    if ((ex.response?.statusCode ?? 0) == 401) return UnAuthenticatedException();
    return Exception(messageServeur(ex, defaut));
  }

  Map<String, dynamic> _donneesReception(dynamic data) {
    final corps = data is Map && data['data'] is Map ? data['data'] : data;
    return Map<String, dynamic>.from(corps as Map);
  }

  /// Reglages de l'utilisateur connecte, ou d'un autre ([managerId], admin).
  Future<ReceptionWhatsapp> lireReceptionWhatsapp({int? managerId}) async {
    try {
      final reponse = await _dio.get(
          managerId == null ? '/reception-whatsapp' : '/reception-whatsapp/$managerId');
      return ReceptionWhatsapp.fromJson(_donneesReception(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReceptionWhatsapp(ex, "Les réglages WhatsApp n'ont pas pu être chargés.");
    }
  }

  /// [typesCoupes] : la liste complete des types a ne plus recevoir.
  Future<ReceptionWhatsapp> enregistrerReceptionWhatsapp({
    int? managerId,
    bool? actif,
    List<String>? typesCoupes,
  }) async {
    try {
      final reponse = await _dio.put(
        managerId == null ? '/reception-whatsapp' : '/reception-whatsapp/$managerId',
        data: {
          if (actif != null) 'actif': actif,
          if (typesCoupes != null) 'typesCoupes': typesCoupes,
        },
      );
      return ReceptionWhatsapp.fromJson(_donneesReception(reponse.data));
    } on DioException catch (ex) {
      throw _erreurReceptionWhatsapp(ex, "Le réglage n'a pas pu être enregistré.");
    }
  }

  /// Reglages de tous les utilisateurs (admin).
  Future<List<ReceptionWhatsapp>> receptionWhatsappUtilisateurs() async {
    try {
      final reponse = await _dio.get('/reception-whatsapp/utilisateurs');
      final data = reponse.data;
      final liste = (data is Map ? data['data'] : data) as List? ?? const [];
      return liste
          .map((e) => ReceptionWhatsapp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (ex) {
      throw _erreurReceptionWhatsapp(ex, "La liste n'a pas pu être chargée.");
    }
  }

  // ================= Desactivation des biens =================

  BienDesactive _bienDesactive(dynamic data) {
    final corps = data is Map && data['data'] is Map ? data['data'] : data;
    return BienDesactive.fromJson(Map<String, dynamic>.from(corps as Map));
  }

  /// 422 (reservations en cours / a venir, bail actif) : message du serveur.
  Future<BienDesactive> desactiverBien(int id, {String? motif}) async {
    try {
      final m = (motif ?? '').trim();
      final reponse = await _dio.post(
        '/realestates/$id/desactiver',
        data: m.isEmpty ? <String, dynamic>{} : {'motif': m},
      );
      return _bienDesactive(reponse.data);
    } on DioException catch (ex) {
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      throw Exception(messageServeur(ex, "Le bien n'a pas pu être désactivé."));
    }
  }

  Future<BienDesactive> reactiverBien(int id) async {
    try {
      final reponse = await _dio.post('/realestates/$id/reactiver');
      return _bienDesactive(reponse.data);
    } on DioException catch (ex) {
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      throw Exception(messageServeur(ex, "Le bien n'a pas pu être réactivé."));
    }
  }

  Future<List<BienDesactive>> biensDesactives() async {
    try {
      final reponse = await _dio.get('/biens-desactives');
      final data = reponse.data;
      final corps = data is Map ? data['data'] : data;
      final liste = corps is List
          ? corps
          : (corps is Map && corps['biens'] is List ? corps['biens'] as List : const []);
      return liste
          .whereType<Map>()
          .map((e) => BienDesactive.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (ex) {
      if ((ex.response?.statusCode ?? 0) == 401) throw UnAuthenticatedException();
      throw Exception(messageServeur(ex, "La liste des biens désactivés n'a pas pu être chargée."));
    }
  }

  // ================= Droits et permissions (administrateur) =================

  /// Les modules, leurs droits, et ce que chaque rôle possède.
  /// Reserve a l'administrateur : 403 sinon.
  Future<DroitsEtPermissions> fetchDroitsPermissions() async {
    try {
      final reponse = await _dio.get('/permissions');
      return DroitsEtPermissions.fromJson(reponse.data);
    } on DioException catch (ex) {
      throw _erreurPermissions(
          ex, "Les droits n'ont pas pu être chargés.");
    }
  }

  /// Remplace la liste des droits d'un rôle ; rend le rôle mis à jour.
  /// Le serveur refuse le rôle « admin » (422).
  Future<RolePermissions> majPermissionsRole(
      String nom, List<String> permissions) async {
    try {
      final reponse = await _dio.put('/permissions/roles/$nom', data: {
        'permissions': permissions,
      });
      final data = reponse.data;
      dynamic corps = data;
      if (corps is Map && corps['nom'] == null && corps['data'] != null) {
        corps = corps['data'];
      }
      if (corps is Map && corps['role'] is Map) corps = corps['role'];
      if (corps is Map) {
        return RolePermissions.fromJson(Map<String, dynamic>.from(corps));
      }
      // Reponse sans corps exploitable : on garde ce qui vient d'etre envoye.
      return RolePermissions(
          nom: nom, libelle: nom, permissions: permissions.toSet());
    } on DioException catch (ex) {
      throw _erreurPermissions(
          ex, "Les droits n'ont pas pu être enregistrés.");
    }
  }

  /// Les droits d'un utilisateur : ceux de son role, ceux accordes en
  /// plus, ceux retires, et le resultat effectif.
  Future<DetailUtilisateurPermissions> fetchPermissionsUtilisateur(
      int id) async {
    try {
      final reponse = await _dio.get('/permissions/utilisateurs/$id');
      return DetailUtilisateurPermissions.fromJson(reponse.data);
    } on DioException catch (ex) {
      throw _erreurPermissions(
          ex, "Les droits de l'utilisateur n'ont pas pu être chargés.");
    }
  }

  /// Enregistre les exceptions d'un utilisateur (droits accordes / retires).
  /// Le serveur refuse un administrateur et un droit a la fois accorde et
  /// retire (422).
  Future<DetailUtilisateurPermissions> majPermissionsUtilisateur(
      int id, List<String> accordes, List<String> retires) async {
    try {
      final reponse = await _dio.put('/permissions/utilisateurs/$id', data: {
        'accordes': accordes,
        'retires': retires,
      });
      return DetailUtilisateurPermissions.fromJson(reponse.data);
    } on DioException catch (ex) {
      throw _erreurPermissions(
          ex, "Les droits de l'utilisateur n'ont pas pu être enregistrés.");
    }
  }

  /// 401 deconnecte ; le reste (403 et 422 compris) garde le message
  /// du serveur, qui explique pourquoi le changement est refuse.
  Exception _erreurPermissions(DioException ex, String defaut) {
    if ((ex.response?.statusCode ?? 0) == 401) return UnAuthenticatedException();
    return Exception(messageServeur(ex, defaut));
  }
}
