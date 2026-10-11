part of 'journal_nettoyage_cubit.dart';

class JournalNettoyageState {
  final AppStatus statut;
  final String? erreur;
  final JournalNettoyage? journal;

  final PeriodeActivite periode;
  final DateTime du;
  final DateTime au;

  /// Le nom de l'appartement ou de la personne cherché.
  final String recherche;

  /// L'appartement retenu ; nul pour tous.
  final int? bienId;

  /// La personne retenue ; nul pour tout le monde.
  final int? agentId;

  const JournalNettoyageState({
    this.statut = AppStatus.unknown,
    this.erreur,
    this.journal,
    required this.periode,
    required this.du,
    required this.au,
    this.recherche = '',
    this.bienId,
    this.agentId,
  });

  bool get enChargement => statut == AppStatus.loading;

  bool get premierChargement => enChargement && journal == null;

  /// Vrai quand un filtre autre que la période est actif : l'état vide le
  /// dit, pour qu'on sache quoi relâcher.
  bool get filtre =>
      recherche.trim().isNotEmpty || bienId != null || agentId != null;

  JournalNettoyageState copyWith({
    AppStatus? statut,
    String? erreur,
    bool effacerErreur = false,
    JournalNettoyage? journal,
    PeriodeActivite? periode,
    DateTime? du,
    DateTime? au,
    String? recherche,
    int? bienId,
    bool effacerBien = false,
    int? agentId,
    bool effacerAgent = false,
  }) {
    return JournalNettoyageState(
      statut: statut ?? this.statut,
      erreur: effacerErreur ? erreur : (erreur ?? this.erreur),
      journal: journal ?? this.journal,
      periode: periode ?? this.periode,
      du: du ?? this.du,
      au: au ?? this.au,
      recherche: recherche ?? this.recherche,
      bienId: effacerBien ? null : (bienId ?? this.bienId),
      agentId: effacerAgent ? null : (agentId ?? this.agentId),
    );
  }
}
