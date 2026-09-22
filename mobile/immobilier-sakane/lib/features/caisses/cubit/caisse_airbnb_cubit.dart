import 'package:bloc/bloc.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/repository/repository.dart';

/// Droit « Voir la caisse Airbnb ». Le serveur reste juge ;
/// l'application évite seulement d'appeler un point refusé.
bool get estAdminCaisseAirbnb => peut(AppPermission.viewAirbnbCashbox);

/// Droit « Transférer depuis la caisse Airbnb ».
bool get peutTransfererCaisseAirbnb => peut(AppPermission.transferAirbnbCashbox);

class CaisseAirbnbState {
  final AppStatus chargement;
  final AppStatus action;
  final CaisseAirbnb? caisse;
  final String? message;
  final String? erreur;

  const CaisseAirbnbState({
    this.chargement = AppStatus.unknown,
    this.action = AppStatus.unknown,
    this.caisse,
    this.message,
    this.erreur,
  });

  CaisseAirbnbState copyWith({
    AppStatus? chargement,
    AppStatus? action,
    CaisseAirbnb? caisse,
    String? message,
    String? erreur,
  }) {
    return CaisseAirbnbState(
      chargement: chargement ?? this.chargement,
      action: action ?? this.action,
      caisse: caisse ?? this.caisse,
      message: message,
      erreur: erreur,
    );
  }
}

/// La caisse Airbnb : elle reçoit seule le montant des séjours payés sur
/// Airbnb. L'administrateur la consulte et en transfère le contenu.
class CaisseAirbnbCubit extends Cubit<CaisseAirbnbState> {
  CaisseAirbnbCubit() : super(const CaisseAirbnbState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(state.copyWith(chargement: AppStatus.loading));
    try {
      final caisse = await _repository.caisseAirbnb();
      emit(state.copyWith(chargement: AppStatus.success, caisse: caisse));
    } catch (ex) {
      emit(state.copyWith(chargement: AppStatus.error, erreur: _raison(ex)));
    }
  }

  /// Le serveur rend la caisse à jour : pas besoin de la relire.
  Future<bool> transferer({
    required int caisse,
    required double montant,
    String? commentaire,
  }) async {
    emit(state.copyWith(action: AppStatus.loading));
    try {
      final maj = await _repository.transfererCaisseAirbnb(
          caisse: caisse, montant: montant, commentaire: commentaire);
      emit(state.copyWith(
        action: AppStatus.success,
        caisse: maj,
        message: "Transfert effectué",
      ));
      return true;
    } catch (ex) {
      emit(state.copyWith(action: AppStatus.error, erreur: _raison(ex)));
      return false;
    }
  }

  static String _raison(Object ex) {
    final texte = ex.toString().replaceFirst("Exception: ", "");
    return texte.length > 160 ? "${texte.substring(0, 160)}…" : texte;
  }
}
