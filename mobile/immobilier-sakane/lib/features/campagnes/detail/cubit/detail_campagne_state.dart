part of 'detail_campagne_cubit.dart';

class DetailCampagneState {
  final AppStatus? fetchStatus;
  final AppStatus? actionStatus;
  final Campagne? campagne;

  /// Action en cours : lancer | pause | reprendre | annuler | relancer |
  /// supprimer | test. Sert a afficher l'attente sur le bon bouton.
  final String? action;

  /// La campagne vient d'etre supprimee : l'ecran se ferme.
  final bool supprimee;
  final String? message;
  final String? error;

  DetailCampagneState({
    this.fetchStatus,
    this.actionStatus,
    this.campagne,
    this.action,
    this.supprimee = false,
    this.message,
    this.error,
  });

  DetailCampagneState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    Campagne? campagne,
    String? action,
    bool? supprimee,
    String? message,
    String? error,
  }) {
    return DetailCampagneState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Un statut d'action declenche un message : il ne se conserve pas.
      actionStatus: actionStatus,
      campagne: campagne ?? this.campagne,
      action: action,
      supprimee: supprimee ?? this.supprimee,
      message: message,
      error: error,
    );
  }
}
