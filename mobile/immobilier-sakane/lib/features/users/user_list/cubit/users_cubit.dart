import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/manager.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../repository/repository.dart';

part 'users_state.dart';

class UsersCubit extends Cubit<UsersState> {
  UsersCubit() : super(UsersState());

  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Manager> managers=await repository.getManagers();
      emit(state.copyWith(fetchDataStatus: AppStatus.success,managers: managers));
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

  void deleteUser(Manager user)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading,managerInOperationId: user.id));
      Repository repository=Dependencies.get<Repository>();
      await repository.deleteUser(user);
      emit(state.copyWith(actionStatus: AppStatus.success));
      fetchData();
    }catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error));
    }
  }


}
