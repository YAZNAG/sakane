part of 'add_reservation_cubit.dart';



class AddReservationState {

  AppStatus? fetchStatus;
  AppStatus? addStatus;
  Booking? booking;
  List<Client>? clients;
  List<Client>? sourceClients;
  String? error;
  int? realestateId;
  Realestate? realestate;
  String? searchQuery;
  /// Une recherche de client est en cours cote serveur.
  bool rechercheClients;
  Map<String,dynamic>? errors;
  Uint8List? signature;


  AddReservationState({
    this.fetchStatus,
    this.addStatus,
    this.booking,
    this.clients,
    this.error,
    this.realestateId,
    this.realestate,
    this.sourceClients,
    this.searchQuery,
    this.rechercheClients = false,
    this.errors,
    this.signature
  });

  AddReservationState copyWith({
    AppStatus? fetchStatus,
    AppStatus? addStatus,
    Booking? booking,
    List<Client>? clients,
    String? error,
    int? realestateId,
    Realestate? realestate,
    List<Client>? sourceClients,
    String? searchQuery,
    bool? rechercheClients,
    Map<String,dynamic>? errors,
    Uint8List? signature
  }) {
    return AddReservationState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      addStatus: addStatus ,
      booking: booking ?? this.booking,
      clients: clients ?? this.clients,
      error: error ,
      realestateId: realestateId ?? this.realestateId,
      realestate: realestate ?? this.realestate,
      sourceClients: sourceClients ?? this.sourceClients,
      searchQuery: searchQuery ?? this.searchQuery,
      rechercheClients: rechercheClients ?? this.rechercheClients,
      errors: errors,
      signature: signature ?? this.signature
    );
  }
}


