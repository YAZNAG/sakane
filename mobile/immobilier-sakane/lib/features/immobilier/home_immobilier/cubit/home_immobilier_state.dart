part of 'home_immobilier_cubit.dart';


class HomeImmobilierState {

  AppStatus? fetchStatus;
  String? error;
  Realestate? realestate;
  int? id;

  HomeImmobilierState({
    this.fetchStatus,
    this.error,
    this.realestate,
    this.id
  });

  HomeImmobilierState copyWith({
    AppStatus? fetchStatus,
    String? error,
    Realestate? realestate,
    int? id
  }) {
    return HomeImmobilierState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      error: error ,
      realestate: realestate ?? this.realestate,
      id: id ?? this.id
    );
  }

}



