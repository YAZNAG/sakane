part of 'campagnes_cubit.dart';

/// Filtres de l'historique.
enum FiltreCampagnes { toutes, enCours, enPause, terminees, brouillons }

class CampagnesState {
  final AppStatus? fetchStatus;
  final AppStatus? actionStatus;
  final List<Campagne>? campagnes;
  final FiltreCampagnes filtre;

  /// Campagne dont une action (pause, reprise, suppression) est en cours.
  final int? actionId;
  final String? message;
  final String? error;

  CampagnesState({
    this.fetchStatus,
    this.actionStatus,
    this.campagnes,
    this.filtre = FiltreCampagnes.toutes,
    this.actionId,
    this.message,
    this.error,
  });

  /// Au moins une campagne avance ou va demarrer : la liste se rafraichit.
  bool get aSuivre => (campagnes ?? []).any((c) => c.estActive);

  static bool correspond(Campagne c, FiltreCampagnes filtre) {
    switch (filtre) {
      case FiltreCampagnes.toutes:
        return true;
      case FiltreCampagnes.enCours:
        return c.estLancee;
      case FiltreCampagnes.enPause:
        return c.estEnPause;
      case FiltreCampagnes.terminees:
        return c.estTerminee;
      case FiltreCampagnes.brouillons:
        return c.estBrouillon;
    }
  }

  List<Campagne> get campagnesFiltrees =>
      (campagnes ?? []).where((c) => correspond(c, filtre)).toList();

  int nombre(FiltreCampagnes f) =>
      (campagnes ?? []).where((c) => correspond(c, f)).length;

  CampagnesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    List<Campagne>? campagnes,
    FiltreCampagnes? filtre,
    int? actionId,
    String? message,
    String? error,
  }) {
    return CampagnesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Un statut d'action n'est jamais conserve : il declenche un message.
      actionStatus: actionStatus,
      campagnes: campagnes ?? this.campagnes,
      filtre: filtre ?? this.filtre,
      actionId: actionId,
      message: message,
      error: error,
    );
  }
}
