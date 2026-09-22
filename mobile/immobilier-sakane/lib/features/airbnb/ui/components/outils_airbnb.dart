import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/airbnb/ui/components/carte_reservation_airbnb.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/routes.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nom du calendrier a donner sur Airbnb.
const String nomApplicationAirbnb = 'Alwed';

class CouleursAirbnb {
  static const Color rose = Color(0xFFFF5A5F);
  static const Color roseClair = Color(0xFFFF9A9D);
  static const Color succes = Color(0xFF2E7D32);

  /// Reservation en rose, blocage Airbnb en rose pale.
  static Color sejour(SejourAirbnb s) => s.estReservation ? rose : roseClair;
}

/// Droit « Relier / délier un bien à Airbnb » (l'administrateur l'a).
bool peutGererAirbnb() => Dependencies.get<Manager>().can(AppPermission.linkAirbnb);

/// Droit « Synchroniser avec Airbnb ».
bool peutSynchroniserAirbnb() => Dependencies.get<Manager>().can(AppPermission.syncAirbnb);

String cheminAirbnbBien(int bienId, {String? titre}) => Uri(
      path: Routes.airbnbBien.replaceAll(':id', '$bienId'),
      queryParameters: (titre ?? '').isEmpty ? null : {'titre': titre},
    ).toString();

/// « à l'instant », « il y a 5 min », « il y a 2 h », « il y a 3 jours ».
String ilYA(DateTime instant) {
  final ecart = DateTime.now().difference(instant);
  if (ecart.inMinutes < 1) return "à l'instant";
  if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
  if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
  if (ecart.inDays < 30) return 'il y a ${pluriel(ecart.inDays, 'jour')}';
  return 'le ${dateMoyenne(instant)}';
}

Future<void> ouvrirSurAirbnb(BuildContext context, String lien) async {
  final uri = Uri.tryParse(lien);
  try {
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) throw Exception();
  } catch (_) {
    if (context.mounted) afficherMessage(context, "Le lien Airbnb n'a pas pu être ouvert.", erreur: true);
  }
}

class PastilleAirbnb extends StatelessWidget {
  final SejourAirbnb sejour;

  const PastilleAirbnb({super.key, required this.sejour});

  @override
  Widget build(BuildContext context) {
    final couleur = CouleursAirbnb.sejour(sejour);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(sejour.estReservation ? FontAwesomeIcons.airbnb : FontAwesomeIcons.lock,
              size: 11, color: CouleursAirbnb.rose),
          const SizedBox(width: 5),
          Text(sejour.libelleType,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: CouleursAirbnb.rose)),
        ],
      ),
    );
  }
}

/// Choix fait dans la fiche d'un sejour, execute une fois la fiche fermee.
enum _ActionFicheAirbnb { ajouterContrat, voirReservation }

/// Resume d'un sejour Airbnb, ouvert depuis le calendrier. Pour une
/// reservation, propose d'en faire un contrat ou d'ouvrir celui cree.
/// Rend `true` quand le calendrier doit etre recharge (contrat cree, ou
/// retour de la reservation).
Future<bool> ouvrirFicheSejourAirbnb(BuildContext context, SejourAirbnb sejour, {int? bienId}) async {
  final action = await showModalBottomSheet<_ActionFicheAirbnb>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _FicheSejourAirbnb(sejour: sejour),
  );
  if (action == null || !context.mounted) return false;
  switch (action) {
    case _ActionFicheAirbnb.ajouterContrat:
      return ajouterContratAirbnb(context, sejour, bienId: bienId);
    case _ActionFicheAirbnb.voirReservation:
      await GoRouter.of(context).push(Routes.detailReservation.replaceAll(':id', '${sejour.bookingId}'));
      return true;
  }
}

class _FicheSejourAirbnb extends StatelessWidget {
  final SejourAirbnb sejour;

  const _FicheSejourAirbnb({required this.sejour});

  @override
  Widget build(BuildContext context) {
    final resume = (sejour.resume ?? '').trim();
    final reservation = sejour.estReservation;
    final bookingId = sejour.bookingId;
    final peutAjouter = reservation && bookingId == null && sejour.id != null && peutCreerContratAirbnb();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: CouleursCalendrier.bordure, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CouleursAirbnb.rose.withValues(alpha: .12),
                child: const FaIcon(FontAwesomeIcons.airbnb, color: CouleursAirbnb.rose, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Airbnb',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        PastilleAirbnb(sejour: sejour),
                        if (reservation && bookingId != null) const _PastilleContratCree(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ligne(Icons.date_range_outlined,
              'Du ${dateMoyenne(sejour.du)} au ${dateMoyenne(sejour.au)} (${pluriel(sejour.nuits, 'nuit')})'),
          if (resume.isNotEmpty) _ligne(Icons.notes_outlined, resume),
          _ligne(Icons.info_outline, 'Ces dates ne peuvent pas être réservées dans l’application.'),
          if (peutAjouter) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(_ActionFicheAirbnb.ajouterContrat),
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('Ajouter un contrat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursAirbnb.succes,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
          if (reservation && bookingId != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => voirContratAirbnb(context, bookingId),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Voir le contrat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursAirbnb.succes,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(_ActionFicheAirbnb.voirReservation),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Voir la réservation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CouleursAirbnb.succes,
                side: BorderSide(color: CouleursAirbnb.succes.withValues(alpha: .45)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
          if ((sejour.lien ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => ouvrirSurAirbnb(context, sejour.lien!),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ouvrir sur Airbnb'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursAirbnb.rose,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ligne(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: CouleursCalendrier.texteDoux),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
          ),
        ],
      ),
    );
  }
}

class _PastilleContratCree extends StatelessWidget {
  const _PastilleContratCree();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CouleursAirbnb.succes.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: CouleursAirbnb.succes),
          SizedBox(width: 4),
          Text('Contrat créé',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: CouleursAirbnb.succes)),
        ],
      ),
    );
  }
}
