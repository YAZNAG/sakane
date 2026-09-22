part of 'immobilier_by_status_cubit.dart';




class ImmobilierByStatusState {

  AppStatus? fetchStatus;
  AppStatus? actionStatus;
  String? error;
  List<Realestate>? realestates;
  String? status;

  ImmobilierByStatusState({
    this.fetchStatus,
    this.actionStatus,
    this.error,
    this.realestates,
    this.status,
  });

  ImmobilierByStatusState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    String? error,
    List<Realestate>? realestates,
    String? status,
  }) {
    return ImmobilierByStatusState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      actionStatus: actionStatus ,
      error: error ,
      realestates: realestates ?? this.realestates,
      status: status ?? this.status,
    );
  }
}

