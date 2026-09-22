part of 'immobilier_detail_cubit.dart';

class ImmobilierDetailState {

  AppStatus? fetchStatus;
  String? error;
  Realestate? realestate;
  int? id;

  ImmobilierDetailState({
    this.fetchStatus,
    this.error,
    this.realestate,
    this.id
  });

  ImmobilierDetailState copyWith({
    AppStatus? fetchStatus,
    String? error,
    Realestate? realestate,
    int? id
  }) {
    return ImmobilierDetailState(
        fetchStatus: fetchStatus ?? this.fetchStatus,
        error: error ,
        realestate: realestate ?? this.realestate,
        id: id ?? this.id
    );
  }

}