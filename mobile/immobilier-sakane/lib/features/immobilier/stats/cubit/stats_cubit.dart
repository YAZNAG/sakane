import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/models/realestate_stats.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';

part 'stats_state.dart';

class StatsCubit extends Cubit<StatsState> {
  StatsCubit(int id) : super(
      StatsState(
          id:id,
        from: DateTime.now().add(const Duration(days: -7)),
        to: DateTime.now(),
        groupBy: "day",

      )
  );




  void fetchData()async{
    try{
      emit(state.copyWith(fetchDataStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      RealestateStats realestateStats=await repository.getRealestateStats(
          state.from!.formattedDateEn,
          state.to!.formattedDateEn,
          state.groupBy!,
          state.id!);
      emit(state.copyWith(fetchDataStatus: AppStatus.success,realestateStats: realestateStats));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch (ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: AppStrings.authorizationError));
    }catch (ex){
      emit(state.copyWith(fetchDataStatus: AppStatus.error,error: "Error"));
    }
  }

  void selectDate(DateTime date,String type){
    if(type=="from"){
      emit(state.copyWith(from: date));
    }else{
      emit(state.copyWith(to: date));
    }
  }

  void changeGoupBy(String value){
    emit(state.copyWith(groupBy: value));
    fetchData();
  }




}
