part of 'financial_stats_cubit.dart';

class FinancialStatsState {
  final AppStatus? fetchStatus;
  final String? error;
  final FinancialStats? stats;
  final DateTime? from;
  final DateTime? to;
  // 'today' | 'week' | 'month' | 'year' | 'custom'
  final String quickPeriod;
  final List<int> selectedRealestateIds;
  final List<Realestate> allRealestates;
  final bool singlePropertyMode;

  /// 'encaissement' : l'argent a sa date d'enregistrement ;
  /// 'nuit' : l'argent d'une reservation reparti sur ses nuits.
  final String repartition;

  FinancialStatsState({
    this.fetchStatus,
    this.error,
    this.stats,
    this.from,
    this.to,
    this.quickPeriod = 'month',
    this.selectedRealestateIds = const [],
    this.allRealestates = const [],
    this.singlePropertyMode = false,
    this.repartition = 'encaissement',
  });

  FinancialStatsState copyWith({
    AppStatus? fetchStatus,
    String? error,
    FinancialStats? stats,
    DateTime? from,
    DateTime? to,
    String? quickPeriod,
    List<int>? selectedRealestateIds,
    List<Realestate>? allRealestates,
    bool? singlePropertyMode,
    String? repartition,
  }) {
    return FinancialStatsState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      error: error,
      stats: stats ?? this.stats,
      from: from ?? this.from,
      to: to ?? this.to,
      quickPeriod: quickPeriod ?? this.quickPeriod,
      selectedRealestateIds:
          selectedRealestateIds ?? this.selectedRealestateIds,
      allRealestates: allRealestates ?? this.allRealestates,
      singlePropertyMode: singlePropertyMode ?? this.singlePropertyMode,
      repartition: repartition ?? this.repartition,
    );
  }
}
