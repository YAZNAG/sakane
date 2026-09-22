part of 'stats_cubit.dart';



class StatsState {

  int? id;
  RealestateStats? realestateStats;
  AppStatus? fetchDataStatus;
  String? error;
  DateTime? from;
  DateTime? to;
  String? groupBy;

  StatsState({
    this.id,
    this.realestateStats,
    this.fetchDataStatus,
    this.error,
    this.from,
    this.to,
    this.groupBy,
  });

  StatsState copyWith({
    int? id,
    RealestateStats? realestateStats,
    AppStatus? fetchDataStatus,
    String? error,
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) {
    return StatsState(
      id: id ?? this.id,
      realestateStats: realestateStats ?? this.realestateStats,
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      error: error ,
      from: from ?? this.from,
      to: to ?? this.to,
      groupBy: groupBy ?? this.groupBy,
    );
  }
}

