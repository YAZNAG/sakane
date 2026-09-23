import 'package:flutter/material.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/models/calendrier_bien.dart';

/// Couleurs et formats partages par les ecrans du calendrier.
class CouleursCalendrier {
  static const Color texte = Color(0xFF17262E);
  static const Color texteDoux = Color(0xFF6B7B84);
  static const Color bordure = Color(0xFFE2E8EC);
  static const Color fond = Color(0xFFF4F6F8);
  static const Color bloque = Color(0xFFE6EAED);
  static const Color rayures = Color(0xFFC3CCD2);
  static const Color prixSpecial = Color(0xFFE8710A);
  static const Color paye = Color(0xFF2E9E5B);
  static const Color partiel = Color(0xFFF08C00);
  static const Color nonPaye = Color(0xFFE03E3E);
  static const Color passee = Color(0xFF9AA7AF);
  static const Color erreur = Color(0xFFB3261E);
  // Baux de longue duree : violet, distinct des reservations.
  static const Color bail = Color(0xFF6D4AB0);
  static const Color bailTermine = Color(0xFFA99BC6);

  /// Couleur de la barre d'une reservation : grise une fois passee.
  /// Hors charges, toute reservation est consideree payee.
  static Color reservation(ReservationCalendrier r) => estPassee(r) ? passee : paye;

  static Color paiement(ReservationCalendrier r) => paye;

  // ── Les couleurs de la legende du calendrier ─────────────────────
  //
  // Une barre de sejour dit d'abord ce qui en a ete paye : vert quand
  // tout est regle, bleu quand une part reste due, rouge sombre quand
  // rien n'a ete encaisse. Airbnb garde son rouge, le bail son violet.

  static const Color sejourPaye = paye;
  static const Color sejourPartiel = Color(0xFF2C6FB5);
  static const Color sejourNonPaye = Color(0xFF8E1F1F);
  static const Color sejourAirbnb = Color(0xFFE03E3E);

  /// La couleur d'une barre selon le champ `paiement` du serveur.
  static Color selonPaiement(String paiement) => switch (paiement) {
        'partiel' => sejourPartiel,
        'non_paye' => sejourNonPaye,
        _ => sejourPaye,
      };
}

DateTime aujourdhui() => CalendrierBien.jour(DateTime.now());

bool estPassee(ReservationCalendrier r) =>
    r.passee || !r.checkout.isAfter(aujourdhui());

const List<String> moisFr = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

const List<String> moisCourtsFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

const List<String> joursFr = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

String titreMois(DateTime m) {
  final nom = moisFr[m.month - 1];
  return '${nom[0].toUpperCase()}${nom.substring(1)} ${m.year}';
}

/// « 12 sept. »
String dateCourte(DateTime d) => '${d.day} ${moisCourtsFr[d.month - 1]}';

/// « 12 sept. 2026 »
String dateMoyenne(DateTime d) => '${dateCourte(d)} ${d.year}';

/// « 29/09 » : la forme courte de la barre de sélection.
String dateChiffree(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// « jeudi 12 septembre 2026 »
String dateLongue(DateTime d) =>
    '${joursFr[d.weekday - 1]} ${d.day} ${moisFr[d.month - 1]} ${d.year}';

String pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';

/// Jours entre deux dates, a l'abri du changement d'heure.
int ecartJours(DateTime du, DateTime au) => DateTime.utc(au.year, au.month, au.day)
    .difference(DateTime.utc(du.year, du.month, du.day))
    .inDays;

int nuitsEntre(DateTime du, DateTime au) => ecartJours(du, au);

DateTime ajouterJours(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Prix compact pour une case : 450, 1,2k, 12k.
String prixCompact(double v) {
  if (v < 1000) {
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');
  }
  final k = v / 1000;
  if (k >= 10 || k == k.roundToDouble()) return '${k.round()}k';
  return '${k.toStringAsFixed(1).replaceAll('.', ',')}k';
}

/// Prix lisible : « 450 » ou « 450,50 ».
String prixSimple(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

double? lireMontant(String brut) =>
    double.tryParse(brut.trim().replaceAll(' ', '').replaceAll(',', '.'));

/// Le message a montrer pour une erreur venue du depot.
String messageErreur(Object ex) {
  if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
  if (ex is UnAuthorizedException) return AppStrings.authorizationError;
  if (ex is UnAuthenticatedException) {
    logout();
    return 'Session expirée.';
  }
  return ex.toString().replaceFirst('Exception: ', '');
}

void afficherMessage(BuildContext context, String texte, {bool erreur = false}) {
  final messager = ScaffoldMessenger.maybeOf(context);
  if (messager == null) return;
  messager
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texte),
      behavior: SnackBarBehavior.floating,
      backgroundColor: erreur ? CouleursCalendrier.erreur : const Color(0xFF263238),
      duration: const Duration(seconds: 5),
    ));
}

/// Demande une confirmation simple.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  required String message,
  required String action,
  Color? couleur,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: couleur ?? CouleursCalendrier.texte,
            foregroundColor: Colors.white,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Fond raye des jours bloques.
class RayuresPainter extends CustomPainter {
  final Color couleur;

  const RayuresPainter({this.couleur = CouleursCalendrier.rayures});

  @override
  void paint(Canvas canvas, Size size) {
    final pinceau = Paint()
      ..color = couleur
      ..strokeWidth = 1.2;
    const pas = 7.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += pas) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), pinceau);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RayuresPainter oldDelegate) => oldDelegate.couleur != couleur;
}
