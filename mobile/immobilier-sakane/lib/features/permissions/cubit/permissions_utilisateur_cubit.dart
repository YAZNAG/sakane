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

part 'permissions_utilisateur_state.dart';

/// Les droits d'un utilisateur, un par un : hérités de son rôle,
/// accordés en plus ou retirés.
///
/// Comme pour les rôles, les changements restent locaux jusqu'à
/// « Enregistrer ».
class PermissionsUtilisateurCubit extends Cubit<PermissionsUtilisateurState> {
  PermissionsUtilisateurCubit({
    required UtilisateurPermissions utilisateur,
    required List<ModulePermissions> modules,
  }) : super(PermissionsUtilisateurState(
          utilisateur: utilisateur,
          modules: modules,
        ));

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading, effacerErreur: true));
      final detail =
          await _repository.fetchPermissionsUtilisateur(state.utilisateur.id);
      _appliquer(detail, fetchStatus: AppStatus.success);
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
    if (state.detail == null) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: message));
    } else {
      emit(state.copyWith(
          fetchStatus: AppStatus.success,
          saveStatus: AppStatus.error,
          error: message));
    }
  }

  /// Choisit l'état d'un droit. Accordé et retiré s'excluent toujours.
  void definir(String code, EtatDroitUtilisateur etat) {
    if (!state.modifiable) return;
    final accordes = Set<String>.from(state.accordes)..remove(code);
    final retires = Set<String>.from(state.retires)..remove(code);
    switch (etat) {
      case EtatDroitUtilisateur.accorde:
        accordes.add(code);
      case EtatDroitUtilisateur.retire:
        retires.add(code);
      case EtatDroitUtilisateur.role:
        break;
    }
    emit(state.copyWith(
        accordes: accordes, retires: retires, effacerErreur: true));
  }

  /// Revient entièrement au rôle : plus rien d'accordé ni de retiré.
  void reinitialiser() {
    if (!state.modifiable) return;
    emit(state.copyWith(
        accordes: const {}, retires: const {}, effacerErreur: true));
  }

  /// Oublie les changements non enregistrés.
  void annuler() {
    final detail = state.detail;
    if (detail == null) return;
    emit(state.copyWith(
      accordes: detail.listeAccordes,
      retires: detail.listeRetires,
      effacerErreur: true,
    ));
  }

  Future<void> enregistrer() async {
    if (!state.modifiable || !state.modifie) return;
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading, effacerErreur: true));
      final detail = await _repository.majPermissionsUtilisateur(
        state.utilisateur.id,
        state.accordes.toList()..sort(),
        state.retires.toList()..sort(),
      );
      _appliquer(
        detail,
        saveStatus: AppStatus.success,
        message: "Droits enregistrés pour ${state.utilisateur.nom}",
      );
    } on UnAuthenticatedException {
      logout();
    } catch (ex) {
      emit(state.copyWith(saveStatus: AppStatus.error, error: _message(ex)));
    }
  }

  void _appliquer(
    DetailUtilisateurPermissions detail, {
    AppStatus? fetchStatus,
    AppStatus? saveStatus,
    String? message,
  }) {
    // Le détail peut revenir sans nom ni rôles : on garde ceux de la liste.
    final recu = detail.utilisateur;
    final base = state.utilisateur;
    final utilisateur = UtilisateurPermissions(
      id: base.id,
      nom: recu.nom.isEmpty || recu.nom.startsWith('Utilisateur #')
          ? base.nom
          : recu.nom,
      roles: recu.roles.isEmpty ? base.roles : recu.roles,
      rolesLibelles:
          recu.rolesLibelles.isEmpty ? base.rolesLibelles : recu.rolesLibelles,
      admin: recu.admin || base.admin,
      modifiable: recu.modifiable && base.modifiable,
      accordes: detail.listeAccordes.length,
      retires: detail.listeRetires.length,
      personnalise: !(recu.admin || base.admin) &&
          detail.listeAccordes.length + detail.listeRetires.length > 0,
    );
    emit(state.copyWith(
      fetchStatus: fetchStatus,
      saveStatus: saveStatus,
      utilisateur: utilisateur,
      detail: detail,
      accordes: detail.listeAccordes,
      retires: detail.listeRetires,
      message: message,
      effacerErreur: true,
    ));
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
