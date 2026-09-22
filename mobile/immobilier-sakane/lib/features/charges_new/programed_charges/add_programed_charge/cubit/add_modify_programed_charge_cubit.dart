import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/programed_charge.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';

part 'add_modify_programed_charge_state.dart';

class AddModifyProgramedChargeCubit extends Cubit<AddModifyProgramedChargeState> {
  AddModifyProgramedChargeCubit({int? id,int? realestate}) : super(AddModifyProgramedChargeState(id: id,realestate: realestate)) {
    if (id != null) fetchCharge(id);
  }

  void fetchCharge(int id) async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      ProgramedCharge charge = await repository.fetchProgramedCharge(id);
      emit(state.copyWith(fetchStatus: AppStatus.success, programedCharge: charge));
    } catch (ex) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: ex.toString()));
    }
  }

  void submit(ProgramedCharge programedCharge) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      if (state.id != null) {
        ProgramedCharge updated = await repository.updateProgramedCharge(
          programedCharge.copyWith(id: state.id),
        );
        emit(state.copyWith(actionStatus: AppStatus.success, programedCharge: updated));
      } else {
        programedCharge=programedCharge.copyWith(
                realestate:  Realestate(id: state.realestate)
                );
        ProgramedCharge created = await repository.addProgramedCharge(programedCharge);
        emit(state.copyWith(actionStatus: AppStatus.success, programedCharge: created));
      }
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: ex.toString()));
    }
  }
}