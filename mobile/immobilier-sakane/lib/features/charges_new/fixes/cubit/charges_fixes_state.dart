part of 'charges_fixes_cubit.dart';

class ChargesFixesState {
  final AppStatus? fetchStatus;

  /// L'état de la dernière action : saisie, modification, échéance.
  final AppStatus? actionStatus;
  final String? error;

  final PeriodeActivite periode;
  final DateTime du;
  final DateTime au;

  /// La famille sur laquelle la liste est filtrée, null pour toutes.
  final String? famille;

  final ChargesFixes? donnees;
  final List<Realestate>? biens;

  const ChargesFixesState({
    required this.periode,
    required this.du,
    required this.au,
    this.fetchStatus,
    this.actionStatus,
    this.error,
    this.famille,
    this.donnees,
    this.biens,
  });

  /// Le mois en cours : c'est la période sur laquelle une charge fixe se lit.
  factory ChargesFixesState.initial() {
    final bornes = bornesActivite(PeriodeActivite.mois);
    final maintenant = DateTime.now();
    return ChargesFixesState(
      periode: PeriodeActivite.mois,
      du: DateTime(bornes.du.year, bornes.du.month, 1),
      au: DateTime(maintenant.year, maintenant.month + 1, 0),
    );
  }

  ChargesFixesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    String? error,
    PeriodeActivite? periode,
    DateTime? du,
    DateTime? au,
    String? famille,
    ChargesFixes? donnees,
    List<Realestate>? biens,

    /// Certaines valeurs doivent pouvoir redevenir nulles : un message
    /// d'erreur qui s'efface, un filtre que l'on retire.
    bool effacerErreur = false,
    bool effacerFamille = false,
  }) {
    return ChargesFixesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      actionStatus: actionStatus,
      error: effacerErreur ? error : (error ?? this.error),
      periode: periode ?? this.periode,
      du: du ?? this.du,
      au: au ?? this.au,
      famille: effacerFamille ? null : (famille ?? this.famille),
      donnees: donnees ?? this.donnees,
      biens: biens ?? this.biens,
    );
  }

  /// Vrai tant que rien n'est encore arrivé du serveur.
  bool get enAttente => fetchStatus == AppStatus.loading && donnees == null;

  bool get vide => (donnees?.familles.isEmpty ?? true) &&
      (donnees?.recurrences.isEmpty ?? true);
}
