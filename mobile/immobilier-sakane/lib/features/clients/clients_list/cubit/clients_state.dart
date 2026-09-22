part of 'clients_cubit.dart';



class ClientsState {

  AppStatus? fetchStatus;
  AppStatus? deleteStatus;
  int? deletingId;
  String? error;
  List<Client>? clients;

  ClientsState({
    this.fetchStatus,
    this.deleteStatus,
    this.deletingId,
    this.error,
    this.clients,
  });

  ClientsState copyWith({
    AppStatus? fetchStatus,
    AppStatus? deleteStatus,
    int? deletingId,
    String? error,
    List<Client>? clients,
  }) {
    return ClientsState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      deleteStatus: deleteStatus,
      deletingId: deletingId ?? this.deletingId,
      error: error,
      clients: clients ?? this.clients,
    );
  }

}

