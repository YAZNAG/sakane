part of 'add_reclamation_cubit.dart';

class AddReclamationState {
  final AppStatus? addStatus;
  final String? error;
  final Map<String, dynamic>? errors;
  final Reclamation? reclamation;
  final int? realestateId;

  AddReclamationState({
    this.addStatus,
    this.error,
    this.errors,
    this.reclamation,
    this.realestateId,
  });

  AddReclamationState copyWith({
    AppStatus? addStatus,
    String? error,
    Map<String, dynamic>? errors,
    Reclamation? reclamation,
    int? realestateId,
  }) {
    return AddReclamationState(
      addStatus: addStatus ?? this.addStatus,
      error: error,
      errors: errors,
      reclamation: reclamation ?? this.reclamation,
      realestateId: realestateId ?? this.realestateId,
    );
  }
}
