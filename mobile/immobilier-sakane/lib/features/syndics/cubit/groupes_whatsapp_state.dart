part of 'groupes_whatsapp_cubit.dart';

class GroupesWhatsappState {
  final AppStatus? fetchStatus;

  /// L'état de la dernière action : ajout, renommage, suppression.
  final AppStatus? actionStatus;
  final String? error;
  final GroupesWhatsapp? donnees;

  const GroupesWhatsappState({
    this.fetchStatus,
    this.actionStatus,
    this.error,
    this.donnees,
  });

  GroupesWhatsappState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    String? error,
    GroupesWhatsapp? donnees,

    /// Un message d'erreur doit pouvoir redevenir nul.
    bool effacerErreur = false,
  }) {
    return GroupesWhatsappState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      actionStatus: actionStatus,
      error: effacerErreur ? null : (error ?? this.error),
      donnees: donnees ?? this.donnees,
    );
  }

  List<GroupeWhatsapp> get groupes => donnees?.groupes ?? const [];

  List<GroupeDisponible> get disponibles => donnees?.disponibles ?? const [];

  bool get enAttente => fetchStatus == AppStatus.loading && donnees == null;
}
