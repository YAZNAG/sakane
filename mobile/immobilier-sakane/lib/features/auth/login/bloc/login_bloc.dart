import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
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
  }

  FutureOr<void> _login(LoginSubmitted event, Emitter<LoginState> emit) async{
    try{
      emit(state.copyWith(loginStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Manager manager=await repository.login(event.manager);
      Dependencies.put(manager);
      SharedPrefService sharedPrefService=Dependencies.get<SharedPrefService>();
      sharedPrefService.putValue(SharedPrefService.token, manager.token);
      // Memorisation des identifiants pour pre-remplir le formulaire
      sharedPrefService.putValue(SharedPrefService.username, event.manager.email ?? "");
      sharedPrefService.putValue(SharedPrefService.password, event.manager.password ?? "");
      ApiClient apiClient=ApiClient(baseUrl: baseUrl,token: manager.token,apiAppsVersion: baseUrlApiVersion);
      Repository newRepo=Repository(apiClient: apiClient);
      Dependencies.put(newRepo);
      // La synchronisation envoie desormais avec cette session, et les
      // actions de ce compte en attente de reconnexion repartent.
      Synchronisation.instance.apresConnexion(apiClient.dio, managerId: manager.id, jeton: manager.token);
      emit(state.copyWith(loginStatus: AppStatus.success,manager: manager));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(loginStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      emit(state.copyWith(loginStatus: AppStatus.error,error: AppStrings.invalidCredential));
    }catch(ex){
      emit(state.copyWith(loginStatus: AppStatus.error,error: "Error"));
    }
  }
}
