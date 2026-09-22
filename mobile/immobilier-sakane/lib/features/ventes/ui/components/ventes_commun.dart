import 'package:flutter/material.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/routes.dart';

/// Teintes du module « Vente de biens ».
class CouleursVente {
  static const Color teinte = Color(0xFFE06A1F);
  static const Color fondTeinte = Color(0xFFFFECE0);
  static const Color aVendre = Color(0xFF2E9E5B);
  static const Color compromis = Color(0xFF2C6FB5);
  static const Color vendu = Color(0xFF6D4AB0);
  static const Color sansMandat = Color(0xFFE08A00);

  static Color statut(String? code) {
    switch (code) {
      case StatutVente.compromis:
        return compromis;
      case StatutVente.vendu:
        return vendu;
      default:
        return aVendre;
    }
  }

  static IconData iconeStatut(String? code) {
    switch (code) {
      case StatutVente.compromis:
        return Icons.handshake_outlined;
      case StatutVente.vendu:
        return Icons.verified_outlined;
      default:
        return Icons.sell_outlined;
    }
  }

  static Color suite(String? code) {
    switch (code) {
      case 'interesse':
        return const Color(0xFF2E9E5B);
      case 'offre':
        return const Color(0xFF6D4AB0);
      case 'a_relancer':
        return const Color(0xFFE08A00);
      case 'pas_interesse':
        return const Color(0xFFD64545);
      default:
        return CouleursBail.texteDoux;
    }
  }
}

bool _peutVente(AppPermission droit) {
  try {
    return Dependencies.get<Manager>().can(droit);
  } catch (_) {
    return false;
  }
}

/// Droits du module « Ventes » (l'administrateur les a tous).
bool get peutVoirVentes => _peutVente(AppPermission.viewSales);

bool get peutChangerStatutVente => _peutVente(AppPermission.updateSaleStatus);

bool get peutCreerMandat => _peutVente(AppPermission.createMandate);

/// Modifier ou envoyer un mandat.
bool get peutModifierMandat => _peutVente(AppPermission.updateMandate);

bool get peutSignerMandat => _peutVente(AppPermission.signMandate);

bool get peutSupprimerMandat => _peutVente(AppPermission.deleteMandate);

/// Créer, modifier ou envoyer un reçu de visite.
bool get peutCreerVisite => _peutVente(AppPermission.createVisit);

bool get peutSignerVisite => _peutVente(AppPermission.signVisit);

bool get peutSupprimerVisite => _peutVente(AppPermission.deleteVisit);

/// Au moins une action sur les ventes.
bool get peutGererVentes =>
    peutChangerStatutVente ||
    peutCreerMandat ||
    peutModifierMandat ||
    peutSignerMandat ||
    peutSupprimerMandat ||
    peutCreerVisite ||
    peutSignerVisite ||
    peutSupprimerVisite;

/// Chemin du dossier de vente d'un bien. [onglet] : mandats ou visites ;
/// [nouveauMandat] ouvre directement le formulaire du mandat.
String cheminDossierVente(int id, {String? onglet, bool nouveauMandat = false}) {
  final parametres = {
    if (onglet != null) 'onglet': onglet,
    if (nouveauMandat) 'mandat': '1',
  };
  return Uri(
    path: Routes.dossierVente.replaceFirst(':id', '$id'),
    queryParameters: parametres.isEmpty ? null : parametres,
  ).toString();
}

/// Chemin de la liste des biens en vente, filtree.
String cheminVentes({String filtre = 'tous'}) =>
    filtre == 'tous' ? Routes.ventes : '${Routes.ventes}?filtre=$filtre';

String prixVente(double? prix) => prix == null || prix <= 0 ? 'Prix non renseigné' : montantLisible(prix);

/// « 2,5 % »
String pourcentage(double? v) {
  if (v == null) return '—';
  final texte = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');
  return '${texte.replaceAll('.', ',')} %';
}

/// Pastille du statut de vente.
class PastilleStatutVente extends StatelessWidget {
  final String statut;
  final String? libelle;

  const PastilleStatutVente({super.key, required this.statut, this.libelle});

  @override
  Widget build(BuildContext context) => PastilleBail(
        texte: libelle ?? StatutVente.libelle(statut),
        couleur: CouleursVente.statut(statut),
        icone: CouleursVente.iconeStatut(statut),
      );
}

/// « Mandat jusqu'au … » ou « Sans mandat » en orange.
class PastilleMandat extends StatelessWidget {
  final MandatVente? mandat;

  const PastilleMandat({super.key, required this.mandat});

  @override
  Widget build(BuildContext context) {
    final m = mandat;
    if (m == null || !m.actif) {
      return const PastilleBail(texte: 'Sans mandat', couleur: CouleursVente.sansMandat, icone: Icons.warning_amber_rounded);
    }
    final bientot = (m.joursRestants ?? 999) <= 30;
    return PastilleBail(
      texte: m.dateFin == null ? 'Mandat actif' : "Mandat jusqu'au ${dateBail(m.dateFin)}",
      couleur: bientot ? CouleursVente.sansMandat : CouleursVente.compromis,
      icone: Icons.assignment_turned_in_outlined,
    );
  }
}
