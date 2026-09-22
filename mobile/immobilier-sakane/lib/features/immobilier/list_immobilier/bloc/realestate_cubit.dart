import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';

part 'realestate_state.dart';

class RealestateCubit extends Cubit<RealestateState> {
  RealestateCubit() : super(RealestateState());


  void deleteRealestate(Realestate realestate) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: realestate.id));
      Repository repository = Dependencies.get<Repository>();
      await repository.deleteRealestate(realestate.id!);
      emit(state.copyWith(deleteStatus: AppStatus.success));
      fetchData();
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: AppStrings.authorizationError));
    } catch (_) {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    }
  }

  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Realestate> realestates=await repository.getRealestates();
      emit(state.copyWith(fetchStatus: AppStatus.success,realestates: realestates));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: "Error"));
      rethrow;
    }
  }

}
