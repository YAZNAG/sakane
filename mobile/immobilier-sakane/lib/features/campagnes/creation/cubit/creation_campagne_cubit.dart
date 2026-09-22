import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/exceptions/validation_exception.dart';
import 'package:immobilier/models/campagne.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/models/client.dart';

part 'creation_campagne_state.dart';

class CreationCampagneCubit extends Cubit<CreationCampagneState> {
  CreationCampagneCubit() : super(CreationCampagneState());

  Repository get _repository => Dependencies.get<Repository>();

  /// Charge les segments proposes et la liste des biens, necessaire au
  /// segment "clients ayant séjourné dans un bien".
  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final resultats = await Future.wait([
        _repository.fetchSegmentsCampagne(),
        _repository.getRealestates(),
        // La liste des clients alimente la selection manuelle.
        _repository.getClients(),
      ]);
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        segments: resultats[0] as List<Map<String, String>>,
        biens: resultats[1] as List<Realestate>,
        clients: resultats[2] as List<Client>,
      ));
      estimer();
    } on NetworkConnectivityException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      emit(state.copyWith(
          fetchStatus: AppStatus.error,
          error: "Impossible de préparer la campagne"));
    }
  }

  void majSegment(SegmentClients segment) {
    emit(state.copyWith(segment: segment));
    estimer();
  }

  /// Combien de clients recevront le message, et combien sont exclus
  /// parce qu'ils refusent les messages promotionnels.
  Future<void> estimer() async {
    try {
      emit(state.copyWith(estimationStatus: AppStatus.loading));
      final estimation = await _repository.estimerSegment(state.segment);
      emit(state.copyWith(
        estimationStatus: AppStatus.success,
        estimation: estimation,
      ));
    } catch (_) {
      emit(state.copyWith(estimationStatus: AppStatus.error));
    }
  }

  void choisirImage(File? image) => emit(state.copyWith(image: image, effacerImage: image == null));

  /// Envoi test vers un numero, sans consommer la campagne.
  Future<void> envoyerTest({
    required String telephone,
    required String message,
    String? lien,
  }) async {
    try {
      emit(state.copyWith(testStatus: AppStatus.loading));
      await _repository.envoyerTestCampagne(
        telephone: telephone,
        message: message,
        lien: lien,
      );
      emit(state.copyWith(testStatus: AppStatus.success));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          testStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on ValidatorException catch (ex) {
      // Le motif exact du refus est bien plus utile qu'un message general.
      emit(state.copyWith(
          testStatus: AppStatus.error, error: _premiereErreur(ex.errors)));
    } catch (_) {
      emit(state.copyWith(
          testStatus: AppStatus.error, error: "L'envoi test n'a pas abouti"));
    }
  }

  /// [quand] : null pour un brouillon, une date pour un envoi programme.
  /// [maintenant] declenche l'envoi immediat.
  Future<void> enregistrer({
    required String titre,
    required String message,
    String? lien,
    DateTime? quand,
    bool maintenant = false,
  }) async {
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading));

      final campagne = Campagne(
        titre: titre,
        message: message,
        lien: lien,
        image: state.image,
        segment: state.segment,
        planifieeA: quand,
      );

      await _repository.addCampagne(campagne, envoyerMaintenant: maintenant);
      emit(state.copyWith(saveStatus: AppStatus.success));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          saveStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(
          saveStatus: AppStatus.error, error: AppStrings.authorizationError));
    } on ValidatorException catch (ex) {
      emit(state.copyWith(
          saveStatus: AppStatus.error, error: _premiereErreur(ex.errors)));
    } catch (_) {
      emit(state.copyWith(
          saveStatus: AppStatus.error,
          error: "La campagne n'a pas pu être enregistrée"));
    }
  }

  String _premiereErreur(Map<String, dynamic>? erreurs) {
    if (erreurs == null || erreurs.isEmpty) return "Données invalides";
    final premiere = erreurs.values.first;
    if (premiere is List && premiere.isNotEmpty) return premiere.first.toString();
    return premiere.toString();
  }
}
