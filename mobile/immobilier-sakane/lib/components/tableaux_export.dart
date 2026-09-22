import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/realestate.dart';

/// Les tableaux d'export partagés par plusieurs pages.

String _periode(DateTime? du, DateTime? au) =>
    du == null || au == null ? '' : 'Du ${dateExport(du)} au ${dateExport(au)}';

TableauExportable tableauReservations(
  String titre,
  List<Booking> liste, {
  DateTime? depuis,
  DateTime? jusqua,
}) {
  double total = 0;
  final lignes = liste.map((b) {
    total += b.amount ?? 0;
    final nuits = (b.checkin != null && b.checkout != null)
        ? b.checkout!.difference(b.checkin!).inDays
        : 0;
    final client = b.client;
    return [
      '${b.id ?? ''}',
      [client?.firstName, client?.lastName].whereType<String>().join(' ').trim(),
      client?.tel ?? '',
      b.realestate?.title ?? '',
      dateExport(b.checkin),
      dateExport(b.checkout),
      '$nuits',
      '${b.nbGuest ?? ''}',
      montantExport(b.nightPrice),
      montantExport(b.amount),
      b.status?.name ?? '',
      b.creePar ?? '',
    ];
  }).toList();

  return TableauExportable(
    titre: titre,
    sousTitre: _periode(depuis, jusqua),
    colonnes: const [
      'N°', 'Client', 'Téléphone', 'Bien', 'Arrivée', 'Départ', 'Nuits',
      'Voyageurs', 'Prix / nuit', 'Montant', 'Statut', 'Créée par',
    ],
    lignes: lignes,
    totaux: ['TOTAL', '', '', '', '', '', '', '', '', montantExport(total), '', ''],
  );
}

TableauExportable tableauBiens(String titre, List<Realestate> liste) {
  return TableauExportable(
    titre: titre,
    colonnes: const [
      'Réf.', 'Bien', 'Adresse', 'Ville', 'Propriétaire', 'Statut', 'Chambres',
      'Surface (m²)', 'Prix', 'Client en cours', 'Départ prévu',
    ],
    lignes: liste
        .map((r) => [
              '${r.id ?? ''}',
              r.title ?? '',
              r.address?.address ?? '',
              r.address?.city?.name ?? '',
              r.owner?.name ?? '',
              r.status?.name ?? '',
              '${r.nbRooms ?? ''}',
              '${r.surface ?? ''}',
              r.price == null ? '' : montantExport(r.price),
              [r.booking?.client?.firstName, r.booking?.client?.lastName]
                  .whereType<String>()
                  .join(' ')
                  .trim(),
              dateExport(r.booking?.checkout),
            ])
        .toList(),
  );
}
