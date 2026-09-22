import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/repository/repository.dart';

part 'clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {

  ClientsCubit() : super(ClientsState());

  void deleteClient(int id) async {
    try {
      emit(state.copyWith(deleteStatus: AppStatus.loading, deletingId: id));
      Repository repository = Dependencies.get<Repository>();
      await repository.deleteClient(id);
      final updated = state.clients?.where((c) => c.id != id).toList();
      emit(state.copyWith(deleteStatus: AppStatus.success, clients: updated));
    } on NetworkConnectivityException {
      emit(state.copyWith(deleteStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } catch (ex) {
      emit(state.copyWith(deleteStatus: AppStatus.error));
      rethrow;
    }
  }

  /// Recharge la liste sans afficher le chargement.
  void rafraichir() async {
    try {
      final clients = await Dependencies.get<Repository>().getClients();
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.success, clients: clients));
    } on UnAuthenticatedException {
      logout();
    } catch (_) {}
  }

  void fetchData()async{
    try{
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository=Dependencies.get<Repository>();
      List<Client> clients=await repository.getClients();
      emit(state.copyWith(fetchStatus: AppStatus.success,clients: clients));
    }on NetworkConnectivityException catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error,error: AppStrings.checkConnectivity));
    }on UnAuthenticatedException catch(ex){
      logout();
    }catch(ex){
      emit(state.copyWith(fetchStatus: AppStatus.error));
      rethrow;
    }
  }

}
