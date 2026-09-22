import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/models/numero_campagnes.dart';
import 'package:immobilier/repository/repository.dart';

part 'numero_campagnes_state.dart';

/// Numero WhatsApp dedie aux campagnes (session Wasender).
class NumeroCampagnesCubit extends Cubit<NumeroCampagnesState> {
  NumeroCampagnesCubit() : super(NumeroCampagnesState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final numero = await _repository.fetchNumeroCampagnes();
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.success, numero: numero));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.error, error: _message(ex)));
    }
  }

  /// Retourne vrai si la cle a ete acceptee par le serveur.
  Future<bool> enregistrer(String cle) => _action(
      () => _repository.enregistrerNumeroCampagnes(cle.trim()),
      "Numéro des campagnes enregistré");

  Future<bool> revenirAuPrincipal() => _action(
      _repository.retirerNumeroCampagnes,
      "Les campagnes utilisent de nouveau le numéro principal");

  Future<bool> _action(
      Future<NumeroCampagnes> Function() operation, String message) async {
    if (state.enCours) return false;
    try {
      emit(state.copyWith(enCours: true));
      final numero = await operation();
      if (isClosed) return true;
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        numero: numero,
        actionStatus: AppStatus.success,
        message: message,
      ));
      return true;
    } catch (ex) {
      if (!isClosed) {
        emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
      }
      return false;
    }
  }

  String _message(Object ex) {
    if (ex is UnAuthenticatedException) {
      logout();
      return "Session expirée";
    }
    return ex.toString().replaceFirst('Exception: ', '');
  }
}
