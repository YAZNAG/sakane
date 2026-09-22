part of 'charges_cubit.dart';

class ChargesState {
  final AppStatus? fetchStatus;
  final AppStatus? actionStatus;
  final AppStatus? deleteStatus;
  final int? deletingId;
  final String? error;
  final int? realestate;
  final Map<String, dynamic>? errors;
  final List<Charge>? charges;

  // filters
  final String? type;
  final String? status;
  final DateTime? from;
  final DateTime? to;

  /// Les charges affichées : "agence" (sans appartement), "all" (toutes),
  /// ou l'identifiant d'un appartement.
  final String bien;

  /// Les appartements proposés dans le filtre.
  final List<Realestate>? biens;

  ChargesState({
    this.fetchStatus,
    this.actionStatus,
    this.deleteStatus,
    this.deletingId,
    this.error,
    this.errors,
    this.charges,
    this.type,
    this.status,
    this.from,
    this.to,
    this.realestate,
    this.bien = "agence",
    this.biens,
  });

  ChargesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    AppStatus? deleteStatus,
    int? deletingId,
    String? error,
    Map<String, dynamic>? errors,
    List<Charge>? charges,
    String? type,
    String? status,
    DateTime? from,
    DateTime? to,
    int? realestate,
    String? bien,
    List<Realestate>? biens,
  }) {
    return ChargesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      actionStatus: actionStatus,
      deleteStatus: deleteStatus,
      deletingId: deletingId ?? this.deletingId,
      error: error ?? this.error,
      errors: errors ?? this.errors,
      charges: charges ?? this.charges,
      type: type ?? this.type,
      status: status ?? this.status,
      from: from ?? this.from,
      to: to ?? this.to,
      realestate: realestate ?? this.realestate,
      bien: bien ?? this.bien,
      biens: biens ?? this.biens,
    );
  }
}
