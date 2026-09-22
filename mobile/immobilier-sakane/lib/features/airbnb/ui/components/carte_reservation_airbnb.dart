import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/add_reservation/pre_remplissage_reservation.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/components/outils_reservation.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// Droit de creer une reservation, donc un contrat depuis Airbnb.
bool peutCreerContratAirbnb() => Dependencies.get<Manager>().can(AppPermission.createReservation);

/// Ouvre le formulaire de reservation pre-rempli avec le sejour Airbnb.
/// Rend `true` quand le contrat a ete cree.
Future<bool> ajouterContratAirbnb(BuildContext context, SejourAirbnb sejour, {int? bienId}) async {
  final bien = sejour.bienId ?? bienId;
  if (bien == null || sejour.id == null) {
    afficherMessage(context, "Cette réservation Airbnb ne peut pas encore devenir un contrat.", erreur: true);
    return false;
  }
  return ouvrirAjoutReservation(
    context,
    bien,
    preRemplissage: PreRemplissageReservation.airbnb(sejour),
  );
}

/// Ouvre le contrat prive (a defaut le public) de la reservation creee
/// pour un sejour Airbnb.
Future<void> voirContratAirbnb(BuildContext context, int bookingId) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  String? url;
  var titre = 'Contrat privé';
  try {
    final detail = await Dependencies.get<Repository>().detailReservation(bookingId);
    url = detail.contratPrive;
    if (url == null || url.isEmpty) {
      url = detail.contratPublic;
      titre = 'Contrat public';
    }
  } catch (ex) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    afficherMessage(context, messageErreur(ex), erreur: true);
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();
  if (url == null || url.isEmpty) {
    afficherMessage(context, "Aucun contrat n'est encore disponible pour cette réservation.", erreur: true);
    return;
  }
  await ouvrirContratDistant(context, url, titre: titre);
}

/// Une reservation Airbnb : dates, code, telephone, et son contrat.
class CarteReservationAirbnb extends StatelessWidget {
  final SejourAirbnb sejour;

  /// Bien du sejour, quand le serveur ne le precise pas (page d'un bien).
  final int? bienId;

  /// Affiche le titre du bien (vue d'ensemble).
  final bool afficherBien;

  /// Carte posee a plat dans une autre carte (page d'un bien).
  final bool aPlat;

  /// Appele apres la creation du contrat, ou au retour de la reservation.
  final VoidCallback? onChange;

  const CarteReservationAirbnb({
    super.key,
    required this.sejour,
    this.bienId,
    this.afficherBien = true,
    this.aPlat = false,
    this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final s = sejour;
    final titre = (s.bienTitre ?? '').trim();
    final code = (s.code ?? '').trim();
    final tel = (s.telephone4 ?? '').trim();
    final lien = (s.lien ?? '').trim();
    final termine = !s.au.isAfter(aujourdhui());

    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CouleursAirbnb.rose.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const FaIcon(FontAwesomeIcons.airbnb, size: 19, color: CouleursAirbnb.rose),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (afficherBien)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        titre.isEmpty ? (s.bienId == null ? 'Bien' : 'Bien #${s.bienId}') : titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: CouleursCalendrier.texte),
                      ),
                    ),
                  Text(
                    '${dateCourte(s.du)} → ${dateMoyenne(s.au)}',
                    style: TextStyle(
                      fontSize: afficherBien ? 13 : 14,
                      fontWeight: afficherBien ? FontWeight.w600 : FontWeight.w700,
                      color: CouleursCalendrier.texte,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _pastille(Icons.nights_stay_outlined, pluriel(s.nuits, 'nuit'), CouleursCalendrier.texteDoux),
                      if (code.isNotEmpty) _pastille(Icons.confirmation_number_outlined, code, CouleursCalendrier.texte),
                      if (tel.isNotEmpty) _pastille(Icons.phone_outlined, 'Tél. …$tel', CouleursCalendrier.texte),
                      if (termine) _pastille(Icons.history, 'Séjour terminé', CouleursCalendrier.texteDoux),
                      if (s.contratCree)
                        _pastille(Icons.check_circle, 'Contrat créé', CouleursAirbnb.succes, fort: true),
                    ],
                  ),
                ],
              ),
            ),
            if (lien.isNotEmpty)
              IconButton(
                tooltip: 'Ouvrir sur Airbnb',
                visualDensity: VisualDensity.compact,
                onPressed: () => ouvrirSurAirbnb(context, lien),
                icon: const Icon(Icons.open_in_new, color: CouleursAirbnb.rose, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _action(context),
      ],
    );

    if (aPlat) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: contenu);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CouleursCalendrier.bordure),
      ),
      child: contenu,
    );
  }

  Widget _action(BuildContext context) {
    final s = sejour;
    if (s.contratCree) {
      return OutlinedButton.icon(
        onPressed: () async {
          await GoRouter.of(context).push(Routes.detailReservation.replaceAll(':id', '${s.bookingId}'));
          onChange?.call();
        },
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text('Voir la réservation'),
        style: OutlinedButton.styleFrom(
          foregroundColor: CouleursAirbnb.succes,
          side: BorderSide(color: CouleursAirbnb.succes.withValues(alpha: .45)),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    if (!peutCreerContratAirbnb() || s.id == null) return const SizedBox.shrink();
    return ElevatedButton.icon(
      onPressed: () async {
        final cree = await ajouterContratAirbnb(context, s, bienId: bienId);
        if (cree) onChange?.call();
      },
      icon: const Icon(Icons.note_add_outlined, size: 18),
      label: const Text('Ajouter un contrat'),
      style: ElevatedButton.styleFrom(
        backgroundColor: CouleursAirbnb.rose,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _pastille(IconData icone, String texte, Color couleur, {bool fort = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: fort ? .12 : .07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: couleur),
          const SizedBox(width: 4),
          Text(texte, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur)),
        ],
      ),
    );
  }
}
