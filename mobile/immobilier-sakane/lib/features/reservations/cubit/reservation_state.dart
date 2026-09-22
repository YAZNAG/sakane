part of 'reservation_cubit.dart';



class ReservationState {
  int? id;
  List<Booking>? bookings;
  String? error;
  AppStatus? fetchDataStatus;
  AppStatus? actionStatus;
  DateTime? from;
  DateTime? to;

  ReservationState({
    this.id,
    this.bookings,
    this.error,
    this.fetchDataStatus,
    this.from,
    this.to,
    this.actionStatus
  });

  ReservationState copyWith({
    int? id,
    List<Booking>? bookings,
    String? error,
    AppStatus? fetchDataStatus,
    DateTime? from,
    DateTime? to,
    AppStatus? actionStatus
  }) {
    return ReservationState(
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


