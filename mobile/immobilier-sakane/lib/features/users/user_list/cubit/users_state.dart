part of 'users_cubit.dart';



class UsersState {

  AppStatus? fetchDataStatus;
  AppStatus? actionStatus;
  List<Manager>? managers;
  String? error;
  int? managerInOperationId;

  UsersState({
    this.fetchDataStatus,
    this.managers,
    this.error,
    this.actionStatus,
    this.managerInOperationId
  });

  UsersState copyWith({
    AppStatus? fetchDataStatus,
    AppStatus? actionStatus,
    List<Manager>? managers,
    String? error,
    int? managerInOperationId
  }) {
    return UsersState(
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      managers: managers ?? this.managers,
      error: error ?? this.error,
      actionStatus: actionStatus,
      managerInOperationId: managerInOperationId
    );
  }

}

