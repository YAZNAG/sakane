import 'dart:async';

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

part 'detail_campagne_state.dart';

class DetailCampagneCubit extends Cubit<DetailCampagneState> {
  DetailCampagneCubit(this.id) : super(DetailCampagneState());

  final int id;
  Timer? _rafraichissement;

  /// Vrai quand l'application passe en arriere-plan.
  bool _suiviSuspendu = false;
  bool _chargementDiscret = false;

  Repository get _repository => Dependencies.get<Repository>();

  @override
  Future<void> close() {
    _rafraichissement?.cancel();
    return super.close();
  }

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final campagne = await _repository.fetchCampagne(id);
      emit(state.copyWith(
          fetchStatus: AppStatus.success, campagne: campagne));
      _suivreAvancement(campagne);
    } on NetworkConnectivityException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      emit(state.copyWith(
          fetchStatus: AppStatus.error,
          error: "Impossible de charger la campagne"));
    }
  }

  /// Mise a jour sans ecran d'attente : tirer pour rafraichir, suivi auto.
  Future<void> rafraichir() async {
    if (_chargementDiscret || isClosed) return;
    if (state.campagne == null) return charger();
    _chargementDiscret = true;
    try {
      final maj = await _repository.fetchCampagne(id);
      if (isClosed) return;
      // Une action peut etre en cours : son attente reste affichee.
      emit(state.copyWith(
          fetchStatus: AppStatus.success, campagne: maj, action: state.action));
      _suivreAvancement(maj);
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      // Reseau indisponible : on retente au prochain tour.
      if (state.campagne != null) _suivreAvancement(state.campagne!);
    } finally {
      _chargementDiscret = false;
    }
  }

  /// Tant que l'envoi avance (2 messages par minute, cote serveur),
  /// l'ecran se met a jour tout seul. Une campagne programmee est
  /// surveillee plus lentement, pour voir son demarrage.
  void _suivreAvancement(Campagne campagne) {
    _rafraichissement?.cancel();
    _rafraichissement = null;
    if (_suiviSuspendu || isClosed || !campagne.estActive) return;

    final delai = campagne.estLancee
        ? const Duration(seconds: 10)
        : const Duration(seconds: 30);
    _rafraichissement = Timer(delai, rafraichir);
  }

  /// Application en arriere-plan : on arrete d'interroger le serveur.
  void suspendreSuivi() {
    _suiviSuspendu = true;
    _rafraichissement?.cancel();
    _rafraichissement = null;
  }

  void reprendreSuivi() {
    if (!_suiviSuspendu) return;
    _suiviSuspendu = false;
    if (state.campagne?.estActive ?? false) rafraichir();
  }

  Future<void> lancer() => _action('lancer',
      () => _repository.lancerCampagne(id), "L'envoi a démarré");

  Future<void> pause() => _action('pause',
      () => _repository.pauseCampagne(id), "Campagne mise en pause");

  Future<void> reprendre() => _action('reprendre',
      () => _repository.reprendreCampagne(id), "L'envoi reprend");

  Future<void> annuler() => _action('annuler',
      () => _repository.annulerCampagne(id), "La campagne a été annulée");

  Future<void> relancerEchecs() => _action(
      'relancer',
      () => _repository.relancerEchecsCampagne(id),
      "Les envois en échec ont été remis en file");

  Future<void> supprimer() async {
    try {
      emit(state.copyWith(action: 'supprimer'));
      await _repository.supprimerCampagne(id);
      _rafraichissement?.cancel();
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        supprimee: true,
        message: "Campagne supprimée",
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _erreur(ex)));
    }
  }

  /// Envoie le message de la campagne a un seul numero, pour verifier.
  Future<void> envoyerTest(String telephone) async {
    final c = state.campagne;
    if (c == null) return;
    try {
      emit(state.copyWith(action: 'test'));
      await _repository.envoyerTestCampagne(
        telephone: telephone,
        message: c.message ?? '',
        lien: c.lien,
        campagneId: c.id,
      );
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: "Message test envoyé. Vérifiez votre WhatsApp.",
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _erreur(ex)));
    }
  }

  Future<void> _action(String action, Future<Campagne> Function() operation,
      String message) async {
    try {
      emit(state.copyWith(action: action));
      await operation();
      // On recharge le detail complet : les destinataires ont change.
      final campagne = await _repository.fetchCampagne(id);
      if (isClosed) return;
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        fetchStatus: AppStatus.success,
        campagne: campagne,
        message: message,
      ));
      _suivreAvancement(campagne);
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(actionStatus: AppStatus.error, error: _erreur(ex)));
      // Le statut a pu changer entre-temps (fin d'envoi, autre appareil).
      rafraichir();
    }
  }

  String _erreur(Object ex) {
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
