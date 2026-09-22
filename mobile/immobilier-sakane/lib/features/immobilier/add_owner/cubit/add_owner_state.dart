part of 'add_owner_cubit.dart';

class AddOwnerState {
  AppStatus? addStatus;
  String? error;
  Owner? owner;
  Map<String,dynamic>? errors;

  AddOwnerState({
    this.addStatus,
    this.error,
    this.owner,
    this.errors
  });

  AddOwnerState copyWith({
    AppStatus? addStatus,
    String? error,
    Owner? owner,
    Map<String,dynamic>? errors
  }) {
    return AddOwnerState(
      addStatus: addStatus ?? this.addStatus,
      error: error ,
      owner: owner ?? this.owner,
      errors: errors ?? this.errors
    );
  }
}

