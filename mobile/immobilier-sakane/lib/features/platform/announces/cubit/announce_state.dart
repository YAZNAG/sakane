part of 'announce_cubit.dart';


class AnnounceState {

  AppStatus? fetchDataStatus;
  AppStatus? actionStatus;
  String? error;
  List<Realestate>? annouces;

  AnnounceState({
    this.fetchDataStatus,
    this.actionStatus,
    this.error,
    this.annouces,
  });

  AnnounceState copyWith({
    AppStatus? fetchDataStatus,
    AppStatus? actionStatus,
    String? error,
    List<Realestate>? annouces,
  }) {
    return AnnounceState(
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      actionStatus: actionStatus ,
      error: error ,
      annouces: annouces ?? this.annouces,
    );
  }
}

