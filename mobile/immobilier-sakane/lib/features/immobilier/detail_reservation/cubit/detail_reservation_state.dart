part of 'detail_reservation_cubit.dart';

const Object _inchange = Object();

class DetailReservationState {
  final int id;
  final AppStatus? statut;
  final String? erreur;
  final DetailReservation? detail;

  /// Vrai des qu'une action a change la reservation depuis cet ecran.
  final bool modifie;

  const DetailReservationState({
    required this.id,
    this.statut,
    this.erreur,
    this.detail,
    this.modifie = false,
  });

  DetailReservationState copyWith({
    AppStatus? statut,
    Object? erreur = _inchange,
    DetailReservation? detail,
    bool? modifie,
  }) {
    return DetailReservationState(
      id: id,
      statut: statut ?? this.statut,
      erreur: identical(erreur, _inchange) ? this.erreur : erreur as String?,
      detail: detail ?? this.detail,
      modifie: modifie ?? this.modifie,
    );
  }
}
