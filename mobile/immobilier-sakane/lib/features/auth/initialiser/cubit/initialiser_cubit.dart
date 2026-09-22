import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:immobilier/config.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/models/application.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';
import 'package:meta/meta.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:immobilier/core/utils/comparaison_version.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/core/offline/synchronisation.dart';
import 'package:immobilier/core/services/shared_pref_service.dart';

part 'initialiser_state.dart';

class InitialiserCubit extends Cubit<InitialiserState> {
  InitialiserCubit() : super(InitialiserState());



  /// Le numero de la version reellement installee, lu dans le paquet.
  ///
  /// Un numero ecrit en dur dans le code ne suit pas les mises a jour :
  /// l'application se croyait toujours en retard et redemandait sans fin
  /// la mise a jour qu'elle venait d'installer.
  Future<String> _versionInstallee() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return version;
    }
  }

  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Manager manager=await repository.me();
      Dependencies.put(manager);
      // La synchronisation envoie avec la session ouverte.
      Synchronisation.instance.apresConnexion(
        repository.apiClient.dio,
        managerId: manager.id,
        jeton: Dependencies.get<SharedPrefService>().getValue(SharedPrefService.token, ""),
      );

      // Le controle de version ne doit pas interdire l'acces a
      // l'application : sans reseau, on entre directement.
      AppVersion? appVersion;
      bool horsConnexion = false;
      try {
        appVersion = await repository.getApplicationVersion(packageName);
        Dependencies.put(appVersion);
      } on NetworkConnectivityException {
        horsConnexion = true;
      } catch (_) {
        horsConnexion = true;
      }

      final router=Routes.router;
      String distination=Routes.home;
      if (!horsConnexion && appVersion != null) {
        if(!(appVersion.isActive??true)){
          distination=Routes.appInactive;
        }else if (Platform.isAndroid && miseAJourDisponible(
            versionServeur: appVersion.version,
            versionInstallee: await _versionInstallee())) {
          // Uniquement si le serveur propose une version plus recente :
          // une application en avance ne doit pas etre bloquee.
          // Sur iPhone, la mise a jour passe par l'App Store : Apple
          // interdit d'installer l'application par un autre moyen.
          distination=Routes.newVersion;
        }
      }
      while(router.canPop()){
        router.pop();
      }
      router.replace(distination);
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }catch (ex){
      // Seule une session expiree deconnecte : un probleme de reseau ne
      // doit jamais faire perdre sa connexion a l'agent.
      if (ex is UnAuthenticatedException ||
          (ex is DioException && ex.response?.statusCode == 401)) {
        logout();
        return;
      }
      emit(state.copyWith(fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    }
  }




}
