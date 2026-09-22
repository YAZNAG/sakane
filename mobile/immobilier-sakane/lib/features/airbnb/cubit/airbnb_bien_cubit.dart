import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/repository/repository.dart';

/// Operation en cours sur la liaison, pour l'indicateur du bon bouton.
enum ActionAirbnb { enregistrer, synchroniser, nouveauLien, delier }

class AirbnbBienState {
  final int bienId;
  final AppStatus? statut;
  final String? erreur;
  final LienAirbnb? lien;
  final ActionAirbnb? enCours;

  const AirbnbBienState({
    required this.bienId,
    this.statut,
    this.erreur,
    this.lien,
    this.enCours,
  });

  AirbnbBienState copyWith({
    AppStatus? statut,
    String? erreur,
    LienAirbnb? lien,
    ActionAirbnb? enCours,
    bool finAction = false,
  }) {
    return AirbnbBienState(
      bienId: bienId,
      statut: statut ?? this.statut,
      erreur: erreur,
      lien: lien ?? this.lien,
      enCours: finAction ? null : (enCours ?? this.enCours),
    );
  }
}

class AirbnbBienCubit extends Cubit<AirbnbBienState> {
  AirbnbBienCubit(int bienId) : super(AirbnbBienState(bienId: bienId));

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(state.copyWith(statut: AppStatus.loading));
    try {
      final lien = await _depot.fetchAirbnb(state.bienId);
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.success, lien: lien));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreur(ex)));
    }
  }

  /// Rend le message d'erreur, ou null si tout s'est bien passe.
  Future<String?> _executer(ActionAirbnb action, Future<LienAirbnb> Function(Repository d) appel) async {
    if (state.enCours != null) return 'Une opération est déjà en cours.';
    emit(state.copyWith(enCours: action));
    try {
      final lien = await appel(_depot);
      if (isClosed) return null;
      emit(state.copyWith(statut: AppStatus.success, lien: lien, finAction: true));
      return null;
    } catch (ex) {
      if (!isClosed) emit(state.copyWith(finAction: true));
      return messageErreur(ex);
    }
  }

  Future<String?> enregistrer(String url) =>
      _executer(ActionAirbnb.enregistrer, (d) => d.enregistrerLienAirbnb(state.bienId, url.trim()));

  Future<String?> synchroniser() =>
      _executer(ActionAirbnb.synchroniser, (d) => d.synchroniserAirbnb(state.bienId));

  Future<String?> nouveauLien() =>
      _executer(ActionAirbnb.nouveauLien, (d) => d.nouveauLienExportAirbnb(state.bienId));

  Future<String?> delier() =>
      _executer(ActionAirbnb.delier, (d) => d.enregistrerLienAirbnb(state.bienId, ''));
}
