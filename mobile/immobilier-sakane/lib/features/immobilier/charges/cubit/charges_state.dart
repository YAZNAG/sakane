part of 'charges_cubit.dart';



class ChargesState {

  AppStatus? fetchStatus;
  AppStatus? addStatus;
  AppStatus? deleteStatus;
  int? deletingId;
  String? error;
  List<Charge>? charges;
  int? id;
  Map<String,dynamic>? errors;
  DateTime? from;
  DateTime? to;

  ChargesState({
    this.fetchStatus,
    this.addStatus,
    this.deleteStatus,
    this.deletingId,
    this.error,
    this.charges,
    this.id,
    this.errors,
    this.from,
    this.to,
  });

  ChargesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? addStatus,
    AppStatus? deleteStatus,
    int? deletingId,
    String? error,
    List<Charge>? charges,
    int? id,
    Map<String, dynamic>? errors,
    DateTime? from,
    DateTime? to,
  }) {
    return ChargesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      addStatus: addStatus,
      deleteStatus: deleteStatus,
      deletingId: deletingId ?? this.deletingId,
      error: error,
      charges: charges ?? this.charges,
      id: id ?? this.id,
      errors: errors,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}

