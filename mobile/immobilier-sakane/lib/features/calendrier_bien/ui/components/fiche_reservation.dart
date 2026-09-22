import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/components/dialogue_suppression_reservation.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/cubit/calendrier_bien_cubit.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/gestion_immobilier/immobilier_by_status/ui/components/prolonger_dialogue.dart';
import 'package:immobilier/features/gestion_immobilier/immobilier_by_status/ui/components/shrink_dialogue.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/detail_reservation.dart';
import 'package:immobilier/features/immobilier/modifier_prix/ui/modifier_prix.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fiche d'une reservation, ouverte depuis le calendrier.
///
/// [contexte] est celui de la page : les fenetres suivantes s'y ouvrent
/// une fois la fiche refermee.
Future<void> ouvrirFicheReservation(
  BuildContext contexte,
  CalendrierBienCubit cubit,
  ReservationCalendrier r,
) async {
  final action = await showModalBottomSheet<_Action>(
    context: contexte,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FicheReservation(reservation: r),
  );
  if (action == null || !contexte.mounted) return;
  switch (action) {
    case _Action.detail:
      if (await DetailReservationPage.ouvrir(contexte, r.id)) await cubit.rafraichir();
    case _Action.modifier:
      await _modifier(contexte, cubit, r);
    case _Action.prolonger:
      await _prolonger(contexte, cubit, r);
    case _Action.raccourcir:
      await _raccourcir(contexte, cubit, r);
    case _Action.annuler:
      await _annuler(contexte, cubit, r);
  }
}

enum _Action { detail, modifier, prolonger, raccourcir, annuler }

/// Seul le prix par nuit se modifie : les dates passent par
/// « Prolonger » et « Raccourcir ».
Future<void> _modifier(BuildContext contexte, CalendrierBienCubit cubit, ReservationCalendrier r) async {
  final nouveau = await ouvrirModifierPrix(contexte, r.id);
  if (nouveau != null) await cubit.rafraichir();
}

Future<void> _prolonger(BuildContext contexte, CalendrierBienCubit cubit, ReservationCalendrier r) async {
  final cal = cubit.state.calendrier;
  // La prolongation s'arrete a la prochaine reservation ou au prochain blocage.
  DateTime maxDate = ajouterJours(aujourdhui(), 365);
  for (final autre in cal?.reservations ?? const <ReservationCalendrier>[]) {
    if (autre.id != r.id && !autre.checkin.isBefore(r.checkout) && autre.checkin.isBefore(maxDate)) {
      maxDate = autre.checkin;
    }
  }
  // Un bail de longue duree arrete aussi la prolongation.
  for (final b in cal?.baux ?? const <BailCalendrier>[]) {
    if (!b.du.isBefore(r.checkout) && b.du.isBefore(maxDate)) maxDate = b.du;
  }
  for (final b in cal?.blocages ?? const <BlocageCalendrier>[]) {
    final limite = ajouterJours(b.du, 1);
    if (!b.du.isBefore(r.checkout) && limite.isBefore(maxDate)) maxDate = limite;
  }
  if (ecartJours(r.checkout, maxDate) < 2) {
    afficherMessage(contexte, 'Aucune nuit libre juste après cette réservation.', erreur: true);
    return;
  }

  DateTime? checkout;
  double? prix;
  await showDialog(
    context: contexte,
    builder: (_) => ProlongerReservationDialog(
      from: r.checkout,
      maxDate: maxDate,
      initialPrice: r.prixNuit ?? cal?.prixBase,
      onConfirm: (c, p) {
        checkout = c;
        prix = p;
      },
    ),
  );
  if (checkout == null || prix == null || !contexte.mounted) return;
  final erreur = await cubit.prolonger(r.id, checkout!, prix!);
  if (contexte.mounted) afficherMessage(contexte, erreur ?? 'Réservation prolongée.', erreur: erreur != null);
}

Future<void> _raccourcir(BuildContext contexte, CalendrierBienCubit cubit, ReservationCalendrier r) async {
  DateTime? checkout;
  double remboursement = 0;
  await showDialog(
    context: contexte,
    builder: (_) => ShrinkReservationDialog(
      originalCheckout: r.checkout,
      originalPrice: r.prixNuit,
      onConfirm: (c, p) {
        checkout = c;
        remboursement = p;
      },
    ),
  );
  if (checkout == null || !contexte.mounted) return;
  // Un remboursement sort de la caisse : elle doit le contenir.
  if (remboursement > 0) {
    final prete = await garantirCaisseOuverte(
      contexte,
      motif: 'le remboursement de cette réservation',
      sortie: remboursement,
    );
    if (!prete || !contexte.mounted) return;
  }
  final erreur = await cubit.raccourcir(r.id, checkout!, remboursement);
  if (contexte.mounted) afficherMessage(contexte, erreur ?? 'Réservation raccourcie.', erreur: erreur != null);
}

Future<void> _annuler(BuildContext contexte, CalendrierBienCubit cubit, ReservationCalendrier r) async {
  // Le dialogue verifie deja le solde de la caisse pour le remboursement.
  final choix = await demanderSuppressionReservation(contexte, Booking(id: r.id));
  if (choix == null || !contexte.mounted) return;
  final erreur = await cubit.supprimer(r.id, rembourse: choix.rembourse, montant: choix.montant);
  if (contexte.mounted) afficherMessage(contexte, erreur ?? 'Réservation annulée.', erreur: erreur != null);
}

// ── La fiche ───────────────────────────────────────────────────────

class _FicheReservation extends StatefulWidget {
  final ReservationCalendrier reservation;

  const _FicheReservation({required this.reservation});

  @override
  State<_FicheReservation> createState() => _FicheReservationState();
}

class _FicheReservationState extends State<_FicheReservation> {
  String? _contratEnCours;

  ReservationCalendrier get r => widget.reservation;

  Future<void> _ouvrirContrat(String url, String titre) async {
    setState(() => _contratEnCours = url);
    try {
      final dir = await getTemporaryDirectory();
      final chemin = '${dir.path}${Platform.pathSeparator}${url.split('/').last.split('?').first}';
      await Dio().download(url, chemin);
      if (!mounted) return;
      await VisionneuseContrat.ouvrir(context, chemin: chemin, titre: titre);
    } catch (_) {
      if (mounted) afficherMessage(context, "Le contrat n'a pas pu être ouvert.", erreur: true);
    } finally {
      if (mounted) setState(() => _contratEnCours = null);
    }
  }

  Future<void> _lancer(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception();
    } catch (_) {
      if (mounted) afficherMessage(context, 'Action impossible sur cet appareil', erreur: true);
    }
  }

  void _whatsapp(String tel) {
    var chiffres = tel.replaceAll(RegExp(r'\D'), '');
    if (chiffres.startsWith('00')) chiffres = chiffres.substring(2);
    if (chiffres.startsWith('0')) chiffres = '212${chiffres.substring(1)}';
    _lancer(Uri.parse('https://wa.me/$chiffres'));
  }

  @override
  Widget build(BuildContext context) {
    final manager = Dependencies.get<Manager>();
    final passee = estPassee(r);
    final terminee = r.statutCode == 'completed';
    final actif = !passee && !terminee;
    final couleur = CouleursCalendrier.reservation(r);
    final nom = (r.clientNom ?? '').trim().isEmpty ? 'Client' : r.clientNom!.trim();
    final tel = (r.clientTel ?? '').trim();

    final actions = <Widget>[
      _bouton(Icons.info_outline, 'Voir le détail', CouleursCalendrier.texte, _Action.detail),
      if (actif && manager.can(AppPermission.updateReservationPrice))
        _bouton(Icons.price_change_outlined, 'Modifier le prix', AppColors.primaryColor, _Action.modifier),
      if (actif && manager.can(AppPermission.extendReservation))
        _bouton(Icons.more_time, 'Prolonger', const Color(0xFF2E7D32), _Action.prolonger),
      if (actif && manager.can(AppPermission.reduceReservation))
        _bouton(Icons.timelapse, 'Raccourcir', const Color(0xFFD97E1A), _Action.raccourcir),
      if (actif && manager.can(AppPermission.deleteReservation))
        _bouton(Icons.event_busy, 'Annuler la réservation', CouleursCalendrier.erreur, _Action.annuler),
    ];

    return DraggableScrollableSheet(
      initialChildSize: .72,
      minChildSize: .4,
      maxChildSize: .95,
      expand: false,
      builder: (context, controleur) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: controleur,
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CouleursCalendrier.bordure,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: couleur.withValues(alpha: .15),
                  child: Text(
                    nom.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleur),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nom,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pastille(r.libellePaiement, CouleursCalendrier.paiement(r)),
                          if ((r.statutNom ?? '').isNotEmpty)
                            _pastille(r.statutNom!, const Color(0xFF546E7A)),
                          if (passee) _pastille('Historique', CouleursCalendrier.passee),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (tel.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18, color: CouleursCalendrier.texteDoux),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tel,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
                  ),
                  _rond(Icons.call, const Color(0xFF1E88E5), 'Appeler',
                      () => _lancer(Uri(scheme: 'tel', path: tel.replaceAll(' ', '')))),
                  const SizedBox(width: 8),
                  _rond(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), 'WhatsApp', () => _whatsapp(tel)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CouleursCalendrier.fond,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(child: _date('Arrivée', r.checkin, r.heureArrivee)),
                  Column(
                    children: [
                      const Icon(Icons.arrow_forward, size: 18, color: CouleursCalendrier.texteDoux),
                      Text(pluriel(r.nuits > 0 ? r.nuits : nuitsEntre(r.checkin, r.checkout), 'nuit'),
                          style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux)),
                    ],
                  ),
                  Expanded(child: _date('Départ', r.checkout, r.heureDepart, droite: true)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _montant('Montant', r.montant, CouleursCalendrier.texte)),
              ],
            ),
            const SizedBox(height: 12),
            if (r.prixNuit != null) _ligne('Prix par nuit', montantLisible(r.prixNuit!)),
            if (r.avance > 0) _ligne('Avance', montantLisible(r.avance)),
            if (r.caution > 0) _ligne('Caution', montantLisible(r.caution)),
            if ((r.clientCin ?? '').isNotEmpty) _ligne('CIN', r.clientCin!),
            if ((r.creePar ?? '').isNotEmpty) _ligne('Créée par', r.creePar!),
            _ligne('Référence', '#${r.id}'),
            if ((r.remarques ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(r.remarques!.trim(),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF5D4037))),
              ),
            ],
            if ((r.contratPublic ?? '').isNotEmpty || (r.contratPrive ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if ((r.contratPublic ?? '').isNotEmpty)
                    Expanded(child: _contrat(Icons.description_outlined, 'Contrat public', r.contratPublic!)),
                  if ((r.contratPublic ?? '').isNotEmpty && (r.contratPrive ?? '').isNotEmpty)
                    const SizedBox(width: 8),
                  if ((r.contratPrive ?? '').isNotEmpty)
                    Expanded(child: _contrat(Icons.lock_outline, 'Contrat privé', r.contratPrive!)),
                ],
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Divider(height: 1, color: CouleursCalendrier.bordure),
              const SizedBox(height: 14),
              ...actions,
            ],
          ],
        ),
      ),
    );
  }

  Widget _pastille(String texte, Color couleur) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texte, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur)),
      );

  Widget _rond(IconData icone, Color couleur, String aide, VoidCallback onTap) => Material(
        color: couleur.withValues(alpha: .12),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: aide,
          onPressed: onTap,
          icon: FaIcon(icone, color: couleur, size: 20),
        ),
      );

  Widget _date(String libelle, DateTime d, String? heure, {bool droite = false}) => Column(
        crossAxisAlignment: droite ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(libelle, style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux)),
          const SizedBox(height: 2),
          Text(dateMoyenne(d),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
          Text(
            '${joursFr[d.weekday - 1]}${(heure ?? '').isEmpty ? '' : ' • ${_heure(heure!)}'}',
            style: const TextStyle(fontSize: 12, color: CouleursCalendrier.texteDoux),
          ),
        ],
      );

  static String _heure(String h) => h.length >= 5 ? h.substring(0, 5) : h;

  Widget _montant(String libelle, double valeur, Color couleur) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: CouleursCalendrier.bordure),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(libelle, style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(montantLisible(valeur),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: couleur)),
            ),
          ],
        ),
      );

  Widget _ligne(String libelle, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(libelle, style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texteDoux)),
            ),
            Flexible(
              child: Text(valeur,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
            ),
          ],
        ),
      );

  Widget _contrat(IconData icone, String titre, String url) {
    final enCours = _contratEnCours == url;
    return OutlinedButton.icon(
      onPressed: _contratEnCours != null ? null : () => _ouvrirContrat(url, titre),
      icon: enCours
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icone, size: 18),
      label: Text(titre, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryColor,
        side: BorderSide(color: AppColors.primaryColor.withValues(alpha: .5)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _bouton(IconData icone, String texte, Color couleur, _Action action) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: couleur.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).pop(action),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(icone, color: couleur, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(texte,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: couleur)),
                  ),
                  Icon(Icons.chevron_right, color: couleur.withValues(alpha: .7)),
                ],
              ),
            ),
          ),
        ),
      );
}
