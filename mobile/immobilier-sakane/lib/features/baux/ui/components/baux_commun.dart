import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/contrat/ui/visionneuse_contrat.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/routes.dart';
import 'package:url_launcher/url_launcher.dart';

/// Teintes du module « Location longue durée ».
class CouleursBail {
  static const Color teinte = Color(0xFF6D4AB0);
  static const Color fondTeinte = Color(0xFFF0EAFA);
  static const Color texte = Color(0xFF17262E);
  static const Color texteDoux = Color(0xFF6B7B84);
  static const Color bordure = Color(0xFFE2E8EC);
  static const Color fond = Color(0xFFF6F7F9);
  static const Color paye = Color(0xFF2E9E5B);
  static const Color partiel = Color(0xFFE08A00);
  static const Color retard = Color(0xFFD64545);
  static const Color aPayer = Color(0xFF2C6FB5);
  static const Color aVenir = Color(0xFF8A98A0);

  static Color statutLoyer(String statut) {
    switch (statut) {
      case 'paye':
        return paye;
      case 'partiel':
        return partiel;
      case 'en_retard':
        return retard;
      case 'a_payer':
        return aPayer;
      default:
        return aVenir;
    }
  }
}

String libelleStatutLoyer(String statut) {
  switch (statut) {
    case 'paye':
      return 'Payé';
    case 'partiel':
      return 'Partiel';
    case 'en_retard':
      return 'En retard';
    case 'a_payer':
      return 'À payer';
    default:
      return 'À venir';
  }
}

Manager? get _manager {
  try {
    return Dependencies.get<Manager>();
  } catch (_) {
    return null;
  }
}

bool _peut(AppPermission droit) => _manager?.can(droit) ?? false;

/// L'administrateur a tous les droits ; le serveur reste juge.
bool get peutVoirBaux => _peut(AppPermission.viewLeases);

/// Au moins une action sur les baux (création, modification, fin,
/// suppression ou encaissement des loyers).
bool get peutGererBaux =>
    peutCreerBail || peutModifierBail || peutTerminerBail || peutSupprimerBail || peutEncaisserLoyers;

bool get peutCreerBail => _peut(AppPermission.createLease);

/// Modifier, prolonger ou envoyer le contrat d'un bail.
bool get peutModifierBail => _peut(AppPermission.updateLease);

bool get peutTerminerBail => _peut(AppPermission.endLease);

bool get peutSupprimerBail => _peut(AppPermission.deleteLease);

/// Encaisser / annuler un loyer, envoyer une quittance.
bool get peutEncaisserLoyers => _peut(AppPermission.collectRent);

/// Le message a montrer pour une erreur venue du depot.
String messageErreurBail(Object ex) {
  if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
  if (ex is UnAuthorizedException) return AppStrings.authorizationError;
  if (ex is UnAuthenticatedException) {
    logout();
    return 'Session expirée.';
  }
  final texte = ex.toString().replaceFirst('Exception: ', '').trim();
  return texte.isEmpty ? "L'opération n'a pas abouti." : texte;
}

/// Chemin de la fiche d'un bail. « nouveau » : la fiche propose d'ouvrir le contrat.
String cheminBail(int id, {bool nouveau = false}) =>
    '${Routes.bailDetail.replaceFirst(':id', '$id')}${nouveau ? '?nouveau=1' : ''}';

/// « 12 sept. 2026 », ou un tiret.
String dateBail(DateTime? d) => d == null ? '—' : dateMoyenne(d);

String periodeBail(DateTime? du, DateTime? au) => 'Du ${dateBail(du)} au ${dateBail(au)}';

String libelleJoursRestants(int? jours) {
  if (jours == null) return '';
  if (jours < 0) return 'Échu depuis ${pluriel(-jours, 'jour')}';
  if (jours == 0) return "Se termine aujourd'hui";
  return 'Encore ${pluriel(jours, 'jour')}';
}

/// Ajoute des mois en gardant le jour (borne a la fin du mois).
DateTime ajouterMois(DateTime d, int mois) {
  final cible = DateTime(d.year, d.month + mois, 1);
  final dernier = DateTime(cible.year, cible.month + 1, 0).day;
  return DateTime(cible.year, cible.month, d.day > dernier ? dernier : d.day);
}

/// Fin d'un bail : la veille du meme jour, n mois plus tard.
DateTime finDeBail(DateTime debut, int mois) => ajouterJours(ajouterMois(debut, mois), -1);

/// Duree en mois, calculee comme le serveur : un mois commence compte.
/// C'est le plus petit n tel que debut + n mois - 1 jour >= fin.
int dureeMoisEntre(DateTime debut, DateTime fin) {
  var n = 1;
  while (n < 1200 && finDeBail(debut, n).isBefore(fin)) {
    n++;
  }
  return n;
}

String? _chiffresInternationaux(String? tel) {
  var chiffres = (tel ?? '').replaceAll(RegExp(r'\D'), '');
  if (chiffres.isEmpty) return null;
  if (chiffres.startsWith('00')) chiffres = chiffres.substring(2);
  if (chiffres.startsWith('0')) chiffres = '212${chiffres.substring(1)}';
  return chiffres;
}

Future<void> _lancer(BuildContext context, Uri uri) async {
  final messager = ScaffoldMessenger.maybeOf(context);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception();
  } catch (_) {
    messager?.showSnackBar(const SnackBar(content: Text('Action impossible sur cet appareil.')));
  }
}

Future<void> appelerLocataire(BuildContext context, String? tel) async {
  final chiffres = _chiffresInternationaux(tel);
  if (chiffres == null) return;
  await _lancer(context, Uri(scheme: 'tel', path: '+$chiffres'));
}

Future<void> whatsappLocataire(BuildContext context, String? tel) async {
  final chiffres = _chiffresInternationaux(tel);
  if (chiffres == null) return;
  await _lancer(context, Uri.parse('https://wa.me/$chiffres'));
}

/// Telecharge un PDF (contrat, quittance) puis l'ouvre dans la visionneuse.
Future<void> ouvrirPdfBail(BuildContext context, Future<String> Function() telecharger, String titre) async {
  final navigateur = Navigator.of(context, rootNavigator: true);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
  String? chemin;
  String? erreur;
  try {
    chemin = await telecharger();
  } catch (ex) {
    erreur = messageErreurBail(ex);
  }
  navigateur.pop();
  if (!context.mounted) return;
  if (chemin == null) {
    afficherMessage(context, erreur ?? "Le document n'a pas pu être ouvert.", erreur: true);
    return;
  }
  await VisionneuseContrat.ouvrir(context, chemin: chemin, titre: titre);
}

/// Affiche l'avertissement du serveur, s'il y en a un.
void afficherAvertissement(BuildContext context, String? avertissement) {
  if ((avertissement ?? '').trim().isEmpty) return;
  final messager = ScaffoldMessenger.maybeOf(context);
  messager
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(avertissement!.trim()),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFB26A00),
      duration: const Duration(seconds: 7),
    ));
}

class PastilleBail extends StatelessWidget {
  final String texte;
  final Color couleur;
  final IconData? icone;

  const PastilleBail({super.key, required this.texte, required this.couleur, this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: couleur),
            const SizedBox(width: 4),
          ],
          Text(texte, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleur)),
        ],
      ),
    );
  }
}

class PhotoBien extends StatelessWidget {
  final String? url;
  final double taille;

  const PhotoBien({super.key, this.url, this.taille = 58});

  @override
  Widget build(BuildContext context) {
    final vide = Container(
      width: taille,
      height: taille,
      color: CouleursBail.fondTeinte,
      child: const Icon(Icons.home_work_outlined, color: CouleursBail.teinte),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (url ?? '').isEmpty
          ? vide
          : CachedNetworkImage(
              imageUrl: url!,
              width: taille,
              height: taille,
              fit: BoxFit.cover,
              placeholder: (_, __) => vide,
              errorWidget: (_, __, ___) => vide,
            ),
    );
  }
}

/// Appel et WhatsApp, cote a cote.
class BoutonsContact extends StatelessWidget {
  final String? tel;

  const BoutonsContact({super.key, required this.tel});

  @override
  Widget build(BuildContext context) {
    if ((tel ?? '').trim().isEmpty) return const SizedBox();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _rond(context, Icons.call, const Color(0xFF2C6FB5), 'Appeler', () => appelerLocataire(context, tel)),
        const SizedBox(width: 6),
        _rond(context, FontAwesomeIcons.whatsapp, const Color(0xFF25D366), 'WhatsApp', () => whatsappLocataire(context, tel)),
      ],
    );
  }

  Widget _rond(BuildContext context, IconData icone, Color couleur, String aide, VoidCallback onTap) {
    return Tooltip(
      message: aide,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: couleur.withValues(alpha: .12), shape: BoxShape.circle),
          child: Center(child: FaIcon(icone, size: 18, color: couleur)),
        ),
      ),
    );
  }
}

/// Carte blanche arrondie des ecrans du module.
class CarteBail extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const CarteBail({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CouleursBail.bordure),
          ),
          child: child,
        ),
      ),
    );
  }
}

class TitreSection extends StatelessWidget {
  final String texte;
  final IconData icone;
  final Color couleur;
  final String? compteur;

  const TitreSection({
    super.key,
    required this.texte,
    required this.icone,
    this.couleur = CouleursBail.teinte,
    this.compteur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
          ),
          if (compteur != null) PastilleBail(texte: compteur!, couleur: couleur),
        ],
      ),
    );
  }
}

/// Un champ de saisie au style du module.
InputDecoration decorationBail(String label, {String? aide, String? suffixe, IconData? icone}) {
  return InputDecoration(
    labelText: label,
    helperText: aide,
    helperMaxLines: 3,
    suffixText: suffixe,
    prefixIcon: icone == null ? null : Icon(icone, size: 20),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: CouleursBail.bordure),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: CouleursBail.teinte, width: 1.5),
    ),
  );
}
