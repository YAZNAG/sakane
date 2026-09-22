part of 'reservations_cubit.dart';




class ReservationsState {

  int? id;
  List<Booking>? bookings;
  String? error;
  AppStatus? fetchDataStatus;
  AppStatus? actionStatus;

  DateTime? from;
  DateTime? to;

  ReservationsState({
    this.id,
    this.bookings,
    this.error,
    this.fetchDataStatus,
    this.from,
    this.to,
    this.actionStatus
  });

  ReservationsState copyWith({
    int? id,
    List<Booking>? bookings,
    String? error,
    AppStatus? fetchDataStatus,
    AppStatus? actionStatus,
    DateTime? from,
    DateTime? to,
  }) {
    return ReservationsState(
      id: id ?? this.id,
      bookings: bookings ?? this.bookings,
      error: error ,
      fetchDataStatus: fetchDataStatus ?? this.fetchDataStatus,
      from: from ?? this.from,
      to: to ?? this.to,
      actionStatus: actionStatus
    );
  }

}


