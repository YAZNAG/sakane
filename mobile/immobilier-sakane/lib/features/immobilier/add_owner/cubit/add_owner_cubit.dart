import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/enums/app_status.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../models/owner.dart';
import '../../../../repository/repository.dart';

part 'add_owner_state.dart';

class AddOwnerCubit extends Cubit<AddOwnerState> {
  AddOwnerCubit() : super(AddOwnerState());

  /*{
    "name":"saad el",
    "email":"saad@gmail.com",
    "tel":"0612453739",
    "address":"test address"
}*/

  void addOwner(Owner owner) async {
    try {
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      Owner ownerRes = await repository.addOwner(owner);
      emit(state.copyWith(addStatus: AppStatus.success, owner: ownerRes));
    } on NetworkConnectivityException {
      emit(state.copyWith(addStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(addStatus: AppStatus.error, error: AppStrings.authorizationError));
    } on ValidatorException catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, error: "Error"));
    }
  }

  void updateOwner(Owner owner) async {
    try {
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      Owner ownerRes = await repository.updateOwner(owner);
      emit(state.copyWith(addStatus: AppStatus.success, owner: ownerRes));
    } on NetworkConnectivityException {
      emit(state.copyWith(addStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(addStatus: AppStatus.error, error: AppStrings.authorizationError));
    } on ValidatorException catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, error: "Error"));
    }
  }



}
