import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/contract.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../models/media.dart';

part 'contract_state.dart';

class ContractCubit extends Cubit<ContractState> {
  ContractCubit(int id) : super(ContractState(id: id));



  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Contract> contracts=await repository.getContracts(state.id!);
      emit(state.copyWith(fetchStatus: AppStatus.success,contracts: contracts));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: "Error"));
      rethrow;
    }
  }

  /// Rapatrie le document et rend son chemin : c'est l'écran qui
  /// décide de la manière de l'afficher.
  Future<String> telechargerContrat(Media doc) async {
    final Directory dir = await getTemporaryDirectory();
    final String fullPath = "${dir.path}/${doc.url!.split("/").last}";
    await Dio().download(doc.url!, fullPath);
    return fullPath;
  }



}
