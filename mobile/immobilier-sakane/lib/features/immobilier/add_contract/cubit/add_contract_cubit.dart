import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/contract.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:meta/meta.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';

part 'add_contract_state.dart';

class AddContractCubit extends Cubit<AddContractState> {
  AddContractCubit(int id) : super(AddContractState(id: id));



  void addContract(Contract contract)async{
    try{
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      contract=contract.copyWith(realestate: Realestate(id: state.id));
      Contract contractR=await repository.addContract(contract);
      emit(state.copyWith(addStatus: AppStatus.success,contract: contractR));
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


  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Client> clients=await repository.getClients();
      List<Owner> owners=await repository.fetchOwners();
      emit(state.copyWith(fetchStatus: AppStatus.success,clients: clients,owners: owners));
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
    }
  }


}
