import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'charges_state.dart';

class ChargesCubit extends Cubit<ChargesState> {
  ChargesCubit(int? id) : super(ChargesState(
    from: DateTime.now().add(const Duration(days: -7)),
    to: DateTime.now(),
    id: id
  ));



  void fetchData()async{

      try{
        emit(state.copyWith(fetchStatus: AppStatus.loading));
        Repository repository=Dependencies.get<Repository>();
        List<Charge> charges=await repository.getCharges(
          state.from!.formattedDateEn,
          state.to!.formattedDateEn,
          realestate:state.id
        );
        emit(state.copyWith(fetchStatus: AppStatus.success,charges: charges));
      }on NetworkConnectivityException catch(ex){
        emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
      }on UnAuthenticatedException catch (ex){
        logout();
      }on UnAuthorizedException catch(ex){
        emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.authorizationError));
      }on ValidatorException catch (ex){
        emit(state.copyWith(fetchStatus: AppStatus.error,errors: ex.errors));
      }catch(ex){
        emit(state.copyWith(fetchStatus: AppStatus.error,error: "Error"));
        rethrow;
      }
  }


  void addCharge(Charge charge)async{
    try{
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Charge chargeR=await repository.addCharge(charge);
      emit(state.copyWith(addStatus: AppStatus.success));
      fetchData();
    } on OperationMiseEnFileException {
      // Enregistree sur le telephone : elle partira au retour du reseau.
      emit(state.copyWith(addStatus: AppStatus.success));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch (ex){
      emit(state.copyWith(addStatus: AppStatus.error,errors: ex.errors));
    }catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,error: "Error"));
    }
  }



  void deleteCharge(Charge charge) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: charge.id));
      Repository repository = Dependencies.get<Repository>();
      await repository.deleteCharge(charge.id!);
      emit(state.copyWith(deleteStatus: AppStatus.success));
      fetchData();
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    }
  }

  void pickDate(String type,DateTime date){
    if(type=="from"){
      emit(state.copyWith(from: date));
    }else{
      emit(state.copyWith(to: date));
    }
  }






}
