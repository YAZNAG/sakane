import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../models/slider.dart';
import '../../../../repository/repository.dart';

part 'slider_state.dart';

class SliderCubit extends Cubit<SliderState> {
  SliderCubit() : super(SliderState());


  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<SliderModel> sliders=await repository.getSliders();
      emit(state.copyWith(fetchDataStatus: AppStatus.success,sliders: sliders));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch (ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,));
    }catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: "Error"));
    }
  }

  void activateSlider(int id)async{
    try{
      emit(state.copyWith(actionStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      SliderModel slider=await repository.activateSlider(id);
      emit(state.copyWith(actionStatus: AppStatus.success,));
      fetchData();
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch (ex){
      emit(state.copyWith(actionStatus: AppStatus.error,errors: ex.errors));
    }catch(ex){
      emit(state.copyWith(actionStatus: AppStatus.error,error: "Error"));
    }
  }

}
