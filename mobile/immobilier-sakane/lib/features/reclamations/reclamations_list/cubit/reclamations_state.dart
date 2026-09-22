part of 'reclamations_cubit.dart';

class ReclamationsState {
  final AppStatus? fetchStatus;
  final AppStatus? resolveStatus;
  final List<Reclamation>? reclamations;
  final String? error;
  final int? resolvingId;
  final int? realestateId;

  ReclamationsState({
    this.fetchStatus,
    this.resolveStatus,
    this.reclamations,
    this.error,
    this.resolvingId,
    this.realestateId,
  });

  ReclamationsState copyWith({
    AppStatus? fetchStatus,
    AppStatus? resolveStatus,
    List<Reclamation>? reclamations,
    String? error,
    int? resolvingId,
    int? realestateId,
  }) {
    return ReclamationsState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      resolveStatus: resolveStatus ?? this.resolveStatus,
      reclamations: reclamations ?? this.reclamations,
      error: error,
      resolvingId: resolvingId,
      realestateId: realestateId ?? this.realestateId,
    );
  }
}
