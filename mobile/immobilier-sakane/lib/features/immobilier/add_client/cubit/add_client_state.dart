part of 'add_client_cubit.dart';

class AddClientState {
  AppStatus? addStatus;
  String? error;
  Client? client;
  Map<String,dynamic>? errors;

  AddClientState({
    this.addStatus,
    this.error,
    this.client,
    this.errors
  });

  AddClientState copyWith({
    AppStatus? addStatus,
    String? error,
    Client? client,
    Map<String,dynamic>? errors
  }) {
    return AddClientState(
      addStatus: addStatus ?? this.addStatus,
      error: error ,
      client: client ?? this.client,
      errors: errors
    );
  }

}


