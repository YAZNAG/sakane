part of 'numero_campagnes_cubit.dart';

class NumeroCampagnesState {
  final AppStatus? fetchStatus;
  final AppStatus? actionStatus;
  final NumeroCampagnes? numero;

  /// Enregistrement ou retour au numero principal en cours.
  final bool enCours;
  final String? message;
  final String? error;

  NumeroCampagnesState({
    this.fetchStatus,
    this.actionStatus,
    this.numero,
    this.enCours = false,
    this.message,
    this.error,
  });

  NumeroCampagnesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    NumeroCampagnes? numero,
    bool? enCours,
    String? message,
    String? error,
  }) {
    return NumeroCampagnesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Un statut d'action n'est jamais conserve : il declenche un message.
      actionStatus: actionStatus,
      numero: numero ?? this.numero,
      enCours: enCours ?? false,
      message: message,
      error: error,
    );
  }
}
