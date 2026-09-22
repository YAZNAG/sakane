import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/permissions_roles.dart';
import 'package:immobilier/repository/repository.dart';

part 'permissions_state.dart';

/// Les droits de chaque rôle, module par module.
///
/// Les changements restent locaux jusqu'à « Enregistrer » : on compare
/// toujours la sélection en cours à celle du serveur pour savoir ce qui
/// est ajouté et ce qui est retiré.
class PermissionsCubit extends Cubit<PermissionsState> {
  PermissionsCubit() : super(const PermissionsState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading, effacerErreur: true));
      final donnees = await _repository.fetchDroitsPermissions();
      // On garde le rôle affiché si le serveur le connaît toujours.
      final courant = donnees.role(state.roleChoisi)?.nom ??
          _premierRole(donnees)?.nom;
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        donnees: donnees,
        roleChoisi: courant,
        selection: _depuisServeur(donnees, courant),
        effacerErreur: true,
      ));
    } on NetworkConnectivityException {
      _echecChargement(AppStrings.checkConnectivity);
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      _echecChargement("Seuls les administrateurs peuvent gérer les droits.");
    } catch (ex) {
      _echecChargement(_message(ex));
    }
  }

  /// Sans données, l'écran affiche l'erreur ; sinon il garde ce qu'il
  /// montre et l'erreur passe en message.
  void _echecChargement(String message) {
    if (state.donnees == null) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: message));
    } else {
      emit(state.copyWith(
          fetchStatus: AppStatus.success,
          saveStatus: AppStatus.error,
          error: message));
    }
  }

  /// Change de rôle : la sélection repart de ce que le serveur connaît.
  void choisirRole(String nom) {
    if (nom == state.roleChoisi) return;
    emit(state.copyWith(
      roleChoisi: nom,
      selection: _depuisServeur(state.donnees, nom),
      effacerErreur: true,
    ));
  }

  /// Coche ou décoche un droit du rôle affiché.
  void basculer(String code, bool actif) {
    final role = state.roleCourant;
    if (role == null || !role.modifiableIci) return;
    final selection = Set<String>.from(state.selection);
    if (actif) {
      selection.add(code);
    } else {
      selection.remove(code);
    }
    emit(state.copyWith(selection: selection, effacerErreur: true));
  }

  /// « Tout activer » / « tout désactiver » sur un module.
  void basculerModule(ModulePermissions module, bool actif) =>
      basculerCodes(module.codes, actif);

  /// Active ou désactive d'un coup un groupe de droits (module,
  /// sous-module ou résultat de recherche).
  void basculerCodes(Iterable<String> codes, bool actif) {
    final role = state.roleCourant;
    if (role == null || !role.modifiableIci) return;
    final selection = Set<String>.from(state.selection);
    if (actif) {
      selection.addAll(codes);
    } else {
      selection.removeAll(codes);
    }
    emit(state.copyWith(selection: selection, effacerErreur: true));
  }

  /// Met à jour la ligne d'un utilisateur après l'enregistrement de ses
  /// droits dans l'écran de détail.
  void majUtilisateur(UtilisateurPermissions utilisateur) {
    final donnees = state.donnees;
    if (donnees == null) return;
    emit(state.copyWith(donnees: donnees.avecUtilisateur(utilisateur)));
  }

  /// Revient à ce que le serveur a enregistré pour ce rôle.
  void annuler() {
    emit(state.copyWith(
      selection: _depuisServeur(state.donnees, state.roleChoisi),
      effacerErreur: true,
    ));
  }

  Future<void> enregistrer() async {
    final role = state.roleCourant;
    if (role == null || !role.modifiableIci || !state.modifie) return;
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading, effacerErreur: true));
      final maj = await _repository.majPermissionsRole(
          role.nom, state.selection.toList()..sort());
      final donnees = state.donnees?.avecRole(maj);
      emit(state.copyWith(
        saveStatus: AppStatus.success,
        donnees: donnees,
        selection: _depuisServeur(donnees, role.nom),
        message: "Droits enregistrés pour « ${role.libelle} »",
      ));
    } on UnAuthenticatedException {
      logout();
    } catch (ex) {
      emit(state.copyWith(saveStatus: AppStatus.error, error: _message(ex)));
    }
  }

  static RolePermissions? _premierRole(DroitsEtPermissions donnees) {
    if (donnees.roles.isEmpty) return null;
    // On ouvre sur un rôle réellement modifiable quand il y en a un.
    for (final r in donnees.roles) {
      if (r.modifiableIci) return r;
    }
    return donnees.roles.first;
  }

  /// Les droits du rôle côté serveur, réduits aux codes encore connus.
  static Set<String> _depuisServeur(DroitsEtPermissions? donnees, String? nom) {
    final role = donnees?.role(nom);
    if (donnees == null || role == null) return <String>{};
    final connus = donnees.codesConnus;
    return role.permissions.where(connus.contains).toSet();
  }

  String _message(Object ex) {
    if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
    if (ex is UnAuthorizedException) {
      return "Seuls les administrateurs peuvent modifier les droits.";
    }
    final texte = ex.toString().replaceFirst('Exception: ', '').trim();
    return texte.isEmpty ? "L'opération n'a pas abouti" : texte;
  }
}
