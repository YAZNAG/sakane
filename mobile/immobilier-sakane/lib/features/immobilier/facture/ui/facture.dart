import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/features/immobilier/facture/ui/appliquer_facture.dart';
import 'package:immobilier/models/facture_reservation.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

/// Ouvre la facture d'une réservation, en lecture seule.
///
/// Tant qu'elle n'est pas appliquée, le serveur rend un aperçu sans
/// numéro, et l'on propose de l'appliquer. Une fois appliquée, elle est
/// figée : on peut la télécharger ou l'envoyer au client.
///
/// Rend vrai si la facture a été appliquée depuis cet écran.
Future<bool> ouvrirFacture(BuildContext context, int reservation) async {
  final facture = await _avecAttente(
      context, () => Dependencies.get<Repository>().factureReservation(reservation));
  if (facture == null || !context.mounted) return false;

  var appliquer = false;
  await VisionneuseContrat.ouvrir(
    context,
    chemin: facture.chemin,
    titre: facture.appliquee ? facture.titre : "Aperçu de la facture",
    actionBas: _ActionsFacture(
      reservation: reservation,
      facture: facture,
      onAppliquer: () => appliquer = true,
    ),
  );
  if (!appliquer || !context.mounted) return false;

  final resume = await ouvrirAppliquerFacture(context, reservation);
  return resume != null;
}

/// Télécharge la facture : prépare le PDF puis propose de l'enregistrer
/// ou de le partager, comme les autres documents de l'application.
Future<void> telechargerFacture(BuildContext context, int reservation) async {
  final facture = await _avecAttente(
      context, () => Dependencies.get<Repository>().factureReservation(reservation));
  if (facture == null || !context.mounted) return;
  await enregistrerPdfFacture(context, facture);
}

/// Copie le PDF sous un nom lisible, puis ouvre la feuille de partage
/// (« Enregistrer dans Fichiers », Drive, WhatsApp…).
Future<void> enregistrerPdfFacture(BuildContext context, FactureReservation facture) async {
  try {
    final dir = await getTemporaryDirectory();
    final dossier = Directory('${dir.path}${Platform.pathSeparator}factures');
    await dossier.create(recursive: true);
    final nom = facture.nom
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final cible = File('${dossier.path}${Platform.pathSeparator}${nom.isEmpty ? 'facture' : nom}.pdf');
    await File(facture.chemin).copy(cible.path);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(cible.path, mimeType: 'application/pdf')],
      subject: facture.titre,
    ));
  } catch (_) {
    if (!context.mounted) return;
    showToast(
      "",
      description: "La facture n'a pas pu être téléchargée.",
      context,
      type: ToastificationType.error,
      second: 3,
    );
  }
}

/// « 1 250,00 MAD » : toujours deux décimales sur une facture.
String montantFacture(double v) {
  final centimes = (v.abs() * 100).round();
  final chiffres = (centimes ~/ 100).toString();
  final tampon = StringBuffer();
  for (int i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(' ');
    tampon.write(chiffres[i]);
  }
  final signe = v < 0 && centimes > 0 ? '-' : '';
  return '$signe$tampon,${(centimes % 100).toString().padLeft(2, '0')} MAD';
}

/// Affiche une attente pendant l'appel ; rend null (et prévient) s'il échoue.
Future<FactureReservation?> _avecAttente(
    BuildContext context, Future<FactureReservation> Function() appel) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final facture = await appel();
    if (context.mounted) Navigator.of(context).pop();
    return facture;
  } catch (ex) {
    if (!context.mounted) return null;
    Navigator.of(context).pop();
    showToast(
      "",
      description: ex.toString().replaceFirst("Exception: ", ""),
      context,
      type: ToastificationType.error,
      second: 3,
    );
    return null;
  }
}

/// Les actions sous la facture.
///
/// Aperçu : un bandeau le signale, et l'on propose d'appliquer la facture.
/// Appliquée : télécharger, ou envoyer au client ce que l'on vient de lire.
class _ActionsFacture extends StatefulWidget {
  final int reservation;
  final FactureReservation facture;
  final VoidCallback onAppliquer;

  const _ActionsFacture({
    required this.reservation,
    required this.facture,
    required this.onAppliquer,
  });

  @override
  State<_ActionsFacture> createState() => _ActionsFactureState();
}

class _ActionsFactureState extends State<_ActionsFacture> {
  bool _enCours = false;
  bool _envoyee = false;

  Future<void> _envoyer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("Envoyer la facture ?"),
        content: Text(
          "La facture${widget.facture.numero == null ? '' : ' N° ${widget.facture.numero}'}"
          " sera envoyée au client de la réservation par WhatsApp.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Envoyer"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _enCours = true);
    try {
      final numero = await Dependencies.get<Repository>().envoyerFacture(widget.reservation);
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _envoyee = true;
      });
      showToast(
        numero.isEmpty
            ? "Facture envoyée au client"
            : "Facture envoyée au $numero",
        context,
        second: 2,
      );
    } catch (ex) {
      if (!mounted) return;
      setState(() => _enCours = false);
      showToast(
        "",
        description: ex.toString().replaceFirst("Exception: ", ""),
        context,
        type: ToastificationType.error,
        second: 3,
      );
    }
  }

  void _appliquer() {
    widget.onAppliquer();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: widget.facture.appliquee ? _appliquee() : _apercu(),
      ),
    );
  }

  Widget _apercu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3C77A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.visibility_outlined, size: 19, color: Color(0xFF9A6100)),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Aperçu — facture non appliquée",
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF7A4D00)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: peut(AppPermission.applyInvoice) ? _appliquer : null,
            icon: const Icon(Icons.request_quote_outlined, size: 19),
            label: const Text("Appliquer la facture"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appliquee() {
    const vert = Color(0xFF2F6B4F);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _enCours || _envoyee || !peut(AppPermission.sendInvoice) ? null : _envoyer,
            icon: _enCours
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_envoyee ? Icons.check : Icons.send, size: 18),
            label: Text(_envoyee ? "Envoyée au client" : "Envoyer au client"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _envoyee ? vert : AppColors.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _envoyee ? vert : Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => enregistrerPdfFacture(context, widget.facture),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text("Télécharger"),
          ),
        ),
      ],
    );
  }
}
