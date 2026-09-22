part of 'add_modify_programed_charge_cubit.dart';

class AddModifyProgramedChargeState {
  final AppStatus? fetchStatus;
  final AppStatus? actionStatus;
  final String? error;
  final Map<String, dynamic>? errors;
  final int? id;
  final int? realestate;
  final ProgramedCharge? programedCharge;

  AddModifyProgramedChargeState({
    this.fetchStatus,
    this.actionStatus,
    this.error,
    this.errors,
    this.id,
    this.programedCharge,
    this.realestate
  });

  bool get isEditMode => id != null;

  AddModifyProgramedChargeState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    String? error,
    Map<String, dynamic>? errors,
    int? id,
    ProgramedCharge? programedCharge,
    int? realestate
  }) {
    return AddModifyProgramedChargeState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      actionStatus: actionStatus,
      error: error ?? this.error,
      errors: errors ?? this.errors,
      id: id ?? this.id,
      programedCharge: programedCharge ?? this.programedCharge,
      realestate: realestate ?? this.realestate
    );
  }
}