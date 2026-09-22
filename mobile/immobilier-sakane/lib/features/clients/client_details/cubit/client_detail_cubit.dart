import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:path_provider/path_provider.dart';

part 'client_detail_state.dart';

class ClientDetailCubit extends Cubit<ClientDetailState> {
  ClientDetailCubit(int id) : super(ClientDetailState(id:id ));



  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Client client=await repository.fetchClientDetail(state.id!);
      emit(state.copyWith(fetchDataStatus: AppStatus.success,client: client));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on ValidatorException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,errors: ex.errors));
    }on UnAuthenticatedException catch(ex){
      logout();
    }catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: "Error"));
    }
  }

  void ajouterListeNoire(String motif) async {
    final client = state.client;
    if (client?.id == null) return;
    emit(state.copyWith(listeNoireStatus: AppStatus.loading));
    ListeNoire? listeNoire;
    try {
      final maj = await Dependencies.get<Repository>().ajouterListeNoire(client!.id!, motif);
      listeNoire = maj.listeNoire;
    } on Exception catch (ex) {
      emit(state.copyWith(listeNoireStatus: AppStatus.error, listeNoireMessage: _message(ex)));
      return;
    } catch (_) {
      // Reponse illisible alors que la requete a abouti : on applique localement
    }
    if (isClosed) return;
    final manager = Dependencies.get<Manager>();
    final par = [manager.firstName, manager.lastName].whereType<String>().join(' ').trim();
    _appliquerListeNoire(
      listeNoire ?? ListeNoire(le: DateTime.now(), motif: motif, par: par.isEmpty ? null : par),
      "Client mis sur liste noire",
    );
  }

  void retirerListeNoire() async {
    final client = state.client;
    if (client?.id == null) return;
    emit(state.copyWith(listeNoireStatus: AppStatus.loading));
    try {
      await Dependencies.get<Repository>().retirerListeNoire(client!.id!);
    } on Exception catch (ex) {
      emit(state.copyWith(listeNoireStatus: AppStatus.error, listeNoireMessage: _message(ex)));
      return;
    } catch (_) {
      // Reponse illisible alors que la requete a abouti : on applique localement
    }
    if (isClosed) return;
    _appliquerListeNoire(null, "Client retiré de la liste noire");
  }

  /// Nouvel etat avec une copie du client : tout l'ecran se reconstruit.
  void _appliquerListeNoire(ListeNoire? listeNoire, String message) {
    final client = state.client;
    if (client == null) return;
    emit(state.copyWith(
      client: client.copyWith(listeNoire: listeNoire, effacerListeNoire: listeNoire == null),
      listeNoireStatus: AppStatus.success,
      listeNoireMessage: message,
    ));
  }

  /// Rapatrie un contrat et rend son chemin local.
  Future<String> telechargerContrat(String url, String nom) async {
    final Directory dir = await getTemporaryDirectory();
    final String chemin = "${dir.path}/$nom";
    await Dio().download(url, chemin);
    return chemin;
  }

  static String _message(Object ex) =>
      ex.toString().replaceFirst('Exception: ', '');
}
