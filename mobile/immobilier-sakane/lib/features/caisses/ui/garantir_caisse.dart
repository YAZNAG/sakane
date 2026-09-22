import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/repository/repository.dart';

/// S'assure que la caisse peut recevoir — ou fournir — un montant.
///
/// Deux écueils, tous deux constatés en production :
///
///  * sans caisse ouverte, le serveur en ouvre une d'office et l'agent
///    découvre plus tard un solde dont il ignore l'origine ;
///  * un décaissement supérieur au solde est refusé côté serveur, mais
///    l'erreur y est seulement journalisée : l'opération passe et le
///    mouvement disparaît sans que personne le voie.
///
/// On vérifie donc ici, avant d'enregistrer quoi que ce soit.
/// Renvoie vrai lorsque l'enregistrement peut se poursuivre.
Future<bool> garantirCaisseOuverte(
  BuildContext context, {
  /// Ce que l'on s'apprete a enregistrer, au singulier.
  required String motif,

  /// Montant qui va sortir de la caisse, s'il y en a un. Le solde ne
  /// pouvant devenir negatif, on s'assure qu'elle le contient.
  double sortie = 0,
}) async {
  // Un encaissement n'a rien a verifier : la caisse s'ouvre d'elle-meme
  // cote serveur, et l'argent s'y range aussitot.
  if (sortie <= 0) return true;

  final double solde;
  try {
    final ma = await Dependencies.get<Repository>().maCaisse();
    // Une caisse fermee ne contient rien.
    solde = ma.ouverte ? ma.solde : 0;
  } catch (_) {
    // Caisse injoignable : on laisse le serveur trancher.
    return true;
  }

  if (solde + 0.005 < sortie) {
    if (!context.mounted) return false;
    await showDialog(
      context: context,
      builder: (_) => _SoldeInsuffisant(solde: solde, demande: sortie),
    );
    return false;
  }

  return true;
}

// ── Le solde ne suffit pas ──────────────────────────────────────────

class _SoldeInsuffisant extends StatelessWidget {
  final double solde;
  final double demande;

  const _SoldeInsuffisant({required this.solde, required this.demande});

  @override
  Widget build(BuildContext context) {
    final manque = demande - solde;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: Color(0xFFA8542B), size: 21),
          const SizedBox(width: 9),
          const Expanded(
            child: Text("Caisse insuffisante",
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Votre caisse contient ${montantLisible(solde)}, "
            "et il en faudrait ${montantLisible(demande)}.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 10),
          Text(
            "Il vous manque ${montantLisible(manque)}. Encaissez d'abord, "
            "ou déclarez un apport depuis l'écran de la caisse.",
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text("J'ai compris"),
        ),
      ],
    );
  }
}

/// « 1 250,50 MAD »
String montantLisible(double m) {
  final entier = m.abs().truncate();
  final decimales = ((m.abs() - entier) * 100).round();
  final chiffres = entier.toString();

  final tampon = StringBuffer();
  for (int i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(" ");
    tampon.write(chiffres[i]);
  }

  final fraction =
      decimales == 0 ? "" : ",${decimales.toString().padLeft(2, '0')}";
  return "$tampon$fraction MAD";
}
