part of 'owner_detail_cubit.dart';


class OwnerDetailState {

  int? id;
  Owner? owner;
  AppStatus? fetchStatus;
  String? error;

  /// Statut de la dernière action (joindre / supprimer un contrat).
  /// Il ne se conserve pas d'un emit à l'autre.
  AppStatus? actionStatus;
  String? actionMessage;
  String? actionError;

  OwnerDetailState({
    this.id,
    this.owner,
    this.fetchStatus,
    this.error,
    this.actionStatus,
    this.actionMessage,
    this.actionError,
  });

  OwnerDetailState copyWith({
    int? id,
    Owner? owner,
    AppStatus? fetchStatus,
    String? error,
    AppStatus? actionStatus,
    String? actionMessage,
    String? actionError,
  }) {
    return OwnerDetailState(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      fetchStatus: fetchStatus ?? this.fetchStatus,
      error: error ?? this.error,
      actionStatus: actionStatus,
      actionMessage: actionMessage,
      actionError: actionError,
    );
  }

}
