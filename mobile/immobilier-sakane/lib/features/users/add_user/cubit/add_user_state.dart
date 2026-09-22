part of 'add_user_cubit.dart';


class AddUserState {

  AppStatus? actionStatus;
  AppStatus? fetchDataStatus;
  List<String>? roles;
  String? selectedRole;
  String? error;
  Manager? manager;
  Map<String,dynamic>? errors;
  int? id;

  AddUserState({
    this.actionStatus,
    this.error,
    this.manager,
    this.errors,
    this.fetchDataStatus,
    this.roles,
    this.selectedRole,
    this.id
  });

  AddUserState copyWith({
    AppStatus? actionStatus,
    AppStatus? fetchDataStatus,
    String? error,
    Manager? manager,
    List<String>? roles,
    Map<String,dynamic>? errors,
    String? selectedRole,
    int? id
  }) {
    return AddUserState(
      actionStatus: actionStatus ,
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      error: error ,
      manager: manager ?? this.manager,
      errors: errors,
      roles: roles ?? this.roles,
      selectedRole: selectedRole ?? this.selectedRole,
      id: id ?? this.id
    );
  }

}