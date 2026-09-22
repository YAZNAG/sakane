import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/client.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import '../../../../repository/repository.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'add_client_state.dart';

class AddClientCubit extends Cubit<AddClientState> {
  AddClientCubit() : super(AddClientState());


  void addClient(Client client)async{
    try{
      emit(state.copyWith(addStatus:AppStatus.loading ));
      Repository repository=Dependencies.get<Repository>();
      Client clientRes=await repository.addClient(client);
      emit(state.copyWith(addStatus:AppStatus.success,client: clientRes));
    } on OperationMiseEnFileException {
      // L'action est conservee sur le telephone : pour l'utilisateur
      // le client est enregistre, l'envoi se fera plus tard.
      emit(state.copyWith(addStatus: AppStatus.success));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }on UnAuthorizedException catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,error: AppStrings.authorizationError));
    }on ValidatorException catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,errors: ex.errors));
    }catch(ex){
      emit(state.copyWith(addStatus: AppStatus.error,error: "Error"));
      rethrow;
    }
  }


}
