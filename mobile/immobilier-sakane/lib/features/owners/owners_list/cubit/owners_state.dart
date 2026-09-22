part of 'owners_cubit.dart';


class OwnersState {

  AppStatus? fetchStatus;
  AppStatus? deleteStatus;
  int? deletingId;
  String? error;
  String? query;
  List<Owner>? owners;
  List<Owner>? publicOwners;

  OwnersState({
    this.fetchStatus,
    this.deleteStatus,
    this.deletingId,
    this.error,
    this.owners,
    this.publicOwners,
    this.query
  });

  OwnersState copyWith({
    AppStatus? fetchStatus,
    AppStatus? deleteStatus,
    int? deletingId,
    String? error,
    List<Owner>? owners,
    List<Owner>? publicOwners,
    String? query
  }) {
    return OwnersState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      deleteStatus: deleteStatus,
      deletingId: deletingId ?? this.deletingId,
      error: error ?? this.error,
      owners: owners ?? this.owners,
      publicOwners: publicOwners ?? this.publicOwners,
      query: query ?? this.query
    );
  }

}

