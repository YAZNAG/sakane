part of 'programed_charges_cubit.dart';



class ProgramedChargesState {

  AppStatus? fetchStatus;
  AppStatus? deleteStatus;
  int? deletingId;
  String? error;
  List<ProgramedCharge>? programedCharges;
  int? realestate;

  ProgramedChargesState({
    this.fetchStatus,
    this.deleteStatus,
    this.deletingId,
    this.error,
    this.programedCharges,
    this.realestate
  });

  ProgramedChargesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? deleteStatus,
    int? deletingId,
    String? error,
    List<ProgramedCharge>? programedCharges,
    int? realestate
  }) {
    return ProgramedChargesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      deleteStatus: deleteStatus,
      deletingId: deletingId ?? this.deletingId,
      error: error ?? this.error,
      programedCharges: programedCharges ?? this.programedCharges,
      realestate: realestate ?? this.realestate
    );
  }

}

