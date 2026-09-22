import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/enums/app_status.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../models/realestate.dart';
import '../../../../repository/repository.dart';

part 'immobilier_detail_state.dart';

class ImmobilierDetailCubit extends Cubit<ImmobilierDetailState> {
  ImmobilierDetailCubit(int id) : super(ImmobilierDetailState(id: id));


  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Realestate realestate=await repository.fetchRealesate(state.id!);
      emit(state.copyWith(fetchStatus: AppStatus.success,realestate: realestate));
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
