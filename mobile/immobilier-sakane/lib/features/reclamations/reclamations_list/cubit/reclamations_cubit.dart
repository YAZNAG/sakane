import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/reclamation.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../repository/repository.dart';

part 'reclamations_state.dart';

class ReclamationsCubit extends Cubit<ReclamationsState> {
  ReclamationsCubit() : super(ReclamationsState());

  void fetchReclamations({int? realestateId}) async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading, realestateId: realestateId ?? state.realestateId));
      final repository = Dependencies.get<Repository>();
      final list = await repository.getReclamations(realestateId: realestateId ?? state.realestateId);
      emit(state.copyWith(fetchStatus: AppStatus.success, reclamations: list));
    } on NetworkConnectivityException {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: AppStrings.authorizationError));
    } catch (_) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: "Erreur inattendue"));
    }
  }

  void resolveReclamation(int id) async {
    try {
      emit(state.copyWith(resolvingId: id, resolveStatus: AppStatus.loading));
      final repository = Dependencies.get<Repository>();
      final updated = await repository.resolveReclamation(id);
      final updatedList = state.reclamations
          ?.map((r) => r.id == id ? updated : r)
          .toList();
      emit(state.copyWith(
        resolveStatus: AppStatus.success,
        reclamations: updatedList,
        resolvingId: null,
      ));
    } on NetworkConnectivityException {
      emit(state.copyWith(resolveStatus: AppStatus.error, error: AppStrings.checkConnectivity, resolvingId: null));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(resolveStatus: AppStatus.error, error: AppStrings.authorizationError, resolvingId: null));
    } catch (_) {
      emit(state.copyWith(resolveStatus: AppStatus.error, error: "Erreur inattendue", resolvingId: null));
    }
  }
}
