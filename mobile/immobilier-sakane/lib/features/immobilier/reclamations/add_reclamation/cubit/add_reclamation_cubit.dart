import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/reclamation.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/dependencies/dependencies.dart';
import '../../../../../core/utils/logout.dart';
import '../../../../../exceptions/network_connectivity_exception.dart';
import '../../../../../exceptions/unauthenticated_exception.dart';
import '../../../../../exceptions/unauthorized_exception.dart';
import '../../../../../exceptions/validation_exception.dart';
import '../../../../../repository/repository.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'add_reclamation_state.dart';

class AddReclamationCubit extends Cubit<AddReclamationState> {
  AddReclamationCubit(int realestateId)
    : super(AddReclamationState(realestateId: realestateId));

  void createReclamation(Reclamation reclamation) async {
    try {
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      Reclamation result = await repository.createReclamation(
        reclamation.copyWith(realestateId: state.realestateId),
      );
      emit(state.copyWith(addStatus: AppStatus.success, reclamation: result));
    } on OperationMiseEnFileException {
      emit(state.copyWith(addStatus: AppStatus.success));
    } on NetworkConnectivityException {
      emit(
        state.copyWith(
          addStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(
        state.copyWith(
          addStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } on ValidatorException catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, errors: ex.errors));
    } catch (_) {
      emit(
        state.copyWith(addStatus: AppStatus.error, error: "Erreur inattendue"),
      );
      rethrow;
    }
  }
}
