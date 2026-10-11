part of 'activite_agents_cubit.dart';

class ActiviteAgentsState {
  final AppStatus statut;
  final String? erreur;
  final ActiviteAgents? activite;

  final PeriodeActivite periode;
  final DateTime du;
  final DateTime au;
  final GroupeActivite groupe;

  /// Les agents dont le détail par tranche est déplié.
  final Set<int> agentsOuverts;

  const ActiviteAgentsState({
    this.statut = AppStatus.unknown,
    this.erreur,
    this.activite,
    required this.periode,
    required this.du,
    required this.au,
    this.groupe = GroupeActivite.jour,
    this.agentsOuverts = const {},
  });

  bool get enChargement => statut == AppStatus.loading;

  /// Vrai pendant la toute première lecture : l'écran montre alors son
  /// squelette plutôt qu'une page vide.
  bool get premierChargement => enChargement && activite == null;

  ActiviteAgentsState copyWith({
    AppStatus? statut,
    String? erreur,
    bool effacerErreur = false,
    ActiviteAgents? activite,
    PeriodeActivite? periode,
    DateTime? du,
    DateTime? au,
    GroupeActivite? groupe,
    Set<int>? agentsOuverts,
  }) {
    return ActiviteAgentsState(
      statut: statut ?? this.statut,
      erreur: effacerErreur ? erreur : (erreur ?? this.erreur),
      activite: activite ?? this.activite,
      periode: periode ?? this.periode,
      du: du ?? this.du,
      au: au ?? this.au,
      groupe: groupe ?? this.groupe,
      agentsOuverts: agentsOuverts ?? this.agentsOuverts,
    );
  }
}
