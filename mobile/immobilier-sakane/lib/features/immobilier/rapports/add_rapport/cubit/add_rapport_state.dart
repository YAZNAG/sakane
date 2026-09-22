part of 'add_rapport_cubit.dart';



class AddRapportState {

  AppStatus? addStatus;
  String? error;
  Map<String,dynamic>? errors;
  Rapport? rapport;
  int? id;


  AddRapportState({
    this.addStatus,
    this.error,
    this.errors,
    this.rapport,
    this.id
  });

  AddRapportState copyWith({
    AppStatus? addStatus,
    String? error,
    Map<String, dynamic>? errors,
    Rapport? rapport,
    int? id
  }) {
    return AddRapportState(
      addStatus: addStatus ?? this.addStatus,
      error: error ,
      errors: errors ,
      rapport: rapport ?? this.rapport,
      id: id ?? this.id
    );
  }

}


