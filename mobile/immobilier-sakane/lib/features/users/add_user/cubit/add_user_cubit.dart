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

part 'add_user_state.dart';

class AddUserCubit extends Cubit<AddUserState> {
  AddUserCubit({int? id}) : super(AddUserState(id: id));

  void addUser(Manager manager) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      Manager managerR=await repository.addUser(manager.copyWith(roles: [state.selectedRole!]));
      emit(state.copyWith(actionStatus: AppStatus.success,manager: managerR ));
    } on NetworkConnectivityException catch (ex) {
      emit(
        state.copyWith(
          actionStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException catch (ex) {
      logout();
    } on UnAuthorizedException catch (ex) {
      emit(
        state.copyWith(
          actionStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } on ValidatorException catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: "Error"));
    }
  }


  void fetchData()async{
    try {
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      List<String> roles=await repository.getRoles();
      Manager? manager;
      if(state.id!=null){
        manager=await repository.fetchManager(state.id!);
      }
      emit(state.copyWith(fetchDataStatus: AppStatus.success,roles: roles,selectedRole:manager?.roles?.first ?? roles.first,manager: manager,));
    } on NetworkConnectivityException catch (ex) {
      emit(
        state.copyWith(
          fetchDataStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException catch (ex) {
      logout();
    } on UnAuthorizedException catch (ex) {
      emit(
        state.copyWith(
          fetchDataStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } on ValidatorException catch (ex) {
      emit(state.copyWith(fetchDataStatus: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(fetchDataStatus: AppStatus.error, error: "Error"));
      rethrow;
    }
  }

  void onRoleChanged(String role){
    emit(state.copyWith(selectedRole: role));
  }


  void updateUser(Manager manager) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      Manager managerR=await repository.updateUser(manager.copyWith(id: state.id,roles: [state.selectedRole!]));
      emit(state.copyWith(actionStatus: AppStatus.success,manager: managerR ));
    } on NetworkConnectivityException catch (ex) {
      emit(
        state.copyWith(
          actionStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException catch (ex) {
      logout();
    } on UnAuthorizedException catch (ex) {
      emit(
        state.copyWith(
          actionStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } on ValidatorException catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: "Error"));
    }
  }



}
