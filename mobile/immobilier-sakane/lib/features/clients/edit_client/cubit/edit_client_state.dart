part of 'edit_client_cubit.dart';

class EditClientState {
  AppStatus? updateStatus;
  String? error;
  Client? client;
  Map<String, dynamic>? errors;

  EditClientState({
    this.updateStatus,
    this.error,
    this.client,
    this.errors,
  });

  EditClientState copyWith({
    AppStatus? updateStatus,
    String? error,
    Client? client,
    Map<String, dynamic>? errors,
  }) {
    return EditClientState(
      updateStatus: updateStatus ?? this.updateStatus,
      error: error,
      client: client ?? this.client,
      errors: errors,
    );
  }
}
