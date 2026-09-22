import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/features/campagnes/commun/campagne_ui.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:immobilier/repository/repository.dart';

part 'campagnes_state.dart';

class CampagnesCubit extends Cubit<CampagnesState> {
  CampagnesCubit() : super(CampagnesState());

  Repository get _repository => Dependencies.get<Repository>();

  bool _rafraichissementEnCours = false;

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final campagnes = await _repository.fetchCampagnes();
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        campagnes: campagnes,
      ));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: AppStrings.authorizationError));
    } catch (_) {
      emit(state.copyWith(
          fetchStatus: AppStatus.error,
          error: "Impossible de charger les campagnes"));
    }
  }

  /// Mise a jour discrete (tirer pour rafraichir, suivi automatique) :
  /// la liste reste affichee pendant le chargement.
  Future<void> rafraichir() async {
    if (_rafraichissementEnCours || isClosed) return;
    if (state.campagnes == null) return charger();
    _rafraichissementEnCours = true;
    try {
      final campagnes = await _repository.fetchCampagnes();
      if (!isClosed) {
        emit(state.copyWith(
            fetchStatus: AppStatus.success,
            campagnes: campagnes,
            actionId: state.actionId));
      }
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      // Reseau indisponible : la prochaine tentative suffira.
    } finally {
      _rafraichissementEnCours = false;
    }
  }

  void filtrer(FiltreCampagnes filtre) =>
      emit(state.copyWith(filtre: filtre, actionId: state.actionId));

  Future<void> pause(int id) => _action(id, () => _repository.pauseCampagne(id),
      "Campagne mise en pause");

  Future<void> reprendre(int id) => _action(
      id, () => _repository.reprendreCampagne(id), "L'envoi reprend");

  Future<void> _action(
      int id, Future<Campagne> Function() operation, String message) async {
    try {
      emit(state.copyWith(actionId: id));
      final maj = await operation();
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: message,
        campagnes: state.campagnes
            ?.map((c) => c.id == id ? maj : c)
            .toList(),
      ));
      // Les compteurs exacts arrivent avec la liste complete.
      rafraichir();
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
      // Le statut a pu changer entre-temps (fin d'envoi, autre appareil).
      rafraichir();
    }
  }

  Future<void> supprimer(int id) async {
    try {
      emit(state.copyWith(actionId: id));
      await _repository.supprimerCampagne(id);
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: "Campagne supprimée",
        campagnes: state.campagnes?.where((c) => c.id != id).toList(),
      ));
    } catch (ex) {
      emit(state.copyWith(
          actionStatus: AppStatus.error, error: _message(ex)));
    }
  }

  String _message(Object ex) {
    if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
    if (ex is UnAuthenticatedException) {
      logout();
      return AppStrings.authorizationError;
    }
    if (ex is UnAuthorizedException) return AppStrings.authorizationError;
    if (ex is ValidatorException) {
      return CampagneUi.premiereErreur(ex.errors, "L'opération n'a pas abouti");
    }
    return "L'opération n'a pas abouti";
  }
}
