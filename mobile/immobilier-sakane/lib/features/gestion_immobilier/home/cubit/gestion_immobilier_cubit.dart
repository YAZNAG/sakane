import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/models/immobilier_overview.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';

part 'gestion_immobilier_state.dart';

class GestionImmobilierCubit extends Cubit<GestionImmobilierState> {
  GestionImmobilierCubit() : super(GestionImmobilierState());



  void fetchData()async{
    try{
     emit(state.copyWith(fetchDataStatus: AppStatus.loading));
     Repository repository=Dependencies.get<Repository>();
     ImmobilierOverview immobilierOverview=await repository.fetchImmobilierOverview();
     emit(state.copyWith(fetchDataStatus: AppStatus.success,immobilierOverview: immobilierOverview));
    }catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error));
      rethrow;
    }
  }


  void confirmDepart(Realestate realestate)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.confirmDepart(realestate.id!);
      fetchData();
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error));
      rethrow;
    }
  }

  void prolonger(DateTime newCheckout,double price,int id)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      await repository.extendBooking(newCheckout, price, id);
      fetchData();
      emit(state.copyWith(actionStatus: AppStatus.success,));
    }catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error));
      rethrow;
    }
  }

}
