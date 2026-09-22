part of 'global_state_cubit.dart';



class GlobalStateState {

  AppStatus? fetchDataStatus;
  String? error;
  String? groupBy;
  DateTime? from;
  DateTime? to;
  GlobalStats? globalStats;

  GlobalStateState({
    this.fetchDataStatus,
    this.error,
    this.from,
    this.to,
    this.globalStats,
    this.groupBy
  });

  GlobalStateState copyWith({
    AppStatus? fetchDataStatus,
    String? error,
    DateTime? from,
    DateTime? to,
    GlobalStats? globalStats,
    String? groupBy
  }) {
    return GlobalStateState(
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      error: error ,
      from: from ?? this.from,
      to: to ?? this.to,
      globalStats: globalStats ?? this.globalStats,
      groupBy: groupBy??this.groupBy
    );
  }
}

