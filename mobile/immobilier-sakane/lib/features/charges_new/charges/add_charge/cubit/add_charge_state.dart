part of 'add_charge_cubit.dart';

class AddChargeState {
  final AppStatus? actionStatus;
  final String? error;
  final Map<String, dynamic>? errors;
  final int? realestate;

  /// Les appartements de l'agence : une charge peut se rattacher à
  /// l'un d'eux, ou rester une dépense de l'agence.
  final List<Realestate> biens;

  AddChargeState({
    this.actionStatus,
    this.error,
    this.errors,
    this.realestate,
    this.biens = const [],
  });

  AddChargeState copyWith({
    AppStatus? actionStatus,
    String? error,
    Map<String, dynamic>? errors,
    int? realestate,
    List<Realestate>? biens,

    /// Vrai pour revenir à une dépense de l'agence : sans quoi une
    /// valeur nulle laisserait l'appartement déjà choisi.
    bool sansBien = false,
  }) {
    return AddChargeState(
      actionStatus: actionStatus,
      error: error ?? this.error,
      errors: errors ?? this.errors,
      realestate: sansBien ? null : (realestate ?? this.realestate),
      biens: biens ?? this.biens
    );
  }
}