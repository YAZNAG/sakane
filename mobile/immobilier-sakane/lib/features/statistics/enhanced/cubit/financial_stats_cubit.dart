import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/financial_stats.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';

part 'financial_stats_state.dart';

class FinancialStatsCubit extends Cubit<FinancialStatsState> {
  FinancialStatsCubit({int? realestateId})
      : super(FinancialStatsState(
          from: DateTime(DateTime.now().year, DateTime.now().month, 1),
          to: DateTime.now(),
          quickPeriod: 'month',
          selectedRealestateIds: realestateId != null ? [realestateId] : [],
          singlePropertyMode: realestateId != null,
        ));

  String _computeGroupBy(DateTime from, DateTime to) {
    final days = to.difference(from).inDays;
    if (days < 60) return 'day';
    if (days < 366) return 'month';
    return 'year';
  }

  Future<void> fetchStats() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final repo = Dependencies.get<Repository>();
      final stats = await repo.getFinancialStats(
        from: state.from!.formattedDateEn,
        to: state.to!.formattedDateEn,
        groupBy: _computeGroupBy(state.from!, state.to!),
        realestateIds: state.singlePropertyMode?state.selectedRealestateIds:[],
        repartition: state.repartition,
      );
      emit(state.copyWith(fetchStatus: AppStatus.success, stats: stats));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error,
          error: 'Vérifiez votre connexion internet'));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: 'Non autorisé'));
    } catch (_) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: 'Erreur'));
      rethrow;
    }
  }

 /* Future<void> loadRealestates() async {
    try {
      final repo = Dependencies.get<Repository>();
      final list = await repo.getRealestates();
      emit(state.copyWith(allRealestates: list));
    } catch (_) {}
  }*/

  void setDateRange(DateTime from, DateTime to) {
    emit(state.copyWith(from: from, to: to, quickPeriod: 'custom'));
    fetchStats();
  }

  void setQuickPeriod(String period) {
    final now = DateTime.now();
    DateTime from;
    DateTime to = now;

    switch (period) {
      case 'today':
        from = now;
        break;
      case 'yesterday':
        from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        to = from;
        break;
      case 'week':
        from = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        break;
      default:
        from = now.subtract(const Duration(days: 30));
    }

    emit(state.copyWith(from: from, to: to, quickPeriod: period));
    fetchStats();
  }

  /// L'argent a l'encaissement, ou reparti sur les nuits des sejours.
  void setRepartition(String repartition) {
    if (repartition == state.repartition) return;
    emit(state.copyWith(repartition: repartition));
    fetchStats();
  }

  void toggleRealestate(int id) {
    final ids = List<int>.from(state.selectedRealestateIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    emit(state.copyWith(selectedRealestateIds: ids));
    fetchStats();
  }

  void clearRealestateFilter() {
    emit(state.copyWith(selectedRealestateIds: []));
    fetchStats();
  }
}
