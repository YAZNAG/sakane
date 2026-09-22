part of 'client_detail_cubit.dart';


class ClientDetailState {

  int? id;
  AppStatus? fetchDataStatus;
  String? error;
  Map<String,dynamic>? errors;
  Client? client;

  /// Mise sur liste noire ou retrait en cours / terminé.
  AppStatus? listeNoireStatus;
  String? listeNoireMessage;

  ClientDetailState({
    this.id,
    this.fetchDataStatus,
    this.error,
    this.errors,
    this.client,
    this.listeNoireStatus,
    this.listeNoireMessage,
  });

  ClientDetailState copyWith({
    int? id,
    AppStatus? fetchDataStatus,
    String? error,
    Map<String, dynamic>? errors,
    Client? client,
    AppStatus? listeNoireStatus,
    String? listeNoireMessage,
  }) {
    return ClientDetailState(
      id: id ?? this.id,
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      error: error ,
      errors: errors ,
      client: client ?? this.client,
      listeNoireStatus: listeNoireStatus,
      listeNoireMessage: listeNoireMessage,
    );
  }
}

