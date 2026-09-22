import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/caisse.dart';
import 'package:immobilier/repository/repository.dart';

class HistoriqueState {
  final AppStatus chargement;

  /// Les caisses successives, de la plus recente a la plus ancienne,
  /// chacune avec son journal.
  final List<SessionCaisse> sessions;

  final List<Cloturage> cloturages;
  final String? erreur;

  const HistoriqueState({
    this.chargement = AppStatus.unknown,
    this.sessions = const [],
    this.cloturages = const [],
    this.erreur,
  });
}

/// L'historique d'une caisse : la sienne, ou celle qu'un administrateur
/// consulte.
class HistoriqueCubit extends Cubit<HistoriqueState> {
  HistoriqueCubit(this.caisseId) : super(const HistoriqueState());

  /// Nulle pour sa propre caisse.
  final int? caisseId;

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(const HistoriqueState(chargement: AppStatus.loading));
    try {
      // Le serveur choisit la caisse : la sienne pour un agent, celle
      // qu'il nomme pour l'administrateur.
      final sessions = await _repository.sessionsCaisse(caisse: caisseId);
      final cloturages = await _repository.cloturages(caisse: caisseId);

      emit(HistoriqueState(
        chargement: AppStatus.success,
        sessions: sessions,
        cloturages: cloturages,
      ));
    } catch (ex) {
      emit(HistoriqueState(
        chargement: AppStatus.error,
        erreur: ex.toString().replaceFirst("Exception: ", ""),
      ));
    }
  }
}
