import 'package:flutter/material.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:url_launcher/url_launcher.dart';

/// Droits du module « Syndics ». Le serveur reste juge ; l'application
/// évite seulement de proposer une action qui serait refusée.
bool get peutCreerSyndic => peut(AppPermission.createSyndic);

bool get peutModifierSyndic => peut(AppPermission.updateSyndic);

bool get peutSupprimerSyndic => peut(AppPermission.deleteSyndic);

bool get peutVoirHistoriqueSyndics => peut(AppPermission.viewSyndicHistory);

bool get peutRenvoyerContratSyndic => peut(AppPermission.resendSyndicContract);

/// Au moins une action de gestion sur les syndics.
bool get estAdminSyndics => peutCreerSyndic || peutModifierSyndic || peutSupprimerSyndic;

/// Le message d'une erreur remontée par le dépôt, sans le préfixe Dart.
String messageErreurSyndic(Object ex) {
  final texte = ex.toString().replaceFirst('Exception: ', '').trim();
  return texte.isEmpty ? "L'opération n'a pas abouti." : texte;
}

/// Ne garde que les chiffres d'un numéro saisi (espaces, +, tirets…).
String chiffresTelephone(String brut) => brut.replaceAll(RegExp(r'\D'), '');

/// Même règle que le serveur : 10 à 15 chiffres, sans 0 au début.
bool telephoneSyndicValide(String brut) =>
    RegExp(r'^[1-9]\d{9,14}$').hasMatch(chiffresTelephone(brut));

/// Une date de séjour venue du serveur, lisible en jj/mm/aaaa.
String dateSejourSyndic(String? brut) {
  if (brut == null || brut.isEmpty) return '';
  final d = DateTime.tryParse(brut);
  return d == null ? brut : dateExport(d);
}

String sejourSyndic(EnvoiSyndic e) {
  final debut = dateSejourSyndic(e.checkin);
  final fin = dateSejourSyndic(e.checkout);
  if (debut.isEmpty && fin.isEmpty) return '';
  if (fin.isEmpty) return 'Du $debut';
  if (debut.isEmpty) return "Jusqu'au $fin";
  return 'Du $debut au $fin';
}

Color couleurStatutEnvoi(String statut) {
  switch (statut) {
    case 'envoye':
      return Colors.green.shade700;
    case 'echec':
      return Colors.red.shade700;
    default:
      return Colors.orange.shade800;
  }
}

IconData iconeStatutEnvoi(String statut) {
  switch (statut) {
    case 'envoye':
      return Icons.check_circle_outline;
    case 'echec':
      return Icons.error_outline;
    default:
      return Icons.remove_circle_outline;
  }
}

String libelleStatutEnvoi(String statut) {
  switch (statut) {
    case 'envoye':
      return 'Envoyé';
    case 'echec':
      return 'Échec';
    case 'ignore':
      return 'Ignoré';
    default:
      return statut;
  }
}

/// Résumé du dernier envoi : « Contrat envoyé le … », « Échec : … »,
/// « Ignoré : … ».
String resumeEnvoiSyndic(EnvoiSyndic e) {
  final quand = dateHeureExport(e.le);
  switch (e.statut) {
    case 'envoye':
      return quand.isEmpty ? 'Contrat envoyé' : 'Contrat envoyé le $quand';
    case 'echec':
      return 'Échec : ${(e.erreur ?? '').isEmpty ? 'envoi non abouti' : e.erreur}'
          '${quand.isEmpty ? '' : ' ($quand)'}';
    case 'ignore':
      return 'Ignoré : ${(e.erreur ?? '').isEmpty ? 'envoi non effectué' : e.erreur}'
          '${quand.isEmpty ? '' : ' ($quand)'}';
    default:
      return quand.isEmpty ? e.statut : '${e.statut} ($quand)';
  }
}

class EtiquetteSyndic extends StatelessWidget {
  final String texte;
  final Color couleur;

  const EtiquetteSyndic({super.key, required this.texte, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: couleur),
      ),
    );
  }
}

class EtiquetteActifSyndic extends StatelessWidget {
  final bool actif;

  const EtiquetteActifSyndic({super.key, required this.actif});

  @override
  Widget build(BuildContext context) => EtiquetteSyndic(
        texte: actif ? 'Actif' : 'Inactif',
        couleur: actif ? Colors.green.shade700 : Colors.grey.shade600,
      );
}

Future<void> appelerSyndic(BuildContext context, String telephone) =>
    _ouvrir(context, Uri(scheme: 'tel', path: '+${chiffresTelephone(telephone)}'));

Future<void> whatsappSyndic(BuildContext context, String telephone) =>
    _ouvrir(context, Uri.parse('https://wa.me/${chiffresTelephone(telephone)}'));

Future<void> _ouvrir(BuildContext context, Uri uri) async {
  final messager = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception();
  } catch (_) {
    messager.showSnackBar(
      const SnackBar(content: Text("Aucune application ne peut ouvrir ce numéro.")),
    );
  }
}
