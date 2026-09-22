import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'add_charge_state.dart';

class AddChargeCubit extends Cubit<AddChargeState> {
  AddChargeCubit({int? realestate})
      : super(AddChargeState(realestate: realestate)) {
    chargerBiens();
  }

  /// Les appartements proposés au choix. Sans réponse du serveur, le
  /// formulaire reste utilisable : la charge sera celle de l'agence.
  Future<void> chargerBiens() async {
    try {
      Repository repository = Dependencies.get<Repository>();
      final biens = await repository.getRealestates();
      emit(state.copyWith(biens: biens));
    } catch (_) {
      // Sans la liste, seule la dépense d'agence reste possible.
    }
  }

  /// L'appartement sur lequel porte la charge, ou aucun : la charge est
  /// alors celle de l'agence.
  void choisirBien(int? id) {
    emit(id == null
        ? state.copyWith(sansBien: true)
        : state.copyWith(realestate: id));
  }

  void addCharge(Charge charge) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      print("==========realestate=====${state.realestate}");
      charge=charge.copyWith(realEstate: Realestate(id: state.realestate));
      await repository.addCharge(charge);
      emit(state.copyWith(actionStatus: AppStatus.success));
    } on OperationMiseEnFileException {
      // Charge conservee sur le telephone : elle partira au retour du reseau.
      emit(state.copyWith(actionStatus: AppStatus.success));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: ex.toString()));
      rethrow;
    }
  }
}