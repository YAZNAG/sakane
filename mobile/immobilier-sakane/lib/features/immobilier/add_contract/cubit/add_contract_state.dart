part of 'add_contract_cubit.dart';




class AddContractState {

  AppStatus? addStatus;
  AppStatus? fetchStatus;
  String? error;
  Contract? contract;
  int? id;
  Map<String,dynamic>? errors;
  List<Client>? clients;
  List<Owner>? owners;


  AddContractState({
    this.addStatus,
    this.error,
    this.contract,
    this.id,
    this.errors,
    this.owners,
    this.clients,
    this.fetchStatus
  });

  AddContractState copyWith({
    AppStatus? addStatus,
    AppStatus? fetchStatus,
    String? error,
    Contract? contract,
    int? id,
    Map<String, dynamic>? errors,
    List<Client>? clients,
    List<Owner>? owners,
  }) {
    return AddContractState(
      addStatus: addStatus ,
      error: error ,
      contract: contract ?? this.contract,
      id: id ?? this.id,
      errors: errors ,
      clients: clients??this.clients,
      owners: owners??this.owners,
      fetchStatus: fetchStatus??this.fetchStatus
    );
  }
}

