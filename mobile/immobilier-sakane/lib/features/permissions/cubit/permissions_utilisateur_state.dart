part of 'permissions_utilisateur_cubit.dart';

class PermissionsUtilisateurState {
  final AppStatus? fetchStatus;
  final AppStatus? saveStatus;

  /// La ligne de l'utilisateur (mise à jour après enregistrement).
  final UtilisateurPermissions utilisateur;

  /// L'arborescence des droits, reprise de l'écran principal.
  final List<ModulePermissions> modules;

  /// Ce que le serveur connaît pour cet utilisateur.
  final DetailUtilisateurPermissions? detail;

  /// Les droits accordés / retirés à l'écran, pas encore envoyés.
  final Set<String> accordes;
  final Set<String> retires;

  final String? message;
  final String? error;

  const PermissionsUtilisateurState({
    required this.utilisateur,
    required this.modules,
    this.fetchStatus,
    this.saveStatus,
    this.detail,
    this.accordes = const {},
    this.retires = const {},
    this.message,
    this.error,
  });

  /// Un administrateur se consulte mais ne se règle pas.
  bool get modifiable => !utilisateur.verrouille && detail != null;

  bool get enregistrement => saveStatus == AppStatus.loading;

  Set<String> get parRole => detail?.parRole ?? const {};

  /// Le nombre total de droits proposés.
  int get total => modules.fold(0, (t, m) => t + m.permissions.length);

  EtatDroitUtilisateur etat(String code) {
    if (accordes.contains(code)) return EtatDroitUtilisateur.accorde;
    if (retires.contains(code)) return EtatDroitUtilisateur.retire;
    return EtatDroitUtilisateur.role;
  }

  /// Le résultat final : ce que l'utilisateur pourra faire.
  bool effectif(String code) {
    if (utilisateur.verrouille) return true;
    switch (etat(code)) {
      case EtatDroitUtilisateur.accorde:
        return true;
      case EtatDroitUtilisateur.retire:
        return false;
      case EtatDroitUtilisateur.role:
        return parRole.contains(code);
    }
  }

  bool personnalise(String code) =>
      accordes.contains(code) || retires.contains(code);

  int effectifsParmi(Iterable<String> codes) => codes.where(effectif).length;

  int personnalisesParmi(Iterable<String> codes) =>
      codes.where(personnalise).length;

  int get nombreEffectifs =>
      modules.fold(0, (t, m) => t + effectifsParmi(m.codes));

  /// Vrai dès qu'un droit a changé d'état sans être enregistré.
  bool get modifie {
    final d = detail;
    if (d == null || !modifiable) return false;
    return !_egaux(d.listeAccordes, accordes) ||
        !_egaux(d.listeRetires, retires);
  }

  /// Les droits que l'utilisateur perdrait en enregistrant.
  Set<String> get perdus {
    final d = detail;
    if (d == null) return const {};
    bool avant(String code) {
      if (d.listeAccordes.contains(code)) return true;
      if (d.listeRetires.contains(code)) return false;
      return parRole.contains(code);
    }

    return modules
        .expand((m) => m.codes)
        .where((c) => avant(c) && !effectif(c))
        .toSet();
  }

  static bool _egaux(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  PermissionsUtilisateurState copyWith({
    AppStatus? fetchStatus,
    AppStatus? saveStatus,
    UtilisateurPermissions? utilisateur,
    DetailUtilisateurPermissions? detail,
    Set<String>? accordes,
    Set<String>? retires,
    String? message,
    String? error,
    bool effacerErreur = false,
  }) {
    return PermissionsUtilisateurState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Le statut d'enregistrement déclenche un message : il ne se garde pas.
      saveStatus: saveStatus,
      utilisateur: utilisateur ?? this.utilisateur,
      modules: modules,
      detail: detail ?? this.detail,
      accordes: accordes ?? this.accordes,
      retires: retires ?? this.retires,
      message: message,
      error: effacerErreur ? null : (error ?? this.error),
    );
  }
}
