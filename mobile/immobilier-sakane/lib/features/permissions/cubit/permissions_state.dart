part of 'permissions_cubit.dart';

class PermissionsState {
  final AppStatus? fetchStatus;
  final AppStatus? saveStatus;

  final DroitsEtPermissions? donnees;

  /// Le rôle affiché ; null tant que rien n'est chargé.
  final String? roleChoisi;

  /// Les droits cochés à l'écran, pas encore envoyés au serveur.
  final Set<String> selection;

  final String? message;
  final String? error;

  const PermissionsState({
    this.fetchStatus,
    this.saveStatus,
    this.donnees,
    this.roleChoisi,
    this.selection = const {},
    this.message,
    this.error,
  });

  List<ModulePermissions> get modules => donnees?.modules ?? const [];

  List<RolePermissions> get roles => donnees?.roles ?? const [];

  List<UtilisateurPermissions> get utilisateurs =>
      donnees?.utilisateurs ?? const [];

  RolePermissions? get roleCourant => donnees?.role(roleChoisi);

  /// Les droits du rôle tels que le serveur les connaît.
  Set<String> get selectionServeur {
    final role = roleCourant;
    if (role == null || donnees == null) return const {};
    final connus = donnees!.codesConnus;
    return role.permissions.where(connus.contains).toSet();
  }

  bool get enregistrement => saveStatus == AppStatus.loading;

  /// Vrai dès qu'un droit a été coché ou décoché sans être enregistré.
  bool get modifie {
    final role = roleCourant;
    if (role == null || !role.modifiableIci) return false;
    final serveur = selectionServeur;
    if (serveur.length != selection.length) return true;
    return !serveur.containsAll(selection);
  }

  /// Les droits que l'enregistrement retirerait au rôle.
  Set<String> get retires =>
      selectionServeur.where((c) => !selection.contains(c)).toSet();

  /// Les droits que l'enregistrement ajouterait au rôle.
  Set<String> get ajoutes =>
      selection.where((c) => !selectionServeur.contains(c)).toSet();

  /// Le nombre de droits cochés dans un module.
  int coches(ModulePermissions module) => cochesParmi(module.codes);

  /// Le nombre de droits cochés parmi une liste de codes.
  int cochesParmi(Iterable<String> codes) =>
      codes.where(estCoche).length;

  /// L'administrateur garde tous les droits : tout apparaît coché.
  bool estCoche(String code) =>
      (roleCourant?.estAdministrateur ?? false) || selection.contains(code);

  PermissionsState copyWith({
    AppStatus? fetchStatus,
    AppStatus? saveStatus,
    DroitsEtPermissions? donnees,
    String? roleChoisi,
    Set<String>? selection,
    String? message,
    String? error,
    bool effacerErreur = false,
  }) {
    return PermissionsState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Le statut d'enregistrement declenche un message : il ne se garde pas.
      saveStatus: saveStatus,
      donnees: donnees ?? this.donnees,
      roleChoisi: roleChoisi ?? this.roleChoisi,
      selection: selection ?? this.selection,
      message: message,
      error: effacerErreur ? null : (error ?? this.error),
    );
  }
}
