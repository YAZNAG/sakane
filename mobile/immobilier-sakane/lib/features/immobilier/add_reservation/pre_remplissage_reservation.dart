import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/routes.dart';

/// Ce que le formulaire « Nouvelle réservation » reçoit d'avance, par
/// l'`extra` de GoRouter : des dates choisies sur le calendrier, ou une
/// réservation Airbnb dont on crée le contrat.
class PreRemplissageReservation {
  /// Jour d'arrivée.
  final DateTime? arrivee;

  /// Jour du départ (exclu du séjour).
  final DateTime? depart;

  /// Réservation Airbnb à transformer en contrat.
  final SejourAirbnb? sejourAirbnb;

  const PreRemplissageReservation({this.arrivee, this.depart, this.sejourAirbnb});

  factory PreRemplissageReservation.airbnb(SejourAirbnb sejour) =>
      PreRemplissageReservation(arrivee: sejour.du, depart: sejour.au, sejourAirbnb: sejour);

  bool get estAirbnb => sejourAirbnb?.id != null;
}

/// Ouvre le formulaire de réservation du bien [bienId].
///
/// Rend `true` quand une réservation a été créée.
Future<bool> ouvrirAjoutReservation(
  BuildContext context,
  int bienId, {
  PreRemplissageReservation? preRemplissage,
}) async {
  final resultat = await GoRouter.of(context).push(
    Routes.addReservation.replaceAll(':id', '$bienId'),
    extra: preRemplissage,
  );
  return resultat == true;
}
