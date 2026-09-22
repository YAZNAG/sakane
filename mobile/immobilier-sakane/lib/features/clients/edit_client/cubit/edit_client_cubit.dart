import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/repository/repository.dart';

part 'edit_client_state.dart';

class EditClientCubit extends Cubit<EditClientState> {
  EditClientCubit() : super(EditClientState());

  void updateClient(Client client) async {
    try {
      emit(state.copyWith(updateStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      Client updated = await repository.updateClient(client);
      emit(state.copyWith(updateStatus: AppStatus.success, client: updated));
    } on NetworkConnectivityException {
      emit(state.copyWith(updateStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(updateStatus: AppStatus.error, error: AppStrings.authorizationError));
    } on ValidatorException catch (ex) {
      emit(state.copyWith(updateStatus: AppStatus.error, errors: ex.errors));
    } catch (ex) {
      emit(state.copyWith(updateStatus: AppStatus.error, error: AppStrings.error));
      rethrow;
    }
  }
}
