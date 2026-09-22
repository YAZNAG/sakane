import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/repository/repository.dart';

part 'detail_reservation_state.dart';

class DetailReservationCubit extends Cubit<DetailReservationState> {
  DetailReservationCubit(int id) : super(DetailReservationState(id: id));

  Repository get _depot => Dependencies.get<Repository>();

  /// Premier chargement : l'ecran montre l'attente.
  Future<void> charger() async {
    emit(state.copyWith(statut: AppStatus.loading, erreur: null));
    try {
      final detail = await _depot.detailReservation(state.id);
      emit(state.copyWith(statut: AppStatus.success, detail: detail));
    } catch (ex) {
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreur(ex)));
    }
  }

  /// Recharge sans masquer la page ; rend l'erreur eventuelle.
  Future<String?> rafraichir() async {
    if (state.detail == null) {
      await charger();
      return state.statut == AppStatus.error ? state.erreur : null;
    }
    try {
      final detail = await _depot.detailReservation(state.id);
      emit(state.copyWith(statut: AppStatus.success, detail: detail));
      return null;
    } catch (ex) {
      return messageErreur(ex);
    }
  }

  /// Le serveur a rendu le detail a jour (changement de prix).
  void remplacer(DetailReservation detail) {
    emit(state.copyWith(statut: AppStatus.success, detail: detail, modifie: true));
  }

  /// Une action a change la reservation : on recharge et on le retient,
  /// pour que la liste se rafraichisse au retour.
  Future<void> apresModification() async {
    emit(state.copyWith(modifie: true));
    await rafraichir();
  }
}
