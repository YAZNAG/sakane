import 'package:bloc/bloc.dart';
import 'package:immobilier/models/rapport.dart';
import 'package:meta/meta.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/constants/enums/app_status.dart';
import '../../../../../core/dependencies/dependencies.dart';
import '../../../../../core/utils/logout.dart';
import '../../../../../exceptions/network_connectivity_exception.dart';
import '../../../../../exceptions/unauthenticated_exception.dart';
import '../../../../../exceptions/unauthorized_exception.dart';
import '../../../../../repository/repository.dart';

part 'rapport_state.dart';

class RapportCubit extends Cubit<RapportState> {
  RapportCubit(int id) : super(RapportState(id: id));



  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Rapport> rapports=await repository.fetchRapports(state.id!);
      emit(state.copyWith(fetchDataStatus: AppStatus.success,rapports: rapports));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch (ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: "Error"));
    }
  }





}
