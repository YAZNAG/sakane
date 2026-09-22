import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/rapport.dart';
import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/dependencies/dependencies.dart';
import '../../../../../core/utils/logout.dart';
import '../../../../../exceptions/network_connectivity_exception.dart';
import '../../../../../exceptions/unauthenticated_exception.dart';
import '../../../../../exceptions/unauthorized_exception.dart';
import '../../../../../exceptions/validation_exception.dart';
import '../../../../../repository/repository.dart';

part 'add_rapport_state.dart';

class AddRapportCubit extends Cubit<AddRapportState> {

  AddRapportCubit(int id) : super(AddRapportState(id: id));


  void addRapport(Rapport rapport)async{
    try{
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      Rapport rapportR=await repository.addRapport(rapport.copyWith(realestate: state.id));
      emit(state.copyWith(addStatus: AppStatus.success,rapport: rapportR));
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

}
