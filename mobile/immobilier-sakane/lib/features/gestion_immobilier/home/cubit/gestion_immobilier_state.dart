part of 'gestion_immobilier_cubit.dart';



class GestionImmobilierState {

  AppStatus? fetchDataStatus;
  AppStatus? actionStatus;
  ImmobilierOverview? immobilierOverview;
  String? error;

  GestionImmobilierState({
    this.fetchDataStatus,
    this.immobilierOverview,
    this.error,
    this.actionStatus
  });

  GestionImmobilierState copyWith({
    AppStatus? fetchDataStatus,
    AppStatus? actionStatus,
    ImmobilierOverview? immobilierOverview,
    String? error,
  }) {
    return GestionImmobilierState(
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      immobilierOverview: immobilierOverview ?? this.immobilierOverview,
      error: error ?? this.error,
      actionStatus: actionStatus
    );
  }

}


