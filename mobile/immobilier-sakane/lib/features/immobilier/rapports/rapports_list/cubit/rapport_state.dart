part of 'rapport_cubit.dart';



class RapportState {

  AppStatus? fetchDataStatus;
  String? error;
  List<Rapport>? rapports;
  int? id;

  RapportState({
    this.fetchDataStatus,
    this.error,
    this.rapports,
    this.id
  });

  RapportState copyWith({
    AppStatus? fetchDataStatus,
    String? error,
    List<Rapport>? rapports,
    int? id
  }) {
    return RapportState(
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      error: error ,
      rapports: rapports ?? this.rapports,
      id: id ?? this.id
    );
  }

}

