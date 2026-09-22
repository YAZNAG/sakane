import 'dart:async';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/repository/data_providers/api/api_client.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../exceptions/unauthorized_exception.dart';
import '../../../../exceptions/validation_exception.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

part 'add_reservation_state.dart';

/// Message affiché quand on tente de réserver pour un client sur liste noire.
String messageListeNoire(Client client) {
  final motif = client.listeNoire?.motif;
  return "Ce client est sur la liste noire${(motif ?? '').isEmpty ? '' : ' : $motif'}. "
      "Impossible de créer une réservation.";
}

class AddReservationCubit extends Cubit<AddReservationState> {
  AddReservationCubit(int realestateId)
    : super(AddReservationState(realestateId: realestateId));

  void fetchData() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      var result = await Future.wait([
        repository.getClients(),
        repository.fetchRealesate(state.realestateId!),
      ]);
      emit(
        state.copyWith(
          fetchStatus: AppStatus.success,
          clients: result[0] as List<Client>,
          sourceClients: result[0] as List<Client>,
          realestate: result[1] as Realestate,
          booking: Booking(realestate: result[1] as Realestate),
        ),
      );
    } on NetworkConnectivityException catch (ex) {
      emit(
        state.copyWith(
          fetchStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException catch (ex) {
      logout();
    } on UnAuthorizedException catch (ex) {
      emit(
        state.copyWith(
          fetchStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } catch (ex) {
      emit(state.copyWith(fetchStatus: AppStatus.error, error: "Error"));
      rethrow;
    }
  }

  void updateReservation(Booking booking) {
    emit(state.copyWith(booking: booking));
  }

  /// Recherche de client : filtre immediat sur les clients deja charges,
  /// puis interrogation du serveur (nom, telephone, CIN, e-mail) apres une
  /// courte pause, pour atteindre aussi les clients absents de la liste.
  Timer? _rechercheDifferee;

  void searchClient(String searchQuery) {
    final requete = searchQuery.trim();
    _rechercheDifferee?.cancel();
    if (requete.isEmpty) {
      emit(state.copyWith(
        clients: state.sourceClients,
        searchQuery: '',
        rechercheClients: false,
      ));
      return;
    }
    emit(state.copyWith(
      clients: _filtrerClientsLocalement(requete),
      searchQuery: searchQuery,
      rechercheClients: true,
    ));
    _rechercheDifferee = Timer(
      const Duration(milliseconds: 400),
      () => _chercherClientsSurServeur(requete),
    );
  }

  List<Client> _filtrerClientsLocalement(String requete) {
    final query = requete.toLowerCase();
    return (state.sourceClients ?? []).where((client) {
      final texte = [
        client.firstName,
        client.lastName,
        client.firstNameAr,
        client.lastNameAr,
        client.tel,
        client.email,
        client.identityNumber,
      ].whereType<String>().join(' ').toLowerCase();
      return texte.contains(query);
    }).toList();
  }

  Future<void> _chercherClientsSurServeur(String requete) async {
    try {
      final resultats =
          await Dependencies.get<Repository>().getClients(search: requete);
      if (isClosed) return;
      // Une reponse en retard ne doit pas ecraser une recherche plus recente.
      if ((state.searchQuery ?? '').trim() != requete) return;
      emit(state.copyWith(clients: resultats, rechercheClients: false));
    } catch (_) {
      if (isClosed) return;
      // Hors ligne ou serveur muet : le filtre local reste affiche.
      emit(state.copyWith(rechercheClients: false));
    }
  }

  @override
  Future<void> close() {
    _rechercheDifferee?.cancel();
    return super.close();
  }

  void addClient(Client client) {
    List<Client> clients = [client, ...(state.clients ?? [])];
    Booking booking = state.booking ?? Booking();
    booking = booking.copyWith(client: client);
    emit(state.copyWith(booking: booking, sourceClients: clients));
    searchClient(state.searchQuery ?? "");
  }

  void editClient(Client updated) {
    final updatedSource = (state.sourceClients ?? [])
        .map((c) => c.id == updated.id ? updated : c)
        .toList();
    Booking? booking = state.booking;
    if (booking?.client?.id == updated.id) {
      booking = booking!.copyWith(client: updated);
    }
    emit(state.copyWith(sourceClients: updatedSource, booking: booking));
    searchClient(state.searchQuery ?? "");
  }

  /// [airbnbSejour] : le sejour Airbnb dont cette reservation devient le
  /// contrat (signature facultative ; le montant entre seul dans la caisse
  /// Airbnb, l'agent n'encaisse rien).
  void addBooking(Booking booking, {int? airbnbSejour}) async {
    // Le serveur refuse aussi, mais on évite l'aller-retour.
    final client = booking.client;
    if (client?.listeNoire != null) {
      emit(state.copyWith(addStatus: AppStatus.error, error: messageListeNoire(client!)));
      return;
    }
    try {
      emit(state.copyWith(addStatus: AppStatus.loading));
      Repository repository = Dependencies.get<Repository>();
      booking = booking.copyWith(signature: state.signature);
      await repository.addBooking(booking, airbnbSejour: airbnbSejour);
      emit(state.copyWith(addStatus: AppStatus.success));
    } on OperationMiseEnFileException {
      // Enregistree sur le telephone : elle partira au retour du reseau.
      // Ce n'est pas un echec, l'agent ne doit pas recommencer.
      emit(state.copyWith(addStatus: AppStatus.success));
    } on NetworkConnectivityException catch (ex) {
      emit(
        state.copyWith(
          addStatus: AppStatus.error,
          error: AppStrings.checkConnectivity,
        ),
      );
    } on UnAuthenticatedException catch (ex) {
      logout();
    } on UnAuthorizedException catch (ex) {
      emit(
        state.copyWith(
          addStatus: AppStatus.error,
          error: AppStrings.authorizationError,
        ),
      );
    } on ValidatorException catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, errors: ex.errors));
    } on DioException catch (ex) {
      // Refus du serveur sans détail de validation (ex. liste noire, dates
      // prises sur Airbnb) : on affiche son message (error.msg[0] ou message).
      emit(state.copyWith(
        addStatus: AppStatus.error,
        error: ApiClient.messageServeur(ex, AppStrings.error),
      ));
    } catch (ex) {
      emit(state.copyWith(addStatus: AppStatus.error, error: "Error"));
      rethrow;
    }
  }

  void clientSignature(Uint8List signature) async {
    emit(state.copyWith(signature: signature));
  }
}
