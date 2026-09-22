import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/repository/repository.dart';

class ReservationsAirbnbState {
  final AppStatus? statut;
  final String? erreur;
  final List<SejourAirbnb>? sejours;

  const ReservationsAirbnbState({this.statut, this.erreur, this.sejours});

  int get sansContrat => (sejours ?? const []).where((s) => !s.contratCree).length;
}

/// Reservations Airbnb (a venir et des 30 derniers jours), pour en
/// faire des contrats.
class ReservationsAirbnbCubit extends Cubit<ReservationsAirbnbState> {
  /// Un seul bien, ou tous si null.
  final int? bienId;

  ReservationsAirbnbCubit({this.bienId}) : super(const ReservationsAirbnbState());

  Future<void> charger() async {
    // Au rafraichissement, la liste deja affichee reste visible.
    emit(ReservationsAirbnbState(statut: AppStatus.loading, sejours: state.sejours));
    try {
      final sejours = await Dependencies.get<Repository>().fetchSejoursAirbnb(bienId: bienId);
      sejours.sort((a, b) => a.du.compareTo(b.du));
      if (isClosed) return;
      emit(ReservationsAirbnbState(statut: AppStatus.success, sejours: sejours));
    } catch (ex) {
      if (isClosed) return;
      emit(ReservationsAirbnbState(
          statut: AppStatus.error, erreur: messageErreur(ex), sejours: state.sejours));
    }
  }
}
