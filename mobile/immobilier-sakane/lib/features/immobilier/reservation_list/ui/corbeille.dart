import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/models/reservation_supprimee.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:toastification/toastification.dart';

/// La corbeille des réservations.
///
/// Une réservation supprimée y reste une semaine : de quoi revenir sur
/// une suppression faite trop vite. Passé ce délai, elle n'y figure
/// plus. La restaurer la remet telle qu'elle était, sans qu'aucun
/// message ne parte au client.
class CorbeillePage extends StatefulWidget {
  const CorbeillePage({super.key});

  static Widget page() => const CorbeillePage();

  @override
  State<CorbeillePage> createState() => _CorbeillePageState();
}

class _CorbeillePageState extends State<CorbeillePage> {

  List<ReservationSupprimee>? _affichees;

  TableauExportable? _tableauExport() {
    final liste = _affichees;
    if (liste == null) return null;
    double total = 0;
    final lignes = liste.map((r) {
      total += r.montant;
      return [
        '${r.id}',
        r.client,
        r.telephone ?? '',
        r.bien ?? '',
        r.checkin ?? '',
        r.checkout ?? '',
        '${r.nuits}',
        montantExport(r.montant),
        dateHeureExport(r.supprimeeLe),
        r.supprimeePar ?? '',
        _remboursementTexte(r),
        '${r.joursRestants}',
      ];
    }).toList();
    return TableauExportable(
      titre: 'Corbeille des réservations',
      colonnes: const ['N°', 'Client', 'Téléphone', 'Bien', 'Arrivée', 'Départ', 'Nuits', 'Montant',
          'Supprimée le', 'Supprimée par', 'Remboursement', 'Jours restants'],
      lignes: lignes,
      totaux: ['TOTAL', '', '', '', '', '', '', montantExport(total), '', '', '', ''],
    );
  }

  static String _remboursementTexte(ReservationSupprimee r) {
    if (r.rembourse == null) return '';
    if (r.rembourse == false) return 'Non remboursé';
    return 'Remboursé ${montantExport(r.montantRembourse ?? 0)}';
  }

  late Future<List<ReservationSupprimee>> _chargement;

  @override
  void initState() {
    super.initState();
    _chargement = _charger();
  }

  Future<List<ReservationSupprimee>> _charger() =>
      Dependencies.get<Repository>().corbeilleReservations();

  Future<void> _rafraichir() async {
    setState(() => _chargement = _charger());
    await _chargement;
  }

  Future<void> _restaurer(ReservationSupprimee r) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Restaurer la réservation", style: TextStyle(fontSize: 17)),
        content: Text(
          "La réservation de ${r.client} reprendra sa place, telle qu'elle "
          "était. Aucun message ne sera envoyé au client.",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6B4F),
              foregroundColor: Colors.white,
            ),
            child: const Text("Restaurer"),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      await Dependencies.get<Repository>().restaurerReservation(r.id);
      if (!mounted) return;
      showToast("Réservation restaurée", context, type: ToastificationType.success);
      await _rafraichir();
    } catch (ex) {
      if (!mounted) return;
      showToast("La restauration a échoué. Réessayez.", context,
          type: ToastificationType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Corbeille",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      body: FutureBuilder<List<ReservationSupprimee>>(
        future: _chargement,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: MyLoadingIndicator());
          }
          if (snap.hasError) {
            return MyErrorWidget(
              error: "La corbeille n'a pas pu être chargée.",
              action: "Réessayer",
              actionCLick: _rafraichir,
            );
          }

          final liste = snap.data ?? const <ReservationSupprimee>[];
          _affichees = liste;

          return RefreshIndicator(
            onRefresh: _rafraichir,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _Explication(nombre: liste.length),
                const SizedBox(height: 12),
                if (liste.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 46, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text("Aucune réservation supprimée cette semaine.",
                            style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ...liste.map((r) => _Carte(
                      reservation: r,
                      onRestaurer: () => _restaurer(r),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Ce que contient la corbeille, et pour combien de temps.
class _Explication extends StatelessWidget {
  final int nombre;

  const _Explication({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              nombre == 0
                  ? "Les réservations supprimées apparaissent ici pendant une "
                      "semaine, le temps de revenir sur une suppression."
                  : "$nombre réservation${nombre > 1 ? 's' : ''} supprimée"
                      "${nombre > 1 ? 's' : ''} cette semaine. Passé sept "
                      "jours, elles quittent la corbeille.",
              style: TextStyle(
                  fontSize: 12.5, color: Colors.blue.shade900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une réservation supprimée, avec de quoi la remettre en place.
class _Carte extends StatelessWidget {
  final ReservationSupprimee reservation;
  final VoidCallback onRestaurer;

  const _Carte({required this.reservation, required this.onRestaurer});

  @override
  Widget build(BuildContext context) {
    final r = reservation;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.client.isEmpty ? "Client inconnu" : r.client,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.black87),
                ),
              ),
              Text(
                "${r.montant.toStringAsFixed(2)} MAD",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87),
              ),
            ],
          ),
          if ((r.bien ?? "").isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(r.bien!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 15, color: Colors.grey.shade700),
              const SizedBox(width: 5),
              Text("${r.checkin ?? '-'} → ${r.checkout ?? '-'}",
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
              if (r.nuits > 0) ...[
                const SizedBox(width: 8),
                Text("${r.nuits} nuit${r.nuits > 1 ? 's' : ''}",
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              ],
            ],
          ),
          if ((r.supprimeePar ?? "").isNotEmpty || r.rembourse != null) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((r.supprimeePar ?? "").isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 15, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text("Supprimée par ${r.supprimeePar}",
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
                    ],
                  ),
                if (r.rembourse != null) _PuceRemboursement(reservation: r),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  r.joursRestants <= 1
                      ? "Dernier jour dans la corbeille"
                      : "Encore ${r.joursRestants} jours dans la corbeille",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: r.joursRestants <= 1
                        ? const Color(0xFFA8542B)
                        : Colors.grey.shade700,
                    fontWeight:
                        r.joursRestants <= 1 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (peut(AppPermission.restoreReservation))
              ElevatedButton.icon(
                onPressed: onRestaurer,
                icon: const Icon(Icons.restore, size: 17),
                label: const Text("Restaurer", style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6B4F),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Le client a-t-il été remboursé, et de combien.
class _PuceRemboursement extends StatelessWidget {
  final ReservationSupprimee reservation;

  const _PuceRemboursement({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final rembourse = reservation.rembourse == true;
    final texte = rembourse
        ? "Remboursé ${(reservation.montantRembourse ?? 0).toStringAsFixed(2)} MAD"
        : "Non remboursé";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: rembourse ? const Color(0xFFE3F1EA) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: rembourse ? const Color(0xFF2F6B4F) : Colors.grey.shade700,
        ),
      ),
    );
  }
}
