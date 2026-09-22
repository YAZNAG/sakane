import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:meta/meta.dart';

import '../../../../core/dependencies/dependencies.dart';
import '../../../../repository/repository.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'immobilier_by_status_state.dart';

class ImmobilierByStatusCubit extends Cubit<ImmobilierByStatusState> {
  ImmobilierByStatusCubit(String status, [this.type, this.dossier])
      : super(ImmobilierByStatusState(status: status));

  /// Famille de biens a laquelle se limiter, ou null pour toutes.
  final String? type;

  /// Dossier de rangement, ou null pour tous.
  final String? dossier;


  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Realestate> realestates=await repository.getRealestates(
          status: state.status, type: type, dossier: dossier);
      emit(state.copyWith(fetchStatus: AppStatus.success,realestates: realestates));
    }catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error));
      rethrow;
    }
  }

  void confirmCheckin(Realestate realestate)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.confirmCheckin(realestate.id!);
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }on OperationMiseEnFileException{
      // Declaration conservee sur le telephone, envoyee au retour du reseau.
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }catch(ex){
      // Le motif du refus vaut mieux qu'un message generique : l'agent
      // doit savoir qu'il lui manquait une caisse ou du liquide.
      emit(state.copyWith(
        actionStatus: AppStatus.error,
        error: ex.toString().replaceFirst("Exception: ", ""),
      ));
      rethrow;
    }
  }

  void finishCleaning(Realestate realestate)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.finishCleaning(realestate.id!);
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }on OperationMiseEnFileException{
      // Declaration conservee sur le telephone, envoyee au retour du reseau.
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }catch(ex){
      // Le motif du refus vaut mieux qu'un message generique : l'agent
      // doit savoir qu'il lui manquait une caisse ou du liquide.
      emit(state.copyWith(
        actionStatus: AppStatus.error,
        error: ex.toString().replaceFirst("Exception: ", ""),
      ));
      rethrow;
    }
  }
  /// Declare le debut du nettoyage : le chronometre demarre.
  void startCleaning(Realestate realestate) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      await repository.startCleaning(realestate.id!);
      emit(state.copyWith(actionStatus: AppStatus.success));
    } on OperationMiseEnFileException {
      emit(state.copyWith(actionStatus: AppStatus.success));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error));
      rethrow;
    }
  }

  /// Remet un appartement en nettoyage (menage juge insuffisant).
  void returnToCleaning(Realestate realestate, {String? motif}) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      await repository.returnToCleaning(realestate.id!, motif: motif);
      emit(state.copyWith(actionStatus: AppStatus.success));
    } on OperationMiseEnFileException {
      emit(state.copyWith(actionStatus: AppStatus.success));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error));
      rethrow;
    }
  }

  void prolonger(DateTime newCheckout, double price, int id) async {
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.extendBooking(newCheckout, price, id);
      fetchData();
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }on OperationMiseEnFileException{
      // Declaration conservee sur le telephone, envoyee au retour du reseau.
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }catch(ex){
      // Le motif du refus vaut mieux qu'un message generique : l'agent
      // doit savoir qu'il lui manquait une caisse ou du liquide.
      emit(state.copyWith(
        actionStatus: AppStatus.error,
        error: ex.toString().replaceFirst("Exception: ", ""),
      ));
      rethrow;
    }
  }

  void shrink(DateTime newCheckout,double refundPrice,int id)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.shrinkBooking(newCheckout, refundPrice, id);
      fetchData();
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }on OperationMiseEnFileException{
      // Declaration conservee sur le telephone, envoyee au retour du reseau.
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }catch(ex){
      // Le motif du refus vaut mieux qu'un message generique : l'agent
      // doit savoir qu'il lui manquait une caisse ou du liquide.
      emit(state.copyWith(
        actionStatus: AppStatus.error,
        error: ex.toString().replaceFirst("Exception: ", ""),
      ));
      rethrow;
    }
  }

}
