import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/apercu_suppression.dart';
import 'package:immobilier/models/booking.dart';
import 'package:immobilier/repository/repository.dart';

/// Ce qu'a décidé celui qui supprime une réservation.
class ChoixSuppression {
  /// Le client est-il remboursé ?
  final bool rembourse;

  /// Le montant rendu au client (seulement si [rembourse]).
  final double? montant;

  const ChoixSuppression({required this.rembourse, this.montant});
}

/// Demande, avant de supprimer une réservation, si le client est remboursé
/// et de combien. Rend null si l'utilisateur renonce.
Future<ChoixSuppression?> demanderSuppressionReservation(
    BuildContext context, Booking booking) {
  return showDialog<ChoixSuppression>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogueSuppressionReservation(bookingId: booking.id ?? 0),
  );
}

String _mad(double v) => '${v.toStringAsFixed(2)} MAD';

class _DialogueSuppressionReservation extends StatefulWidget {
  final int bookingId;

  const _DialogueSuppressionReservation({required this.bookingId});

  @override
  State<_DialogueSuppressionReservation> createState() =>
      _DialogueSuppressionReservationState();
}

class _DialogueSuppressionReservationState
    extends State<_DialogueSuppressionReservation> {
  late Future<ApercuSuppression> _chargement;
  final TextEditingController _montantCtrl = TextEditingController();
  bool? _rembourse;
  bool _montantInitialise = false;

  @override
  void initState() {
    super.initState();
    _chargement =
        Dependencies.get<Repository>().apercuSuppression(widget.bookingId);
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  double? _montantSaisi() =>
      double.tryParse(_montantCtrl.text.trim().replaceAll(' ', '').replaceAll(',', '.'));

  /// Le message d'erreur sur le montant, ou null s'il convient.
  String? _erreurMontant(ApercuSuppression a) {
    final m = _montantSaisi();
    if (m == null || m <= 0) return "Saisissez un montant supérieur à 0.";
    final plafond = math.max(a.revenu, a.encaisse);
    if (m > plafond + 0.001) {
      return "Le remboursement ne peut pas dépasser ${_mad(plafond)}";
    }
    final solde = a.caisseSolde;
    if (solde != null && m > solde + 0.001) {
      return "Votre caisse ne contient que ${_mad(solde)}";
    }
    return null;
  }

  bool _peutConfirmer(ApercuSuppression a) {
    if (_rembourse == null) return false;
    if (_rembourse == true) return _erreurMontant(a) == null;
    return true;
  }

  void _confirmer(ApercuSuppression a) {
    if (!_peutConfirmer(a)) return;
    Navigator.of(context).pop(ChoixSuppression(
      rembourse: _rembourse!,
      montant: _rembourse! ? _montantSaisi() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApercuSuppression>(
      future: _chargement,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AlertDialog(
            backgroundColor: Colors.white,
            content: SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          final msg = snap.error == null
              ? "Impossible de préparer la suppression."
              : snap.error.toString().replaceFirst('Exception: ', '');
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            icon: const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
            content: Text(msg, textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Fermer"),
              ),
            ],
          );
        }
        return _contenu(snap.data!);
      },
    );
  }

  Widget _contenu(ApercuSuppression a) {
    if (!_montantInitialise) {
      _montantInitialise = true;
      final defaut = a.encaisse > 0 ? a.encaisse : a.revenu;
      _montantCtrl.text = defaut > 0 ? defaut.toStringAsFixed(2) : '';
    }
    final erreur = _rembourse == true ? _erreurMontant(a) : null;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text("Supprimer la réservation",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((a.bien ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(a.bien!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  _ligne("Montant de la réservation", _mad(a.montant)),
                  _ligne("Encaissé", _mad(a.encaisse)),
                  const SizedBox(height: 4),
                  Text(
                    "Votre caisse : ${a.caisseNom ?? '—'} — ${_mad(a.caisseSolde ?? 0)}",
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text("Le client est-il remboursé ?",
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _choix("Oui", true, Icons.payments_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _choix("Non", false, Icons.money_off_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            if (_rembourse == true) ...[
              TextField(
                controller: _montantCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: "Montant remboursé",
                  suffixText: "MAD",
                  errorText: erreur,
                  errorMaxLines: 2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 6),
              _note("Ce montant sortira de votre caisse.", Colors.orange.shade800),
            ],
            if (_rembourse == false)
              _note("Aucune sortie de caisse : l'argent encaissé reste acquis à l'agence.",
                  Colors.grey.shade700),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Annuler"),
        ),
        ElevatedButton(
          onPressed: _peutConfirmer(a) ? () => _confirmer(a) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text("Supprimer la réservation"),
        ),
      ],
    );
  }

  Widget _ligne(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(libelle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          ),
          Text(valeur,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _choix(String libelle, bool valeur, IconData icone) {
    final choisi = _rembourse == valeur;
    return OutlinedButton.icon(
      onPressed: () => setState(() => _rembourse = valeur),
      icon: Icon(icone, size: 18),
      label: Text(libelle),
      style: OutlinedButton.styleFrom(
        backgroundColor: choisi ? AppColors.primaryColor : Colors.white,
        foregroundColor: choisi ? Colors.white : AppColors.primaryColor,
        side: const BorderSide(color: AppColors.primaryColor),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _note(String texte, Color couleur) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 15, color: couleur),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texte, style: TextStyle(fontSize: 12.5, color: couleur)),
        ),
      ],
    );
  }
}
