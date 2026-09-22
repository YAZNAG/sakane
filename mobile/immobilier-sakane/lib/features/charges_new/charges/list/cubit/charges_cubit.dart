import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';

part 'charges_state.dart';

class ChargesCubit extends Cubit<ChargesState> {
  ChargesCubit({int? realestate}) : super(ChargesState(
    from: DateTime.now().subtract(Duration(days: 30)),
    to: DateTime.now(),
    realestate: realestate,
    bien: realestate?.toString() ?? "agence",
  )) {
    fetchData();
    _chargerBiens();
  }

  Future<void> _chargerBiens() async {
    try {
      final biens = await Dependencies.get<Repository>().getRealestates();
      biens.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
      if (!isClosed) emit(state.copyWith(biens: biens));
    } catch (_) {}
  }

  /// "agence", "all" ou l'identifiant d'un appartement.
  void setBien(String bien) {
    emit(state.copyWith(bien: bien));
    fetchData();
  }

  void fetchData() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      List<Charge> charges = await repository.fetchCharges(
        type: state.type,
        status: state.status,
        from: state.from?.toIso8601String(),
        to: state.to?.toIso8601String(),
        realestate: state.bien == "agence" ? null : state.bien
      );
      emit(state.copyWith(fetchStatus: AppStatus.success, charges: charges));
    } catch (ex) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: ex.toString()));
    }
  }

  void pickDate(String key, DateTime date) {
    if (key == "from") {
      emit(state.copyWith(from: date));
    } else {
      emit(state.copyWith(to: date));
    }
  }

  void setType(String? type) => emit(state.copyWith(type: type));
  void setStatus(String? status) => emit(state.copyWith(status: status));

  void validateCharge(Charge charge) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      await repository.validateCharge(charge);
      emit(state.copyWith(actionStatus: AppStatus.success));
      fetchData();
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: ex.toString()));
    }
  }

  /// Annule une charge et remet en caisse ce qui a ete rendu.
  ///
  /// On reutilise l'indicateur de suppression : pour qui regarde la
  /// liste, c'est la meme attente sur la meme ligne.
  void annulerCharge(Charge charge, {double? montant, String? motif}) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: charge.id));
      Repository repository = Dependencies.get<Repository>();
      await repository.annulerCharge(charge.id!, montant: montant, motif: motif);
      emit(state.copyWith(deleteStatus: AppStatus.success));
      fetchData();
    } catch (ex) {
      emit(state.copyWith(
          deleteStatus: AppStatus.error,
          error: ex.toString().replaceFirst("Exception: ", "")));
    }
  }

  void deleteCharge(Charge charge) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: charge.id));
      Repository repository = Dependencies.get<Repository>();
      await repository.deleteCharge(charge.id!);
      emit(state.copyWith(deleteStatus: AppStatus.success));
      fetchData();
    } catch (ex) {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: ex.toString()));
    }
  }
}