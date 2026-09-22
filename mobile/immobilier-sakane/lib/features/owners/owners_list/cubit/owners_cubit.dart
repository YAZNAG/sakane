import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../models/owner.dart';
import '../../../../repository/repository.dart';

part 'owners_state.dart';

class OwnersCubit extends Cubit<OwnersState> {
  OwnersCubit() : super(OwnersState());



  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Owner> owners=await repository.fetchOwners();
      emit(state.copyWith(fetchStatus: AppStatus.success,owners: owners,publicOwners: owners));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error));
    }
  }

  void deleteOwner(Owner owner) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: owner.id));
      Repository repository = Dependencies.get<Repository>();
      await repository.deleteOwner(owner.id!);
      emit(state.copyWith(deleteStatus: AppStatus.success));
      fetchData();
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      emit(state.copyWith(deleteStatus: AppStatus.error));
    }
  }

  void search(String query){
    query=query.trim();
    emit(state.copyWith(query: query));
    if(query.isEmpty){
      emit(state.copyWith(publicOwners: state.owners));
    }else{
      final owners=state.owners?.where((owner){
        return (
            (owner.name?.contains(query)??false)
                ||
            (owner.email?.contains(query)??false)
                ||
            (owner.tel?.contains(query)??false)
        );
      }).toList();
      emit(state.copyWith(publicOwners: owners));
    }

  }


}
