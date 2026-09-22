part of 'initialiser_cubit.dart';


class InitialiserState {
  AppStatus? fetchStatus;
  String? error;
  Manager? manager;

  InitialiserState({
    this.fetchStatus,
    this.error,
    this.manager,
  });

  InitialiserState copyWith({
    AppStatus? fetchStatus,
    String? error,
    Manager? manager,
  }) {
    return InitialiserState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      error: error ,
      manager: manager ?? this.manager,
    );
  }

}

