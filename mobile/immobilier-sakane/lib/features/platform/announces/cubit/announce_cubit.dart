import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../repository/repository.dart';

part 'announce_state.dart';

class AnnounceCubit extends Cubit<AnnounceState> {
  AnnounceCubit() : super(AnnounceState());


  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Realestate> announces=await repository.getPendingAnnoces();
      emit(state.copyWith(fetchDataStatus: AppStatus.success,annouces: announces));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch (ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,));
    }catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: "Error"));
    }
  }

  void acceptAnnounce(int id)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Realestate announce=await repository.acceptAnnounce(id);
      emit(state.copyWith(actionStatus: AppStatus.success,));
      fetchData();
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch (ex){
      emit(state.copyWith(actionStatus: AppStatus.error,));
    }catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: "Error"));
    }
  }

  void refuseAnnounce(int id)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Realestate announce=await repository.refuseAnnounce(id);
      emit(state.copyWith(actionStatus: AppStatus.success,));
      fetchData();
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch (ex){
      emit(state.copyWith(actionStatus: AppStatus.error,));
    }catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: "Error"));
    }
  }


}
