import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/programed_charge.dart';
import 'package:immobilier/repository/repository.dart';

part 'programed_charges_state.dart';

class ProgramedChargesCubit extends Cubit<ProgramedChargesState> {
  ProgramedChargesCubit({int? realestate}) : super(ProgramedChargesState(realestate: realestate));

  void fetchData() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      List<ProgramedCharge> charges = await repository.fetchProgramedCharges(realestate: state.realestate);
      emit(state.copyWith(fetchStatus: AppStatus.success, programedCharges: charges));
    } catch (ex) {
      emit(state.copyWith(fetchStatus: AppStatus.error));
      rethrow;
    }
  }

  void deleteProgramedCharge(ProgramedCharge charge) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: charge.id));
      Repository repository = Dependencies.get<Repository>();
      await repository.deleteProgramedCharge(charge.id!);
      emit(state.copyWith(deleteStatus: AppStatus.success));
      fetchData();
    } on NetworkConnectivityException {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: "Vérifiez votre connexion"));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: "Action non autorisée"));
    } catch (ex) {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: ex.toString()));
    }
  }
}
