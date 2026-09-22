part of 'modeles_messages_cubit.dart';

class ModelesMessagesState {
  final AppStatus? fetchStatus;
  final AppStatus? detailStatus;
  final AppStatus? apercuStatus;
  final AppStatus? saveStatus;

  final List<ModeleMessage>? modeles;
  final List<VariableModele>? variables;
  final ModeleMessage? courant;
  final ApercuModele? apercuRendu;
  final String? message;
  final String? error;

  ModelesMessagesState({
    this.fetchStatus,
    this.detailStatus,
    this.apercuStatus,
    this.saveStatus,
    this.modeles,
    this.variables,
    this.courant,
    this.apercuRendu,
    this.message,
    this.error,
  });

  /// Modèles regroupés par catégorie, dans l'ordre d'affichage.
  Map<String, List<ModeleMessage>> get parCategorie {
    final groupes = <String, List<ModeleMessage>>{};
    for (final m in modeles ?? <ModeleMessage>[]) {
      groupes.putIfAbsent(m.categorieLisible, () => []).add(m);
    }
    return groupes;
  }

  ModelesMessagesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? detailStatus,
    AppStatus? apercuStatus,
    AppStatus? saveStatus,
    List<ModeleMessage>? modeles,
    List<VariableModele>? variables,
    ModeleMessage? courant,
    ApercuModele? apercuRendu,
    String? message,
    String? error,
  }) {
    return ModelesMessagesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Les statuts d'action declenchent un message : ils ne se conservent pas.
      detailStatus: detailStatus,
      apercuStatus: apercuStatus,
      saveStatus: saveStatus,
      modeles: modeles ?? this.modeles,
      variables: variables ?? this.variables,
      courant: courant ?? this.courant,
      apercuRendu: apercuRendu ?? this.apercuRendu,
      message: message,
      error: error,
    );
  }
}
