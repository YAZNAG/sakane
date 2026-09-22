part of 'contract_cubit.dart';



class ContractState {

  AppStatus? fetchStatus;
  String? error;
  List<Contract>? contracts;
  int? id;

  ContractState({
    this.fetchStatus,
    this.error,
    this.contracts,
    this.id,
  });

  ContractState copyWith({
    AppStatus? fetchStatus,
    String? error,
    List<Contract>? contracts,
    int? id,
  }) {
    return ContractState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      error: error ?? this.error,
      contracts: contracts ?? this.contracts,
      id: id ?? this.id,
    );
  }

}

