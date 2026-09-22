import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/modele_message.dart';
import 'package:immobilier/repository/repository.dart';

part 'modeles_messages_state.dart';

class ModelesMessagesCubit extends Cubit<ModelesMessagesState> {
  ModelesMessagesCubit() : super(ModelesMessagesState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final resultats = await Future.wait([
        _repository.fetchModelesMessages(),
        _repository.fetchVariablesModeles(),
      ]);
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        modeles: resultats[0] as List<ModeleMessage>,
        variables: resultats[1] as List<VariableModele>,
      ));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(
        fetchStatus: AppStatus.error,
        error: "Seuls les administrateurs peuvent gérer les modèles de messages.",
      ));
    } catch (_) {
      emit(state.copyWith(
          fetchStatus: AppStatus.error,
          error: "Impossible de charger les modèles"));
    }
  }

  /// Détail complet, historique compris.
  Future<void> ouvrir(int id) async {
    try {
      emit(state.copyWith(detailStatus: AppStatus.loading));
      final modele = await _repository.fetchModeleMessage(id);
      emit(state.copyWith(detailStatus: AppStatus.success, courant: modele));
    } catch (ex) {
      emit(state.copyWith(detailStatus: AppStatus.error, error: _message(ex)));
    }
  }

  /// Rendu avec des valeurs d'exemple, sans rien enregistrer.
  Future<void> apercu(String contenu) async {
    try {
      emit(state.copyWith(apercuStatus: AppStatus.loading));
      final apercu = await _repository.apercuModele(contenu);
      emit(state.copyWith(apercuStatus: AppStatus.success, apercuRendu: apercu));
    } catch (ex) {
      emit(state.copyWith(apercuStatus: AppStatus.error, error: _message(ex)));
    }
  }

  Future<void> enregistrer(int id, String contenu, {bool? actif}) async {
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading));
      final modele =
          await _repository.majModeleMessage(id, contenu, actif: actif);
      emit(state.copyWith(
        saveStatus: AppStatus.success,
        courant: modele,
        modeles: _remplacer(modele),
        message: "Modèle enregistré",
      ));
    } catch (ex) {
      emit(state.copyWith(saveStatus: AppStatus.error, error: _message(ex)));
    }
  }

  Future<void> restaurerDefaut(int id) async {
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading));
      final modele = await _repository.restaurerModeleMessage(id);
      emit(state.copyWith(
        saveStatus: AppStatus.success,
        courant: modele,
        modeles: _remplacer(modele),
        message: "Modèle d'origine rétabli",
      ));
    } catch (ex) {
      emit(state.copyWith(saveStatus: AppStatus.error, error: _message(ex)));
    }
  }

  Future<void> deposerImage(int id, File image) async {
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading));
      final modele = await _repository.deposerImageModele(id, image);
      emit(state.copyWith(
        saveStatus: AppStatus.success,
        courant: modele,
        modeles: _remplacer(modele),
        message: "Image jointe au message",
      ));
    } catch (ex) {
      emit(state.copyWith(saveStatus: AppStatus.error, error: _message(ex)));
    }
  }

  Future<void> retirerImage(int id) async {
    try {
      emit(state.copyWith(saveStatus: AppStatus.loading));
      final modele = await _repository.retirerImageModele(id);
      emit(state.copyWith(
        saveStatus: AppStatus.success,
        courant: modele,
        modeles: _remplacer(modele),
        message: "Image retirée",
      ));
    } catch (ex) {
      emit(state.copyWith(saveStatus: AppStatus.error, error: _message(ex)));
    }
  }

  List<ModeleMessage>? _remplacer(ModeleMessage modele) {
    final liste = state.modeles;
    if (liste == null) return null;
    return liste.map((m) => m.id == modele.id ? modele : m).toList();
  }

  String _message(Object ex) {
    if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
    if (ex is UnAuthorizedException) {
      return "Seuls les administrateurs peuvent modifier les modèles.";
    }
    return "L'opération n'a pas abouti";
  }
}
