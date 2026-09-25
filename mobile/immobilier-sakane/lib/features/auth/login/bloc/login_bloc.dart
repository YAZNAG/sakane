import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/comptes_memorises_service.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/models/compte_memorise.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/data_providers/api/api_client.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';

import '../../../../config.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc() : super(LoginState()) {
    on<LoginSubmitted>(_login);
    on<ConnexionParJeton>(_connexionParJeton);
  }

  FutureOr<void> _login(LoginSubmitted event, Emitter<LoginState> emit) async{
    try{
      emit(state.copyWith(loginStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      // L'identifiant part tel qu'il a ete saisi : le serveur accepte une
      // adresse e-mail comme un numero de telephone, sous n'importe quel
      // format, et se debrouille avec les neuf derniers chiffres.
      Manager manager=await repository.login(event.manager);
      Dependencies.put(manager);
      SharedPrefService sharedPrefService=Dependencies.get<SharedPrefService>();
      sharedPrefService.putValue(SharedPrefService.token, manager.token);
      final identifiant=(event.manager.email ?? "").trim();
      // Le dernier identifiant utilise sert a la deconnexion, qui doit
      // savoir de quel compte effacer le jeton de deverrouillage.
      sharedPrefService.putValue(SharedPrefService.username, identifiant);
      // Le mot de passe n'est plus garde : la ou il l'etait, il est efface.
      sharedPrefService.removeRecord(SharedPrefService.password);
      final compte=_memoriser(identifiant, manager);
      ApiClient apiClient=ApiClient(baseUrl: baseUrl,token: manager.token,apiAppsVersion: baseUrlApiVersion);
      Repository newRepo=Repository(apiClient: apiClient);
      Dependencies.put(newRepo);
      // La synchronisation envoie desormais avec cette session, et les
      // actions de ce compte en attente de reconnexion repartent.
      Synchronisation.instance.apresConnexion(apiClient.dio, managerId: manager.id, jeton: manager.token);
      emit(state.copyWith(loginStatus: AppStatus.success,manager: manager,compte: compte));
    }on NetworkConnectivityException catch(_){
      emit(state.copyWith(loginStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      // Le serveur sait mieux que l'application pourquoi il refuse :
      // identifiant inconnu, mot de passe faux, compte desactive.
      emit(state.copyWith(loginStatus: AppStatus.error,error: ex.message ?? AppStrings.invalidCredential));
    }catch(_){
      emit(state.copyWith(loginStatus: AppStatus.error,error: AppStrings.error));
    }
  }

  /// Connexion sans mot de passe : le jeton sorti du coffre est presente au
  /// serveur, qui repond en decrivant son porteur. S'il le refuse, c'est
  /// que la session ne vaut plus rien — l'ecran devra effacer ce jeton et
  /// redemander le mot de passe.
  FutureOr<void> _connexionParJeton(
      ConnexionParJeton event, Emitter<LoginState> emit) async {
    try {
      emit(state.copyWith(loginStatus: AppStatus.loading));
      ApiClient apiClient = ApiClient(
          baseUrl: baseUrl,
          token: event.jeton,
          apiAppsVersion: baseUrlApiVersion);
      Repository repository = Repository(apiClient: apiClient);
      // Le jeton n'est ecrit dans les preferences qu'une fois accepte :
      // un jeton perime ne doit pas remplacer une session valable.
      Manager manager = (await repository.me()).copyWith(token: event.jeton);
      Dependencies.put(manager);
      Dependencies.put(repository);
      SharedPrefService sharedPrefService =
          Dependencies.get<SharedPrefService>();
      sharedPrefService.putValue(SharedPrefService.token, event.jeton);
      sharedPrefService.putValue(
          SharedPrefService.username, event.compte.identifiant);
      final compte = _memoriser(event.compte.identifiant, manager);
      Synchronisation.instance.apresConnexion(apiClient.dio,
          managerId: manager.id, jeton: event.jeton);
      emit(state.copyWith(
          loginStatus: AppStatus.success,
          manager: manager,
          compte: compte,
          parJeton: true));
    } on NetworkConnectivityException catch (_) {
      emit(state.copyWith(
          loginStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException catch (_) {
      emit(state.copyWith(
          loginStatus: AppStatus.error,
          error: AppStrings.sessionExpiree,
          jetonInvalide: true));
    } catch (_) {
      emit(state.copyWith(
          loginStatus: AppStatus.error, error: AppStrings.error));
    }
  }

  /// Retient ce compte pour la prochaine ouverture : de quoi le reconnaitre
  /// et lui dire bonjour, rien de secret.
  CompteMemorise _memoriser(String identifiant, Manager manager) {
    final service = ComptesMemorisesService();
    final connu = service.parIdentifiant(identifiant);
    final roles = manager.roles ?? const <String>[];
    final compte = CompteMemorise(
      identifiant: identifiant,
      managerId: manager.id,
      prenom: manager.firstName,
      nom: manager.lastName,
      email: manager.email,
      role: roles.isEmpty ? null : roles.first,
      couleurAvatar:
          connu?.couleurAvatar ?? CompteMemorise.couleurPour(identifiant),
      derniereConnexion: DateTime.now(),
    );
    service.enregistrer(compte);
    return compte;
  }
}
