import 'package:immobilier/repository/repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/bandeau_synchro.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/departs_du_jour.dart';
import 'package:immobilier/features/home/cubit/resume_accueil_cubit.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/home/ui/components/carte_caisse_accueil.dart';
import 'package:immobilier/features/home/ui/components/entete_accueil.dart';
import 'package:immobilier/features/home/ui/components/tuiles_aujourdhui.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/module_accueil.dart';
import 'package:immobilier/models/resume_accueil.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart' show peutVoirVentes;
import 'package:immobilier/routes.dart';

/// Un module de l'accueil.
///
/// Chaque module porte sa propre teinte : c'est elle que l'agent
/// reconnaît du coin de l'œil, avant même de lire le libellé. Elle est
/// donc indépendante de la couleur de la marque, qui habille l'en-tête.
class _Module {
  final String titre;
  final IconData icone;
  final Color fond;
  final Color teinte;
  final String route;
  final AppPermission? permission;

  /// Le module s'affiche si l'utilisateur a au moins un de ces droits
  /// (en plus de [permission] s'il est donné).
  final List<AppPermission>? auMoinsUn;

  /// Pour un raccourci : la rubrique où il se range dans le choix de la
  /// barre, et le libellé court affiché dans la barre.
  final String? groupe;
  final String? court;

  /// Module du catalogue qui n'est pas posé d'office sur l'accueil :
  /// l'utilisateur l'y met avec « Ajouter un module ».
  final bool horsAccueil;

  /// Contrôle d'accès propre au module, en plus du droit et du rôle.
  final bool Function(Manager)? acces;

  const _Module({
    required this.titre,
    required this.icone,
    required this.fond,
    required this.teinte,
    required this.route,
    this.permission,
    this.auMoinsUn,
    this.groupe,
    this.court,
    this.horsAccueil = false,
    this.acces,
  });
}

/// Les droits qui ouvrent la gestion des biens : la liste ou un état.
const List<AppPermission> _droitsBiens = [
  AppPermission.viewProperties,
  AppPermission.viewAvailableProperties,
  AppPermission.viewReservedProperties,
  AppPermission.viewCleaningProperties,
  AppPermission.viewTodayCheckouts,
];

/// Le catalogue, dans l'ordre où un accueil neuf le présente : les sept
/// premiers tiennent sur les deux rangées de la maquette, le reste
/// s'atteint par « Tous ».
const List<_Module> _modules = [
  _Module(
    titre: 'Immobilier',
    court: 'Biens',
    icone: FontAwesomeIcons.building,
    fond: Color(0xFFFFF1E0),
    teinte: Color(0xFFD97E1A),
    route: Routes.gestionImmobilier,
    auMoinsUn: _droitsBiens,
  ),
  _Module(
    titre: 'Réservations',
    icone: FontAwesomeIcons.calendarCheck,
    fond: Color(0xFFE1F1F0),
    teinte: Color(0xFF157F76),
    route: Routes.reservation,
    permission: AppPermission.viewReservations,
  ),
  _Module(
    titre: 'Calendrier',
    icone: FontAwesomeIcons.calendarDays,
    fond: Color(0xFFEAF1FB),
    teinte: Color(0xFF3B6FD4),
    route: Routes.calendrierBiens,
    permission: AppPermission.viewCalendar,
  ),
  _Module(
    titre: 'Clients',
    icone: FontAwesomeIcons.userTie,
    fond: Color(0xFFEAEEF9),
    teinte: Color(0xFF3D5AA8),
    route: Routes.clients,
    permission: AppPermission.viewClients,
  ),
  _Module(
    titre: 'Statistiques',
    icone: FontAwesomeIcons.chartLine,
    fond: Color(0xFFE5EFF9),
    teinte: Color(0xFF2C6FB5),
    route: Routes.financialStats,
    permission: AppPermission.viewStats,
  ),
  _Module(
    titre: 'Les Charges',
    icone: FontAwesomeIcons.fileInvoiceDollar,
    fond: Color(0xFFFDE8E8),
    teinte: Color(0xFFD64545),
    route: Routes.charges,
    permission: AppPermission.viewCharges,
  ),
  _Module(
    titre: 'Réclamations',
    icone: FontAwesomeIcons.triangleExclamation,
    fond: Color(0xFFFFECE0),
    teinte: Color(0xFFE06A1F),
    route: Routes.reclamationsList,
    permission: AppPermission.viewReclamations,
  ),
  // Au-delà des sept premiers : présents sur l'accueil, mais atteints
  // par « Tous » tant que l'utilisateur ne les a pas remontés.
  _Module(
    titre: 'Plateforme',
    icone: FontAwesomeIcons.globe,
    fond: Color(0xFFF4E9F5),
    teinte: Color(0xFF9B3DA0),
    route: Routes.platform,
    auMoinsUn: [
      AppPermission.viewAnnounces,
      AppPermission.activateAnnounce,
      AppPermission.cancelAnnounce,
      AppPermission.viewSlider,
      AppPermission.createSlider,
      AppPermission.activateSlider,
    ],
  ),
  _Module(
    titre: 'Utilisateurs',
    icone: FontAwesomeIcons.users,
    fond: Color(0xFFE7F4E9),
    teinte: Color(0xFF2E8B45),
    route: Routes.users,
    permission: AppPermission.viewUsers,
  ),
  _Module(
    titre: 'Propriétaires',
    icone: FontAwesomeIcons.userShield,
    fond: Color(0xFFFFF7DC),
    teinte: Color(0xFFC29411),
    route: Routes.owners,
    permission: AppPermission.viewOwners,
  ),
  _Module(
    titre: 'Campagnes',
    icone: FontAwesomeIcons.bullhorn,
    fond: Color(0xFFECEAFB),
    teinte: Color(0xFF6153C9),
    route: Routes.campagnes,
    permission: AppPermission.viewCampaigns,
  ),
  _Module(
    titre: 'Caisse',
    icone: FontAwesomeIcons.wallet,
    fond: Color(0xFFE3EFE7),
    teinte: Color(0xFF2F6B4F),
    route: Routes.caisses,
    permission: AppPermission.viewOwnCashbox,
  ),
  _Module(
    titre: 'Export réservations',
    icone: FontAwesomeIcons.fileArrowDown,
    fond: Color(0xFFE4F1EC),
    teinte: Color(0xFF1E8560),
    route: Routes.exportReservations,
    permission: AppPermission.exportReservations,
  ),
  _Module(
    titre: 'Charges annulées',
    icone: FontAwesomeIcons.ban,
    fond: Color(0xFFFDF2E7),
    teinte: Color(0xFFA8542B),
    route: Routes.chargesAnnulees,
    permission: AppPermission.viewCancelledCharges,
  ),
  _Module(
    titre: 'Corbeille',
    icone: FontAwesomeIcons.trashCan,
    fond: Color(0xFFFDEBEC),
    teinte: Color(0xFFB3261E),
    route: Routes.corbeilleReservations,
    permission: AppPermission.viewReservationTrash,
  ),
  _Module(
    titre: 'Modèles de messages',
    icone: FontAwesomeIcons.penToSquare,
    fond: Color(0xFFE9F0FB),
    teinte: Color(0xFF3B6FD4),
    route: Routes.modelesMessages,
    permission: AppPermission.viewMessageTemplates,
  ),
  _Module(
    titre: 'Syndics',
    icone: FontAwesomeIcons.buildingUser,
    fond: Color(0xFFE3F0F4),
    teinte: Color(0xFF2A7189),
    route: Routes.syndics,
    permission: AppPermission.viewSyndics,
  ),
  _Module(
    titre: 'Droits et permissions',
    icone: FontAwesomeIcons.shieldHalved,
    fond: Color(0xFFEDEAF8),
    teinte: Color(0xFF5B4BB7),
    route: Routes.permissions,
    permission: AppPermission.managePermissions,
  ),
  // « Heures par défaut » ne figure plus sur l'accueil : la page s'ouvre
  // depuis le menu de la liste des réservations (administrateurs).
  // La location longue duree ne figure pas sur l'accueil : elle s'ouvre
  // depuis la gestion des biens (etats du type « location longue durée »).
  // Modules du catalogue : absents de l'accueil tant que l'utilisateur ne
  // les a pas ajoutés (« Ajouter un module »).
  _Module(
    titre: 'Airbnb',
    icone: FontAwesomeIcons.airbnb,
    fond: Color(0xFFFFEBEC),
    teinte: Color(0xFFFF5A5F),
    route: Routes.airbnbBiens,
    permission: AppPermission.viewAirbnb,
    horsAccueil: true,
  ),
  _Module(
    titre: 'Réception WhatsApp',
    icone: FontAwesomeIcons.whatsapp,
    fond: Color(0xFFE3F7EA),
    teinte: Color(0xFF1FA855),
    route: Routes.receptionWhatsapp,
    permission: AppPermission.manageOwnWhatsapp,
    horsAccueil: true,
  ),
  _Module(
    titre: "WhatsApp de l'équipe",
    icone: FontAwesomeIcons.commentDots,
    fond: Color(0xFFE3F7EA),
    teinte: Color(0xFF1FA855),
    route: Routes.receptionsWhatsapp,
    permission: AppPermission.manageTeamWhatsapp,
    horsAccueil: true,
  ),
  _Module(
    titre: 'Ventes',
    icone: FontAwesomeIcons.handshake,
    fond: Color(0xFFFFECE0),
    teinte: Color(0xFFE06A1F),
    route: Routes.dossiersVente,
    acces: _voitVentes,
    horsAccueil: true,
  ),
  _Module(
    titre: 'Visites de vente',
    icone: FontAwesomeIcons.personWalking,
    fond: Color(0xFFFFF1E0),
    teinte: Color(0xFFD97E1A),
    route: Routes.visitesVentes,
    acces: _voitVentes,
    horsAccueil: true,
  ),
];

/// Les mêmes contrôles que les écrans de vente.
bool _voitVentes(Manager _) => peutVoirVentes;

/// Les raccourcis qu'on peut placer dans la barre du bas : un état de
/// biens précis ou une action fréquente, sans passer par les écrans.
const List<_Module> _raccourcis = [
  _Module(
    groupe: 'Location courte durée',
    titre: 'Biens disponibles',
    court: 'Dispo. vacances',
    icone: FontAwesomeIcons.circleCheck,
    fond: Color(0xFFE7F4E9),
    teinte: Color(0xFF2E8B45),
    route: '/immobilier-stats/available?type=rent-short',
    permission: AppPermission.viewAvailableProperties,
  ),
  _Module(
    groupe: 'Location courte durée',
    titre: 'Biens réservés',
    court: 'Réservés vac.',
    icone: FontAwesomeIcons.calendarXmark,
    fond: Color(0xFFFDE8E8),
    teinte: Color(0xFFD64545),
    route: '/immobilier-stats/reserved?type=rent-short',
    permission: AppPermission.viewReservedProperties,
  ),
  _Module(
    groupe: 'Location courte durée',
    titre: 'En nettoyage',
    court: 'Nettoyage',
    icone: FontAwesomeIcons.broom,
    fond: Color(0xFFFFF1E0),
    teinte: Color(0xFFD97E1A),
    route: '/immobilier-stats/cleaning?type=rent-short',
    permission: AppPermission.viewCleaningProperties,
  ),
  _Module(
    groupe: 'Location courte durée',
    titre: 'Tous les biens',
    court: 'Biens vacances',
    icone: FontAwesomeIcons.umbrellaBeach,
    fond: Color(0xFFE1F1F0),
    teinte: Color(0xFF157F76),
    route: '/immobilier-list?type=rent-short',
    permission: AppPermission.viewProperties,
  ),
  _Module(
    groupe: 'Location longue durée',
    titre: 'Biens disponibles',
    court: 'Dispo. longue',
    icone: FontAwesomeIcons.circleCheck,
    fond: Color(0xFFE7F4E9),
    teinte: Color(0xFF2E8B45),
    route: '/immobilier-stats/available?type=rent-long',
    permission: AppPermission.viewAvailableProperties,
  ),
  _Module(
    groupe: 'Location longue durée',
    titre: 'Biens loués',
    court: 'Loués',
    icone: FontAwesomeIcons.key,
    fond: Color(0xFFF4E9F5),
    teinte: Color(0xFF9B3DA0),
    route: '/immobilier-stats/reserved?type=rent-long',
    permission: AppPermission.viewReservedProperties,
  ),
  _Module(
    groupe: 'Location longue durée',
    titre: 'Tous les biens',
    court: 'Biens longue',
    icone: FontAwesomeIcons.building,
    fond: Color(0xFFF4E9F5),
    teinte: Color(0xFF9B3DA0),
    route: '/immobilier-list?type=rent-long',
    permission: AppPermission.viewProperties,
  ),
  _Module(
    groupe: 'Vente',
    titre: 'Biens à vendre',
    court: 'À vendre',
    icone: FontAwesomeIcons.tag,
    fond: Color(0xFFFFECE0),
    teinte: Color(0xFFE06A1F),
    route: '/immobilier-stats/available?type=selle',
    permission: AppPermission.viewAvailableProperties,
  ),
  _Module(
    groupe: 'Vente',
    titre: 'Tous les biens',
    court: 'Biens vente',
    icone: FontAwesomeIcons.house,
    fond: Color(0xFFFFECE0),
    teinte: Color(0xFFE06A1F),
    route: '/immobilier-list?type=selle',
    permission: AppPermission.viewProperties,
  ),
  _Module(
    groupe: 'Actions rapides',
    titre: 'Ajouter une réservation',
    court: '+ Réservation',
    icone: FontAwesomeIcons.calendarPlus,
    fond: Color(0xFFE1F1F0),
    teinte: Color(0xFF157F76),
    route: Routes.nouvelleReservation,
    permission: AppPermission.createReservation,
  ),
  _Module(
    groupe: 'Actions rapides',
    titre: 'Ajouter une charge',
    court: '+ Charge',
    icone: FontAwesomeIcons.fileCirclePlus,
    fond: Color(0xFFFDE8E8),
    teinte: Color(0xFFD64545),
    route: Routes.addCharge,
    permission: AppPermission.createCharge,
  ),
  _Module(
    groupe: 'Actions rapides',
    titre: 'Ajouter un client',
    court: '+ Client',
    icone: FontAwesomeIcons.userPlus,
    fond: Color(0xFFEAEEF9),
    teinte: Color(0xFF3D5AA8),
    route: Routes.addClient,
    permission: AppPermission.createClient,
  ),
  _Module(
    groupe: 'Actions rapides',
    titre: 'Ajouter un bien',
    court: '+ Bien',
    icone: FontAwesomeIcons.plus,
    fond: Color(0xFFFFF1E0),
    teinte: Color(0xFFD97E1A),
    route: Routes.addImmobilier,
    permission: AppPermission.createProperty,
  ),
  _Module(
    groupe: 'Actions rapides',
    titre: 'Ajouter un propriétaire',
    court: '+ Propriétaire',
    icone: FontAwesomeIcons.userShield,
    fond: Color(0xFFFFF7DC),
    teinte: Color(0xFFC29411),
    route: Routes.addOwner,
    permission: AppPermission.createOwner,
  ),
  _Module(
    groupe: 'Actions rapides',
    titre: 'Nouvelle campagne',
    court: '+ Campagne',
    icone: FontAwesomeIcons.bullhorn,
    fond: Color(0xFFECEAFB),
    teinte: Color(0xFF6153C9),
    route: Routes.addCampagne,
    permission: AppPermission.createCampaign,
  ),
  // « Charges programmées » ne figure plus au catalogue : la page et sa
  // route restent disponibles, mais elles ne sont plus proposées ici.
  _Module(
    groupe: 'Autres pages',
    titre: 'Liste de tous les biens',
    court: 'Biens',
    icone: FontAwesomeIcons.houseChimney,
    fond: Color(0xFFFFF1E0),
    teinte: Color(0xFFD97E1A),
    route: Routes.immobilier,
    permission: AppPermission.viewProperties,
  ),
];

/// Les icônes proposées pour un dossier.
const Map<String, IconData> _bibliothequeIcones = {
  'dossier': Icons.folder_rounded,
  'dossier_etoile': Icons.folder_special_rounded,
  'etoile': Icons.star_rounded,
  'coeur': Icons.favorite_rounded,
  'marque_page': Icons.bookmark_rounded,
  'maison': Icons.home_rounded,
  'immeuble': Icons.apartment_rounded,
  'maison_simple': Icons.house_rounded,
  'villa': Icons.villa_rounded,
  'chalet': Icons.cottage_rounded,
  'cabane': Icons.cabin_rounded,
  'hotel': Icons.hotel_rounded,
  'lit': Icons.bed_rounded,
  'grand_lit': Icons.king_bed_rounded,
  'baignoire': Icons.bathtub_rounded,
  'cuisine': Icons.kitchen_rounded,
  'chaise': Icons.chair_rounded,
  'canape': Icons.weekend_rounded,
  'cle': Icons.key_rounded,
  'cle_acces': Icons.vpn_key_rounded,
  'cadenas': Icons.lock_rounded,
  'porte': Icons.door_front_door_rounded,
  'salle': Icons.meeting_room_rounded,
  'ville': Icons.location_city_rounded,
  'bureau': Icons.business_rounded,
  'boutique': Icons.store_rounded,
  'vitrine': Icons.storefront_rounded,
  'plage': Icons.beach_access_rounded,
  'piscine': Icons.pool_rounded,
  'parc': Icons.park_rounded,
  'paysage': Icons.landscape_rounded,
  'soleil': Icons.wb_sunny_rounded,
  'nuit': Icons.nightlight_rounded,
  'evenement': Icons.event_rounded,
  'calendrier': Icons.calendar_month_rounded,
  'disponible': Icons.event_available_rounded,
  'horloge': Icons.schedule_rounded,
  'reveil': Icons.alarm_rounded,
  'aujourdhui': Icons.today_rounded,
  'personnes': Icons.people_rounded,
  'personne': Icons.person_rounded,
  'groupe': Icons.group_rounded,
  'badge': Icons.badge_rounded,
  'agent': Icons.support_agent_rounded,
  'accord': Icons.handshake_rounded,
  'visage': Icons.face_rounded,
  'famille': Icons.family_restroom_rounded,
  'portefeuille': Icons.account_balance_wallet_rounded,
  'paiements': Icons.payments_rounded,
  'argent': Icons.attach_money_rounded,
  'epargne': Icons.savings_rounded,
  'carte': Icons.credit_card_rounded,
  'recu': Icons.receipt_long_rounded,
  'devis': Icons.request_quote_rounded,
  'caisse': Icons.point_of_sale_rounded,
  'banque': Icons.account_balance_rounded,
  'hausse': Icons.trending_up_rounded,
  'barres': Icons.bar_chart_rounded,
  'camembert': Icons.pie_chart_rounded,
  'analyse': Icons.insights_rounded,
  'statistiques': Icons.analytics_rounded,
  'classement': Icons.leaderboard_rounded,
  'document': Icons.description_rounded,
  'article': Icons.article_rounded,
  'tache': Icons.assignment_rounded,
  'verification': Icons.fact_check_rounded,
  'liste': Icons.checklist_rounded,
  'valide': Icons.task_alt_rounded,
  'inventaire': Icons.inventory_2_rounded,
  'archive': Icons.archive_rounded,
  'imprimante': Icons.print_rounded,
  'telechargement': Icons.file_download_rounded,
  'nuage': Icons.cloud_rounded,
  'courrier': Icons.mail_rounded,
  'discussion': Icons.chat_rounded,
  'telephone': Icons.phone_rounded,
  'notification': Icons.notifications_rounded,
  'annonce': Icons.campaign_rounded,
  'message': Icons.message_rounded,
  'reglages': Icons.settings_rounded,
  'outil': Icons.build_rounded,
  'bricolage': Icons.handyman_rounded,
  'plomberie': Icons.plumbing_rounded,
  'electricite': Icons.electrical_services_rounded,
  'menage': Icons.cleaning_services_rounded,
  'linge': Icons.local_laundry_service_rounded,
  'corbeille': Icons.delete_rounded,
  'alerte': Icons.warning_rounded,
  'probleme': Icons.report_problem_rounded,
  'securite': Icons.security_rounded,
  'parking': Icons.local_parking_rounded,
  'voiture': Icons.directions_car_rounded,
  'livraison': Icons.local_shipping_rounded,
  'avion': Icons.flight_rounded,
  'plan': Icons.map_rounded,
  'lieu': Icons.place_rounded,
  'monde': Icons.public_rounded,
  'wifi': Icons.wifi_rounded,
  'television': Icons.tv_rounded,
  'cafe': Icons.local_cafe_rounded,
};

/// Les couleurs proposées pour l'icône d'un dossier.
const List<Color> _couleursDossier = [
  Color(0xFF1F5F8B),
  Color(0xFF0E7C86),
  Color(0xFF2E8B45),
  Color(0xFF7CB342),
  Color(0xFFF9A825),
  Color(0xFFD97E1A),
  Color(0xFFE06A1F),
  Color(0xFFD64545),
  Color(0xFFC2185B),
  Color(0xFF9B3DA0),
  Color(0xFF6153C9),
  Color(0xFF3D5AA8),
  Color(0xFF546E7A),
  Color(0xFF17262E),
];

/// L'icône d'un dossier : image choisie, icône de la bibliothèque, ou
/// l'icône de dossier par défaut.
Widget _iconeDossier(_Element d, {double taille = 20, Color? couleur, double arrondi = 6}) {
  final image = d.image;
  if (image != null && File(image).existsSync()) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(arrondi),
      child: Image.file(File(image), width: taille, height: taille, fit: BoxFit.cover),
    );
  }
  return Icon(
    _bibliothequeIcones[d.icone] ?? Icons.folder_rounded,
    size: taille,
    color: d.couleur != null ? Color(d.couleur!) : (couleur ?? AppColors.primaryColor),
  );
}

/// Un élément de l'accueil : un module seul, ou un dossier qui en
/// regroupe plusieurs sous un nom choisi par l'utilisateur.
class _Element {
  final String? route;
  final String? id;
  String nom;
  final List<String> routes;

  /// Pour un dossier : une icône de la bibliothèque, ou le chemin d'une
  /// image choisie dans le téléphone. L'image l'emporte.
  String? icone;
  String? image;

  /// Couleur de l'icône (ARGB). Nulle : couleur de l'application.
  int? couleur;

  _Element.module(this.route)
      : id = null,
        nom = '',
        routes = [];

  _Element.dossier({
    required this.id,
    required this.nom,
    required this.routes,
    this.icone,
    this.image,
    this.couleur,
  }) : route = null;

  bool get estDossier => id != null;

  Map<String, dynamic> toJson() =>
      estDossier
          ? {'d': id, 'n': nom, 'r': routes, if (icone != null) 'i': icone, if (image != null) 'img': image, if (couleur != null) 'c': couleur}
          : {'m': route};

  static _Element? fromJson(Map<String, dynamic> j) {
    if (j['m'] is String) return _Element.module(j['m'] as String);
    if (j['d'] is String) {
      return _Element.dossier(
        id: j['d'] as String,
        nom: (j['n'] ?? 'Dossier').toString(),
        routes: ((j['r'] ?? []) as List).whereType<String>().toList(),
        icone: j['i'] as String?,
        image: j['img'] as String?,
        couleur: (j['c'] as num?)?.toInt(),
      );
    }
    return null;
  }
}

/// La disposition de l'accueil, propre à chaque utilisateur et gardée
/// sur le téléphone.
///
/// Un module ajouté plus tard, ou devenu accessible, rejoint la fin ; un
/// module dont le droit a été retiré disparaît, y compris des dossiers.
class _Disposition {
  static String _cle(Manager m) => 'accueil_disposition_${m.id ?? 0}';

  /// [sansAjout] : modules gardés s'ils sont déjà placés, mais qu'on
  /// n'ajoute pas d'office à la fin (modules du catalogue).
  static List<_Element> reconcilier(
    List<_Element> elements,
    List<_Module> visibles, {
    Set<String> sansAjout = const {},
  }) {
    final permises = visibles.map((m) => m.route).toSet();
    final vus = <String>{};
    final resultat = <_Element>[];

    for (final e in elements) {
      if (e.estDossier) {
        e.routes.retainWhere((r) => permises.contains(r) && vus.add(r));
        if (e.routes.isNotEmpty) resultat.add(e);
      } else if (permises.contains(e.route) && vus.add(e.route!)) {
        resultat.add(e);
      }
    }
    for (final m in visibles) {
      if (!vus.contains(m.route) && !sansAjout.contains(m.route)) {
        resultat.add(_Element.module(m.route));
      }
    }
    return resultat;
  }

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static int? _lectureDe;
  static Future<Map<String, dynamic>?>? _lecture;

  /// L'organisation gardée sur le serveur, lue une fois par utilisateur :
  /// elle suit l'utilisateur d'un téléphone à l'autre et survit aux
  /// mises à jour comme aux réinstallations. Nulle sans réseau.
  static Future<Map<String, dynamic>?> _serveur(Manager m) {
    if (_lectureDe != m.id || _lecture == null) {
      _lectureDe = m.id;
      _lecture = Dependencies.get<Repository>()
          .lireDispositionAccueil()
          .timeout(const Duration(seconds: 8))
          .then<Map<String, dynamic>?>((v) => v, onError: (_) => null);
    }
    return _lecture!;
  }

  static List<_Element> _lireElements(Object? brut) {
    if (brut is! List) return [];
    return brut
        .whereType<Map>()
        .map((e) => _Element.fromJson(Map<String, dynamic>.from(e)))
        .whereType<_Element>()
        .toList();
  }

  static Future<List<_Element>> charger(
    Manager m,
    List<_Module> visibles, {
    Set<String> sansAjout = const {},
  }) async {
    final prefs = await _prefs();
    final serveur = await _serveur(m);

    if (serveur != null && serveur['disposition'] is List) {
      final liste = serveur['disposition'] as List;
      try {
        await prefs?.setString(_cle(m), jsonEncode(liste));
      } catch (_) {}
      return reconcilier(_lireElements(liste), visibles, sansAjout: sansAjout);
    }

    var elements = <_Element>[];
    try {
      final brut = prefs?.getString(_cle(m));
      if (brut != null) {
        elements = _lireElements(jsonDecode(brut));
        // Organisation faite avant la synchronisation : on la confie au
        // serveur pour qu'elle ne se perde plus.
        if (serveur != null) _envoyer(m);
      }
    } catch (_) {
      elements = [];
    }
    return reconcilier(elements, visibles, sansAjout: sansAjout);
  }

  static Future<void> enregistrer(Manager m, List<_Element> elements) async {
    final prefs = await _prefs();
    try {
      await prefs?.setString(_cle(m), jsonEncode(elements.map((e) => e.toJson()).toList()));
    } catch (_) {}
    await _envoyer(m);
  }

  static String _cleBarre(Manager m) => 'accueil_barre_${m.id ?? 0}';

  static Future<List<String>?> chargerBarre(Manager m) async {
    final prefs = await _prefs();
    final serveur = await _serveur(m);

    if (serveur != null && serveur['barre'] is List) {
      final barre = (serveur['barre'] as List).whereType<String>().toList();
      try {
        await prefs?.setStringList(_cleBarre(m), barre);
      } catch (_) {}
      return barre;
    }

    try {
      final locale = prefs?.getStringList(_cleBarre(m));
      if (locale != null && serveur != null) _envoyer(m);
      return locale;
    } catch (_) {
      return null;
    }
  }

  static Future<void> enregistrerBarre(Manager m, List<String> routes) async {
    final prefs = await _prefs();
    try {
      await prefs?.setStringList(_cleBarre(m), routes);
    } catch (_) {}
    await _envoyer(m);
  }

  static Future<void> effacer(Manager m) async {
    final prefs = await _prefs();
    try {
      await prefs?.remove(_cle(m));
    } catch (_) {}
    await _envoyer(m);
  }

  /// Confie au serveur l'organisation telle qu'elle est sur le téléphone.
  /// Sans réseau, la copie locale reste : elle partira au prochain
  /// changement.
  static Future<void> _envoyer(Manager m) async {
    try {
      final prefs = await _prefs();
      final brut = prefs?.getString(_cle(m));
      final corps = <String, dynamic>{
        'disposition': brut == null ? null : jsonDecode(brut),
        'barre': prefs?.getStringList(_cleBarre(m)),
      };
      _lectureDe = m.id;
      _lecture = Future.value(corps);
      await Dependencies.get<Repository>().enregistrerDispositionAccueil(corps);
    } catch (_) {}
  }
}

/// L'accueil : qui est là, ce qu'il a en caisse, ce qui l'attend
/// aujourd'hui, puis ses modules.
///
/// Le résumé du serveur porte les trois premiers blocs ; les modules, eux,
/// ne dépendent que des droits et de la disposition gardée. Un résumé
/// qui n'arrive pas masque donc des chiffres, jamais l'accès aux écrans.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ResumeAccueilCubit>(
      create: (_) => ResumeAccueilCubit()..charger(),
      child: const _Accueil(),
    );
  }
}

class _Accueil extends StatefulWidget {
  const _Accueil();

  @override
  State<_Accueil> createState() => _HomePageState();
}

class _HomePageState extends State<_Accueil> {
  final Manager manager = Dependencies.get<Manager>();
  late final List<_Module> _visibles;
  late final Map<String, _Module> _parRoute;
  late final List<_Module> _raccourcisVisibles;
  late final Map<String, _Module> _raccourcisParRoute;
  late List<_Element> _elements;

  /// En mode « organiser », on déplace les cartes et on en sélectionne
  /// pour les ranger dans un dossier.
  bool _organiser = false;
  final Set<String> _selection = {};

  /// Les modules de la barre du bas, choisis par l'utilisateur. Nul tant
  /// qu'il n'a rien choisi : la barre garde ses raccourcis d'usage.
  List<String>? _barre;

  /// Modules masqués ou renommés, par code (chemin de la route). Vide :
  /// tout est visible sous son nom d'origine (aussi quand la lecture a échoué).
  Map<String, ModuleAccueil> _reglages = {};
  int _sequenceReglages = 0;

  /// La barre de la maquette : Accueil, Biens, Calendrier, Réservations,
  /// Caisse. L'accueil est toujours en premier et ne se choisit pas ; les
  /// quatre autres restent personnalisables.
  static const _barreParDefaut = [
    Routes.gestionImmobilier,
    Routes.calendrierBiens,
    Routes.reservation,
    Routes.caisses,
  ];
  static const _maxBarre = 4;

  /// Le nombre de modules posés sur l'accueil avant la tuile « Tous » :
  /// sept, plus « Tous », remplissent exactement deux rangées de quatre.
  static const _modulesAffiches = 7;

  /// Les éléments de la barre, dans l'ordre choisi. Un dossier défait ou
  /// un droit retiré en disparaît de lui-même.
  List<String> get _clesBarre {
    final cles = <String>[];
    for (final cle in (_barre ?? _barreParDefaut)) {
      if (cles.length >= _maxBarre) break;
      final valide = cle.startsWith('dossier:')
          ? _elements.any((e) =>
              e.estDossier && 'dossier:${e.id}' == cle && _routesAffichees(e).isNotEmpty)
          : ((_parRoute.containsKey(cle) && !_masque(cle)) ||
              _raccourcisParRoute.containsKey(cle));
      if (valide && !cles.contains(cle)) cles.add(cle);
    }
    return cles;
  }

  List<_EntreeBarre> get _entreesBarre => _clesBarre.map((cle) {
        if (cle.startsWith('dossier:')) {
          final d = _elements.firstWhere((e) => e.estDossier && 'dossier:${e.id}' == cle);
          return _EntreeBarre(
            titre: d.nom,
            icone: _bibliothequeIcones[d.icone] ?? Icons.folder_rounded,
            visuel: (d.image != null || d.couleur != null)
                ? _iconeDossier(d, taille: d.image != null ? 20 : 18, arrondi: 5)
                : null,
            onTap: () => _ouvrirDossier(d),
          );
        }
        final m = _parRoute[cle] ?? _raccourcisParRoute[cle]!;
        return _EntreeBarre(
          titre: _reglages[cle]?.nom ?? m.court ?? m.titre,
          icone: m.icone,
          onTap: () => GoRouter.of(context).push(m.route),
        );
      }).toList();

  Widget _titreSection(String titre) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text(
          titre.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: .8,
            color: Color(0xFF6B7B84),
          ),
        ),
      );

  Widget _ligneChoix({
    required String cle,
    required String titre,
    String? sousTitre,
    required IconData icone,
    required Color fond,
    required Color teinte,
    required List<String> choisis,
    required StateSetter maj,
  }) {
    final rang = choisis.indexOf(cle);
    final coche = rang >= 0;
    final plein = choisis.length >= _maxBarre;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: coche || !plein,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(11)),
        child: Icon(icone, size: 16, color: teinte),
      ),
      title: Text(titre,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF17262E))),
      subtitle: sousTitre == null
          ? null
          : Text(sousTitre, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7B84))),
      trailing: coche
          ? CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primaryColor,
              child: Text('${rang + 1}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : Icon(Icons.radio_button_unchecked,
              color: plein ? const Color(0xFFD5DDE2) : const Color(0xFFB7C3CA)),
      onTap: () => maj(() {
        if (coche) {
          choisis.remove(cle);
        } else if (!plein) {
          choisis.add(cle);
        }
      }),
    );
  }

  /// Un module s'affiche si l'utilisateur a son droit (l'administrateur
  /// les a tous). Tout le reste de
  /// l'accueil (grille, dossiers, barre du bas, disposition gardée) part
  /// de ces listes filtrées.
  bool _autorise(_Module m) {
    if (m.auMoinsUn != null && !manager.canAny(m.auMoinsUn!)) return false;
    if (m.acces != null && !m.acces!(manager)) return false;
    return m.permission == null || manager.can(m.permission!);
  }

  @override
  void initState() {
    super.initState();
    _visibles = _modules.where(_autorise).toList();
    _parRoute = {for (final m in _visibles) m.route: m};
    _raccourcisVisibles = _raccourcis.where(_autorise).toList();
    _raccourcisParRoute = {for (final m in _raccourcisVisibles) m.route: m};
    // L'ordre d'origine s'affiche tout de suite ; celui de l'utilisateur
    // le remplace dès qu'il est lu.
    _elements = _Disposition.reconcilier([], _visibles, sansAjout: _nonAjoutes);
    // Réglages des modules et disposition sont lus en même temps ; la
    // disposition attend les réglages pour savoir quels modules du
    // catalogue l'utilisateur a ajoutés. Sans réponse : valeurs d'origine.
    _Disposition._serveur(manager);
    _chargerReglages()
        .then((_) => _Disposition.charger(manager, _visibles, sansAjout: _nonAjoutes))
        .then((e) {
      if (mounted) setState(() => _elements = e);
    });
    _Disposition.chargerBarre(manager).then((b) {
      if (mounted && b != null) setState(() => _barre = b);
    });
  }

  void _sauver() => _Disposition.enregistrer(manager, _elements);

  // ── Recherche de modules ─────────────────────────────────────────
  //
  // La recherche a suivi les modules : elle vit désormais dans la page
  // « Tous les modules », là où il y a de quoi chercher. L'accueil, lui,
  // ne montre que les sept premiers et n'a rien à filtrer.

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
  };

  /// Minuscules, sans accents ni espaces superflus : « Réservations »
  /// se trouve en tapant « reserv ».
  static String _normaliser(String texte) {
    final tampon = StringBuffer();
    for (final c in texte.toLowerCase().split('')) {
      tampon.write(_accents[c] ?? c);
    }
    return tampon.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Les modules accessibles et non masqués dont le nom choisi, le nom
  /// d'origine ou le dossier qui les range correspond à la saisie.
  List<_Module> _resultatsPour(String requete) {
    final q = _normaliser(requete);
    if (q.isEmpty) return const [];
    final parDossier = <String>{
      for (final e in _elements)
        if (e.estDossier && _normaliser(e.nom).contains(q)) ...e.routes,
    };
    return _visibles.where((m) {
      if (_masque(m.route)) return false;
      return _normaliser(_titre(m)).contains(q) ||
          _normaliser(m.titre).contains(q) ||
          (m.court != null && _normaliser(m.court!).contains(q)) ||
          parDossier.contains(m.route);
    }).toList();
  }

  // ── Modules masqués et renommés ──────────────────────────────────

  Future<void> _chargerReglages() async {
    try {
      final liste = await Dependencies.get<Repository>()
          .lireModulesAccueil()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _reglages = {for (final r in liste) r.code: r});
    } catch (_) {
      // Lecture impossible : l'accueil garde ses modules et ses noms d'origine.
    }
  }

  /// Modules du catalogue que l'utilisateur n'a pas ajoutés : ils ne
  /// rejoignent pas l'accueil d'eux-mêmes.
  Set<String> get _nonAjoutes => {
        for (final m in _visibles)
          if (m.horsAccueil && _reglages[m.route]?.visible != true) m.route,
      };

  bool _masque(String route) => _reglages[route]?.visible == false;

  /// Le nom affiché d'un module : celui choisi par l'utilisateur, sinon
  /// le libellé d'origine.
  String _titre(_Module m) => _reglages[m.route]?.nom ?? m.titre;

  /// Les modules d'un dossier qui restent affichés.
  List<String> _routesAffichees(_Element dossier) =>
      dossier.routes.where((r) => _parRoute.containsKey(r) && !_masque(r)).toList();

  /// Les éléments de l'accueil qui s'affichent : ni module masqué, ni
  /// dossier dont tous les modules sont masqués.
  List<int> get _indicesAffiches => [
        for (var i = 0; i < _elements.length; i++)
          if (_elements[i].estDossier
              ? _routesAffichees(_elements[i]).isNotEmpty
              : !_masque(_elements[i].route!))
            i,
      ];

  bool _estPlace(String route) =>
      _elements.any((e) => e.estDossier ? e.routes.contains(route) : e.route == route);

  /// Applique tout de suite le changement, puis l'enregistre ; en cas
  /// d'échec, revient à l'état d'avant et le signale.
  Future<bool> _modifierReglage(
    String code,
    ModuleAccueil? Function(ModuleAccueil? actuel) changer,
  ) async {
    final avant = _reglages;
    final apres = Map<String, ModuleAccueil>.from(avant);
    final horsAccueil = _parRoute[code]?.horsAccueil ?? false;
    final nouveau = changer(avant[code]);
    // Un module ordinaire visible sous son nom d'origine n'a pas besoin de
    // réglage ; un module du catalogue garde le sien (il marque l'ajout).
    if (nouveau == null || (nouveau.parDefaut && !horsAccueil)) {
      apres.remove(code);
    } else {
      apres[code] = nouveau;
    }
    final numero = ++_sequenceReglages;
    setState(() {
      _reglages = apres;
      _selection.removeWhere(_masque);
    });
    try {
      final reponse = await Dependencies.get<Repository>()
          .enregistrerModulesAccueil(apres.values.toList());
      if (!mounted || numero != _sequenceReglages) return true;
      if (reponse.isNotEmpty || apres.isEmpty) {
        setState(() => _reglages = {for (final r in reponse) r.code: r});
      }
      return true;
    } catch (ex) {
      if (!mounted) return false;
      if (numero == _sequenceReglages) setState(() => _reglages = avant);
      _signalerErreur(ex);
      return false;
    }
  }

  void _signalerErreur(Object ex) {
    final texte = ex.toString().replaceFirst('Exception: ', '').trim();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texte.isEmpty ? "L'enregistrement n'a pas abouti." : texte),
        backgroundColor: Colors.red.shade700,
      ));
  }

  Future<void> _renommerModule(_Module m) async {
    final saisie = TextEditingController(text: _reglages[m.route]?.nom ?? '');
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Renommer le module",
            style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: TextField(
          controller: saisie,
          autofocus: true,
          maxLength: ModuleAccueil.longueurMaxNom,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: m.titre,
            helperText: "Laissez vide pour reprendre « ${m.titre} ».",
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(saisie.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
    if (nom == null || !mounted) return;
    var propre = nom.trim();
    if (propre.length > ModuleAccueil.longueurMaxNom) {
      propre = propre.substring(0, ModuleAccueil.longueurMaxNom);
    }
    final choisi = propre.isEmpty || propre == m.titre ? null : propre;
    if (choisi == _reglages[m.route]?.nom) return;
    await _modifierReglage(
      m.route,
      (r) => (r ?? ModuleAccueil(code: m.route))
          .copyWith(nom: choisi, effacerNom: choisi == null),
    );
  }

  Future<void> _masquerModule(_Module m) async {
    final ok = await _modifierReglage(
      m.route,
      (r) => (r ?? ModuleAccueil(code: m.route)).copyWith(visible: false),
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text("« ${_titre(m)} » est masqué. « Ajouter un module » le fait revenir."),
        duration: const Duration(seconds: 2),
        // Avec une action, le SnackBar resterait affiche sans limite.
        persist: false,
        action: SnackBarAction(label: "Annuler", onPressed: () => _afficherModule(m)),
      ));
  }

  /// Rend un module visible et, s'il n'est nulle part sur l'accueil, le
  /// pose à la fin.
  Future<void> _afficherModule(_Module m) async {
    if (!mounted) return;
    if (!_estPlace(m.route)) {
      setState(() => _elements.add(_Element.module(m.route)));
      _sauver();
    }
    await _modifierReglage(
      m.route,
      (r) => (r ?? ModuleAccueil(code: m.route)).copyWith(visible: true),
    );
  }

  /// Le menu d'une carte : renommer ou masquer le module.
  Future<void> _menuModule(_Module m) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: m.fond, borderRadius: BorderRadius.circular(11)),
                  child: Icon(m.icone, size: 16, color: m.teinte),
                ),
                title: Text(_titre(m),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                subtitle: _reglages[m.route]?.nom != null
                    ? Text("Nom d'origine : ${m.titre}",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B84)))
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text("Renommer"),
                onTap: () => Navigator.of(feuille).pop('renommer'),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text("Masquer"),
                subtitle: const Text(
                    "Il disparaît de l'accueil, des dossiers et de la barre du bas.",
                    style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.of(feuille).pop('masquer'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choix == 'renommer') {
      await _renommerModule(m);
    } else if (choix == 'masquer') {
      await _masquerModule(m);
    }
  }

  /// Le catalogue : modules masqués, ou accessibles mais absents de l'accueil.
  Future<void> _ajouterModule() async {
    final masques = _visibles.where((m) => _masque(m.route)).toList();
    final absents =
        _visibles.where((m) => !_masque(m.route) && !_estPlace(m.route)).toList();
    String? dossierDe(String route) {
      for (final e in _elements) {
        if (e.estDossier && e.routes.contains(route)) return e.nom;
      }
      return null;
    }

    Widget ligne(BuildContext feuille, _Module m, String sousTitre) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: m.fond, borderRadius: BorderRadius.circular(11)),
            child: Icon(m.icone, size: 16, color: m.teinte),
          ),
          title: Text(_titre(m),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF17262E))),
          subtitle: Text(sousTitre,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7B84))),
          trailing: Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
          onTap: () => Navigator.of(feuille).pop(m),
        );

    final choisi = await showModalBottomSheet<_Module>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(feuille).size.height * .82),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5DDE2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Ajouter un module",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Les modules masqués et ceux qui ne sont pas encore sur votre accueil. "
                  "Touchez-en un pour l'afficher.",
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF6B7B84)),
                ),
                const SizedBox(height: 8),
                if (masques.isEmpty && absents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Tous vos modules sont déjà sur l'accueil.",
                        style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7B84)),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (masques.isNotEmpty) ...[
                          _titreSection("Modules masqués"),
                          for (final m in masques)
                            ligne(
                              feuille,
                              m,
                              dossierDe(m.route) != null
                                  ? "Masqué · dossier « ${dossierDe(m.route)} »"
                                  : "Masqué",
                            ),
                        ],
                        if (absents.isNotEmpty) ...[
                          _titreSection("Autres modules"),
                          for (final m in absents)
                            ligne(feuille, m, "Pas encore sur l'accueil"),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choisi == null || !mounted) return;
    await _afficherModule(choisi);
  }

  Future<void> _reinitialiserModules() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Réinitialiser les modules",
            style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: const Text(
          "Les modules masqués réapparaissent et tous reprennent leur nom d'origine. "
          "La disposition et les dossiers ne changent pas.",
          style: TextStyle(fontSize: 13.5, height: 1.35),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Réinitialiser"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final avant = _reglages;
    final numero = ++_sequenceReglages;
    setState(() => _reglages = {});
    try {
      await Dependencies.get<Repository>().reinitialiserModulesAccueil();
    } catch (ex) {
      if (!mounted) return;
      if (numero == _sequenceReglages) setState(() => _reglages = avant);
      _signalerErreur(ex);
    }
  }

  void _entrerOrganiser() {
    FocusScope.of(context).unfocus();
    setState(() => _organiser = true);
  }

  void _terminer() => setState(() {
        _organiser = false;
        _selection.clear();
      });

  void _basculer(String route) => setState(() {
        if (!_selection.remove(route)) _selection.add(route);
      });

  /// Une carte lâchée sur une autre : un module lâché sur un dossier y
  /// entre, sinon la carte prend la place de celle qu'elle recouvre.
  void _deposer(int de, int vers) {
    final source = _elements[de];
    final cible = _elements[vers];
    setState(() {
      if (cible.estDossier && !source.estDossier) {
        cible.routes.add(source.route!);
        _elements.removeAt(de);
        _selection.remove(source.route);
      } else {
        _elements.removeAt(de);
        _elements.insert(vers, source);
      }
    });
    _sauver();
  }

  Future<String?> _demanderNom({required String titre, String initial = ''}) {
    final saisie = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titre, style: const TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: TextField(
          controller: saisie,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.black87),
          decoration: const InputDecoration(
            hintText: "Nom du dossier",
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(saisie.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    ).then((v) {
      if (v == null) return null;
      final nom = v.trim();
      return nom.isEmpty ? "Dossier" : nom;
    });
  }

  Future<void> _creerDossier() async {
    final nom = await _demanderNom(titre: "Nouveau dossier");
    if (nom == null || !mounted) return;

    final choisis = _elements
        .where((e) => !e.estDossier && _selection.contains(e.route))
        .toList();
    if (choisis.isEmpty) return;
    final position = _elements.indexOf(choisis.first);

    final nouveau = _Element.dossier(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nom: nom,
      routes: choisis.map((e) => e.route!).toList(),
    );
    setState(() {
      _elements.removeWhere((e) => choisis.contains(e));
      _elements.insert(position.clamp(0, _elements.length), nouveau);
      _selection.clear();
    });
    _sauver();
    // Le dossier vient d'être nommé : on propose tout de suite son icône.
    await _choisirIcone(nouveau);
  }

  /// Le choix de l'icône d'un dossier : une icône de la bibliothèque ou
  /// une image du téléphone.
  Future<void> _choisirIcone(_Element dossier) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => StatefulBuilder(
        builder: (feuille, maj) {
          final teinte =
              dossier.couleur != null ? Color(dossier.couleur!) : AppColors.primaryColor;

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(feuille).size.height * .8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5DDE2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _iconeDossier(dossier,
                              taille: dossier.image != null ? 46 : 26, arrondi: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Icône de « ${dossier.nom} »",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text("Couleur",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A5B64))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _couleursDossier.map((c) {
                        final choisie = dossier.couleur == c.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setState(() => dossier.couleur = c.toARGB32());
                            maj(() {});
                            _sauver();
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: choisie ? const Color(0xFF17262E) : Colors.white,
                                width: 3,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Color(0x2917262E), blurRadius: 4),
                              ],
                            ),
                            child: choisie
                                ? const Icon(Icons.check, size: 18, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(feuille).pop('image'),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text("Choisir une image"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.of(feuille).pop('defaut'),
                          child: const Text("Par défaut"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Bibliothèque : ${_bibliothequeIcones.length} icônes",
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B84)),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: _bibliothequeIcones.entries.map((e) {
                          final choisie = dossier.image == null && dossier.icone == e.key;
                          return Material(
                            color: choisie ? teinte : const Color(0xFFF2F5F7),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(feuille).pop('icone:${e.key}'),
                              child: Icon(
                                e.value,
                                size: 22,
                                color: choisie ? Colors.white : teinte,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (choix == null || !mounted) return;
    if (choix == 'defaut') {
      setState(() {
        dossier.icone = null;
        dossier.image = null;
        dossier.couleur = null;
      });
    } else if (choix.startsWith('icone:')) {
      setState(() {
        dossier.icone = choix.substring(6);
        dossier.image = null;
      });
    } else if (choix == 'image') {
      final chemin = await _enregistrerImage(dossier);
      if (chemin == null || !mounted) return;
      setState(() => dossier.image = chemin);
    }
    _sauver();
  }

  /// Copie l'image choisie dans les fichiers de l'application : l'original
  /// peut disparaître de la galerie.
  Future<String?> _enregistrerImage(_Element dossier) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 85,
      );
      if (photo == null) return null;
      final racine = await getApplicationDocumentsDirectory();
      final repertoire = Directory('${racine.path}/icones_dossiers');
      if (!repertoire.existsSync()) repertoire.createSync(recursive: true);
      final ancienne = dossier.image;
      final chemin =
          '${repertoire.path}/${dossier.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(photo.path).copy(chemin);
      if (ancienne != null && ancienne != chemin) {
        try {
          File(ancienne).deleteSync();
        } catch (_) {}
      }
      return chemin;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("L'image n'a pas pu être utilisée.")),
        );
      }
      return null;
    }
  }

  void _renommer(_Element dossier, String nom) {
    setState(() => dossier.nom = nom);
    _sauver();
  }

  /// Le choix des modules de la barre du bas.
  Future<void> _personnaliserBarre() async {
    final choisis = _clesBarre.toList();
    final resultat = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => StatefulBuilder(
        builder: (feuille, maj) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(feuille).size.height * .82),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DDE2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Barre du bas",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Choisissez jusqu'à $_maxBarre éléments, dans l'ordre où ils "
                    "apparaîtront : un dossier, un module ou un raccourci comme "
                    "« Biens disponibles » ou « Ajouter une réservation ». "
                    "L'accueil reste toujours en premier.",
                    style: const TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF6B7B84)),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (_elements.any((e) => e.estDossier)) ...[
                          _titreSection("Mes dossiers"),
                          for (final d in _elements
                              .where((e) => e.estDossier && _routesAffichees(e).isNotEmpty))
                            _ligneChoix(
                              cle: 'dossier:${d.id}',
                              titre: d.nom,
                              sousTitre: "${_routesAffichees(d).length} "
                                  "module${_routesAffichees(d).length > 1 ? 's' : ''}",
                              icone: _bibliothequeIcones[d.icone] ?? Icons.folder_rounded,
                              fond: const Color(0xFFEEF2F5),
                              teinte: AppColors.primaryColor,
                              choisis: choisis,
                              maj: maj,
                            ),
                        ],
                        _titreSection("Modules"),
                        for (final m in _visibles.where((m) => !_masque(m.route)))
                          _ligneChoix(
                            cle: m.route,
                            titre: _titre(m),
                            icone: m.icone,
                            fond: m.fond,
                            teinte: m.teinte,
                            choisis: choisis,
                            maj: maj,
                          ),
                        for (final groupe in _raccourcisVisibles
                            .map((r) => r.groupe ?? 'Raccourcis')
                            .toSet()) ...[
                          _titreSection(groupe),
                          for (final r in _raccourcisVisibles
                              .where((r) => (r.groupe ?? 'Raccourcis') == groupe))
                            _ligneChoix(
                              cle: r.route,
                              titre: r.titre,
                              icone: r.icone,
                              fond: r.fond,
                              teinte: r.teinte,
                              choisis: choisis,
                              maj: maj,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(feuille).pop(_barreParDefaut.toList()),
                        child: const Text("Par défaut"),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.of(feuille).pop(choisis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Enregistrer"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (resultat == null || !mounted) return;
    setState(() => _barre = resultat);
    _Disposition.enregistrerBarre(manager, resultat);
  }

  void _sortir(_Element dossier, String route) {
    setState(() {
      final i = _elements.indexOf(dossier);
      dossier.routes.remove(route);
      _elements.insert(i + 1, _Element.module(route));
      if (dossier.routes.isEmpty) _elements.remove(dossier);
    });
    _sauver();
  }

  void _defaire(_Element dossier) {
    setState(() {
      final i = _elements.indexOf(dossier);
      if (i < 0) return;
      _elements.removeAt(i);
      _elements.insertAll(i, dossier.routes.map((r) => _Element.module(r)));
    });
    _sauver();
  }

  Future<void> _reinitialiser() async {
    await _Disposition.effacer(manager);
    if (!mounted) return;
    setState(() {
      _elements = _Disposition.reconcilier([], _visibles, sansAjout: _nonAjoutes);
      _selection.clear();
    });
  }

  Future<void> _ouvrirDossier(_Element dossier) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PageDossier(accueil: this, dossier: dossier),
    ));
    if (mounted) setState(() {});
  }

  Widget _tuile(int i) {
    final e = _elements[i];
    final Widget carte = e.estDossier
        ? _CarteDossier(
            dossier: e,
            modules: _routesAffichees(e).map((r) => _parRoute[r]!).toList(),
            onTap: () => _ouvrirDossier(e),
            onLongPress: _organiser ? null : _entrerOrganiser,
          )
        : _CarteModule(
            module: _parRoute[e.route]!,
            titre: _titre(_parRoute[e.route]!),
            onMenu: _organiser ? () => _menuModule(_parRoute[e.route]!) : null,
            organiser: _organiser,
            selectionne: _selection.contains(e.route),
            onTap: _organiser ? () => _basculer(e.route!) : null,
            onLongPress: _organiser ? null : _entrerOrganiser,
          );

    if (!_organiser) return carte;

    return LayoutBuilder(
      builder: (ctx, taille) => DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != i,
        onAcceptWithDetails: (d) => _deposer(d.data, i),
        builder: (ctx, candidats, _) {
          final survol = candidats.isNotEmpty;
          return LongPressDraggable<int>(
            data: i,
            feedback: SizedBox(
              width: taille.maxWidth,
              height: taille.maxHeight,
              child: Material(
                color: Colors.transparent,
                child: Opacity(opacity: .9, child: carte),
              ),
            ),
            childWhenDragging: Opacity(opacity: .3, child: carte),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rayonAccueil),
                border: Border.all(
                  color: survol ? AppColors.primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: carte,
            ),
          );
        },
      ),
    );
  }

  /// Tout relire : le résumé du serveur, les réglages des modules et la
  /// disposition. Le geste est le même pour l'agent — il tire l'écran.
  Future<void> _rafraichir() async {
    // Le résumé d'abord : c'est lui que l'on vient chercher. Les
    // préférences suivent, sans faire attendre.
    final resume = context.read<ResumeAccueilCubit>().charger();
    _Disposition._lecture = null;
    _Disposition._lectureDe = null;
    await resume;
    if (!mounted) return;
    await _chargerReglages();
    if (!mounted) return;
    final elements =
        await _Disposition.charger(manager, _visibles, sansAjout: _nonAjoutes);
    if (mounted) setState(() => _elements = elements);
  }

  /// Le prénom du serveur ; à défaut celui du compte, à défaut rien.
  String get _prenomAffiche {
    final duServeur =
        context.read<ResumeAccueilCubit>().state.resume?.utilisateur.prenom ?? '';
    if (duServeur.trim().isNotEmpty) return duServeur.trim();
    return manager.firstName?.trim() ?? '';
  }

  // ── Aujourd'hui ──────────────────────────────────────────────────

  /// Les chiffres du jour, chacun avec l'écran qui les détaille.
  ///
  /// Une tuile disparaît lorsque l'utilisateur n'a pas le droit d'ouvrir
  /// l'écran visé : un chiffre sur lequel on ne peut pas appuyer
  /// n'apprend rien et laisse croire à une panne.
  List<TuileJour> _tuilesDuJour(AujourdhuiResume jour) {
    void ouvrir(String route) => GoRouter.of(context).push(route);

    final voitBaux = manager.can(AppPermission.viewLeases);
    final voitReservations = manager.can(AppPermission.viewReservations);

    return [
      if (voitReservations || manager.can(AppPermission.viewReservedProperties))
        TuileJour(
          nombre: jour.arrivees,
          libelle: 'Arrivées',
          teinte: AppColors.primaryColor,
          onTap: () => ouvrir(
              '/immobilier-stats/reserved?type=rent-short&vue=aujourdhui'),
        ),
      if (manager.can(AppPermission.viewTodayCheckouts))
        TuileJour(
          nombre: jour.departs,
          libelle: 'Départs',
          teinte: texteAccueil,
          onTap: _ouvrirDepartsDuJour,
        ),
      if (manager.can(AppPermission.viewCleaningProperties))
        TuileJour(
          nombre: jour.aNettoyer,
          libelle: 'À nettoyer',
          teinte: orangeAccueil,
          onTap: () => ouvrir('/immobilier-stats/cleaning?type=rent-short'),
        ),
      if (voitBaux || voitReservations)
        TuileJour(
          nombre: jour.impayes,
          libelle: 'Impayés',
          teinte: rougeAccueil,
          // Les loyers impayés ont leur liste ; sans la longue durée, les
          // réservations restent le seul endroit où les retrouver.
          onTap: () => ouvrir(voitBaux
              ? '${Routes.baux}?onglet=baux&filtre=impayes'
              : Routes.reservation),
        ),
    ];
  }

  Future<void> _ouvrirDepartsDuJour() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _PageDepartsDuJour()),
    );
  }

  // ── La caisse ────────────────────────────────────────────────────

  Widget _carteCaisse(CaisseResume caisse) {
    void ouvrir(String route) => GoRouter.of(context).push(route);

    return CarteCaisseAccueil(
      caisse: caisse,
      // Sans le droit d'encaisser, le bouton n'existe pas : mieux vaut
      // pas de bouton qu'un bouton qui se fera refuser.
      onEncaisser: manager.can(AppPermission.cashIn)
          ? () => ouvrir('${Routes.caisses}?action=encaisser')
          : null,
      onOuvrirModule: () => ouvrir(Routes.caisses),
      onOuvrirCaisse: () => ouvrir('${Routes.caisses}?action=ouvrir'),
    );
  }

  // ── Les modules ──────────────────────────────────────────────────

  Future<void> _ouvrirTousLesModules() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PageTousModules(accueil: this)),
    );
    if (mounted) setState(() {});
  }

  /// La grille de l'accueil : les premiers modules, puis « Tous ».
  ///
  /// En personnalisation, elle montre tout et passe à trois colonnes :
  /// une carte de 78 pixels ne porte pas en plus une case à cocher et un
  /// bouton de menu.
  Widget _grilleModules() {
    final indices = _indicesAffiches;
    final poses =
        _organiser ? indices : indices.take(_modulesAffiches).toList();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: _organiser ? 3 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: _organiser ? .95 : .84,
      children: [
        ...poses.map(_tuile),
        if (!_organiser)
          _TuileTous(
            reste: indices.length - poses.length,
            onTap: _ouvrirTousLesModules,
          ),
      ],
    );
  }

  Widget _enteteModules() => Row(
        children: [
          const Expanded(
            child: Text(
              'Modules',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: texteAccueil,
              ),
            ),
          ),
          if (_organiser)
            TextButton.icon(
              onPressed: _terminer,
              icon: const Icon(Icons.check, size: 17),
              label: const Text('Terminé', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  visualDensity: VisualDensity.compact),
            )
          else
            TextButton(
              onPressed: _entrerOrganiser,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryColor,
                  visualDensity: VisualDensity.compact),
              child:
                  const Text('Personnaliser', style: TextStyle(fontSize: 13)),
            ),
        ],
      );

  /// Les outils de la personnalisation : dossiers, barre du bas,
  /// catalogue. Ils n'apparaissent qu'en mode « organiser ».
  List<Widget> _outilsPersonnalisation() => [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            "Maintenez une carte puis glissez-la pour la déplacer. "
            "Lâchée sur un dossier, elle y est rangée. Touchez plusieurs "
            "cartes pour les regrouper dans un nouveau dossier. "
            "Le bouton ⋮ d'une carte permet de la renommer ou de la masquer. "
            "Les premières cartes de la liste sont celles que l'accueil affiche.",
            style: TextStyle(
                fontSize: 12.5, height: 1.35, color: Color(0xFF28414F)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selection.length >= 2 ? _creerDossier : null,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: Text(_selection.length >= 2
                    ? "Créer un dossier (${_selection.length})"
                    : "Choisissez au moins 2 cartes"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _reinitialiser,
              child: const Text("Réinitialiser"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _personnaliserBarre,
            icon: const Icon(Icons.space_dashboard_outlined, size: 18),
            label: const Text("Choisir les modules de la barre du bas"),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _ajouterModule,
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: const Text("Ajouter un module"),
          ),
        ),
        if (_reglages.values.any((r) =>
            _parRoute.containsKey(r.code) && (!r.visible || r.nom != null)))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reinitialiserModules,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text("Réinitialiser les noms et modules masqués"),
            ),
          ),
        const SizedBox(height: 14),
      ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResumeAccueilCubit, ResumeAccueilState>(
      builder: (context, etat) {
        final resume = etat.resume;
        final caisse = resume?.caisse;
        final tuiles = resume == null
            ? const <TuileJour>[]
            : _tuilesDuJour(resume.aujourdhui);

        return Scaffold(
          backgroundColor: fondAccueil,
          body: RefreshIndicator(
            color: AppColors.primaryColor,
            onRefresh: _rafraichir,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                EnteteAccueil(
                  prenom: _prenomAffiche,
                  agence: resume?.agence ?? '',
                  date: resume?.date,
                  onPersonnaliser: _entrerOrganiser,
                  onWhatsapp: manager.can(AppPermission.manageOwnWhatsapp)
                      ? () =>
                          GoRouter.of(context).push(Routes.receptionWhatsapp)
                      : null,
                ),
                // Le détail de la synchronisation reste accessible d'un appui.
                const BandeauSynchro(),
                // L'échec du résumé se dit, sans rien emporter avec lui :
                // les modules restent en dessous, intacts.
                if (etat.enErreur)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: CarteErreurResume(
                      message: etat.erreur,
                      onReessayer: () =>
                          context.read<ResumeAccueilCubit>().charger(),
                    ),
                  ),
                if (etat.premierChargement)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SqueletteCarteCaisse(),
                  )
                else if (caisse != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _carteCaisse(caisse),
                  ),
                if (!_organiser && tuiles.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      "Aujourd'hui",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: texteAccueil,
                      ),
                    ),
                  ),
                  TuilesAujourdhui(tuiles: tuiles),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _enteteModules(),
                      const SizedBox(height: 10),
                      if (_organiser) ..._outilsPersonnalisation(),
                      _grilleModules(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _BarreBasse(
            entrees: _entreesBarre,
            onPersonnaliser: _personnaliserBarre,
          ),
        );
      },
    );
  }
}

/// La tuile « Tous » : en pointillés, parce qu'elle n'est pas un module
/// mais la porte vers tous les autres.
class _TuileTous extends StatelessWidget {
  /// Le nombre de modules qui attendent derrière ; 0 : rien de plus.
  final int reste;
  final VoidCallback onTap;

  const _TuileTous({required this.reste, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BordurePointillee(
      couleur: AppColors.primaryColor.withValues(alpha: .45),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(rayonAccueil),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apps_rounded,
                    size: 22, color: AppColors.primaryColor),
                const SizedBox(height: 8),
                Text(
                  'Tous',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
                if (reste > 0)
                  Text(
                    '+$reste',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: texteDouxAccueil,
                      fontFeatures: chiffresTabulaires,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les départs du jour, en page entière : la liste existante, avec ses
/// confirmations, sortie de la gestion des biens pour être atteinte
/// depuis l'accueil.
class _PageDepartsDuJour extends StatelessWidget {
  const _PageDepartsDuJour();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondAccueil,
      appBar: AppBar(
        title: const Text('Départs du jour',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(14, 16, 14, 24),
        child: DepartsDuJour(),
      ),
    );
  }
}

/// Tous les modules, avec la recherche.
///
/// C'est la page derrière la tuile « Tous » : l'accueil ne montre que les
/// premiers modules, celle-ci montre le reste et permet de chercher par
/// nom — le nom choisi, le nom d'origine, ou celui du dossier qui le range.
class _PageTousModules extends StatefulWidget {
  final _HomePageState accueil;

  const _PageTousModules({required this.accueil});

  @override
  State<_PageTousModules> createState() => _PageTousModulesState();
}

class _PageTousModulesState extends State<_PageTousModules> {
  final TextEditingController _recherche = TextEditingController();
  String _requete = '';

  _HomePageState get accueil => widget.accueil;

  bool get _enRecherche => _requete.trim().isNotEmpty;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Widget _champRecherche() => TextField(
        controller: _recherche,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14.5, color: texteAccueil),
        onChanged: (v) => setState(() => _requete = v),
        decoration: InputDecoration(
          hintText: 'Rechercher un module…',
          hintStyle: const TextStyle(color: Color(0xFF98A6AE)),
          prefixIcon: const Icon(Icons.search, color: texteDouxAccueil),
          suffixIcon: _requete.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.close, color: texteDouxAccueil),
                  onPressed: () {
                    _recherche.clear();
                    setState(() => _requete = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: bordureAccueil),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: bordureAccueil),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
          ),
        ),
      );

  Widget _grille(List<Widget> cartes) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .84,
        children: cartes,
      );

  Widget _carte(int i) {
    final e = accueil._elements[i];
    if (e.estDossier) {
      return _CarteDossier(
        dossier: e,
        modules: accueil
            ._routesAffichees(e)
            .map((r) => accueil._parRoute[r]!)
            .toList(),
        onTap: () async {
          await accueil._ouvrirDossier(e);
          if (mounted) setState(() {});
        },
      );
    }
    final m = accueil._parRoute[e.route]!;
    return _CarteModule(module: m, titre: accueil._titre(m));
  }

  @override
  Widget build(BuildContext context) {
    final resultats = accueil._resultatsPour(_requete);

    return Scaffold(
      backgroundColor: fondAccueil,
      appBar: AppBar(
        title: const Text('Tous les modules',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            tooltip: "Personnaliser l'accueil",
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () {
              Navigator.of(context).pop();
              accueil._entrerOrganiser();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _champRecherche(),
          const SizedBox(height: 14),
          if (_enRecherche) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Text(
                resultats.isEmpty
                    ? 'Aucun module ne correspond à « ${_requete.trim()} ».'
                    : '${resultats.length} module${resultats.length > 1 ? 's' : ''} '
                        'trouvé${resultats.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 13.5, color: texteDouxAccueil),
              ),
            ),
            if (resultats.isNotEmpty)
              _grille(resultats
                  .map((m) => _CarteModule(module: m, titre: accueil._titre(m)))
                  .toList()),
          ] else
            _grille(accueil._indicesAffiches.map(_carte).toList()),
        ],
      ),
    );
  }
}

// ── Carte d'un module ──────────────────────────────────────────────

/// La tuile d'un module : une icône fine dans la couleur de la marque,
/// son nom dessous.
///
/// Les teintes propres à chaque module ont quitté l'accueil : à quatre
/// par rangée, huit couleurs faisaient un damier. La couleur sert
/// désormais aux chiffres du jour, où elle porte un sens.
class _CarteModule extends StatelessWidget {
  final _Module module;

  /// Nom affiché ; nul : le libellé d'origine du module.
  final String? titre;

  /// En personnalisation : ouvre le menu (renommer, masquer).
  final VoidCallback? onMenu;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool organiser;
  final bool selectionne;

  const _CarteModule({
    required this.module,
    this.titre,
    this.onMenu,
    this.onTap,
    this.onLongPress,
    this.organiser = false,
    this.selectionne = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: InkWell(
        onTap: onTap ?? () => GoRouter.of(context).push(module.route),
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(4, organiser ? 18 : 10, 4, 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selectionne ? AppColors.primaryColor : bordureAccueil,
                  width: selectionne ? 1.6 : 1,
                ),
                borderRadius: BorderRadius.circular(rayonAccueil),
                boxShadow: ombreAccueil,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(module.icone, size: 21, color: AppColors.primaryColor),
                  const SizedBox(height: 8),
                  Text(
                    titre ?? module.titre,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: texteAccueil,
                    ),
                  ),
                ],
              ),
            ),
            if (organiser)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  selectionne ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: selectionne
                      ? AppColors.primaryColor
                      : const Color(0xFFB7C3CA),
                ),
              ),
            if (onMenu != null)
              Positioned(
                top: 0,
                left: 0,
                child: IconButton(
                  tooltip: "Renommer ou masquer",
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: texteDouxAccueil),
                  onPressed: onMenu,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un dossier : son icône — ou l'aperçu de ce qu'il contient — et son nom.
class _CarteDossier extends StatelessWidget {
  final _Element dossier;
  final List<_Module> modules;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CarteDossier({
    required this.dossier,
    required this.modules,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final illustre =
        dossier.icone != null || dossier.image != null || dossier.couleur != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(rayonAccueil),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(rayonAccueil),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            border: Border.all(color: bordureAccueil),
            borderRadius: BorderRadius.circular(rayonAccueil),
            boxShadow: ombreAccueil,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (illustre)
                _iconeDossier(dossier,
                    taille: dossier.image != null ? 26 : 22, arrondi: 7)
              else
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  children: modules
                      .take(4)
                      .map((m) => Icon(m.icone,
                          size: 10, color: AppColors.primaryColor))
                      .toList(),
                ),
              const SizedBox(height: 8),
              Text(
                dossier.nom,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: texteAccueil,
                ),
              ),
              Text(
                '${modules.length}',
                style: const TextStyle(
                  fontSize: 9.5,
                  color: texteDouxAccueil,
                  fontFeatures: chiffresTabulaires,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un dossier ouvert, en page entière : ses modules en grandes cartes,
/// comme sur l'accueil.
class _PageDossier extends StatefulWidget {
  final _HomePageState accueil;
  final _Element dossier;

  const _PageDossier({required this.accueil, required this.dossier});

  @override
  State<_PageDossier> createState() => _PageDossierState();
}

class _PageDossierState extends State<_PageDossier> {
  bool _edition = false;

  @override
  Widget build(BuildContext context) {
    final accueil = widget.accueil;
    final dossier = widget.dossier;
    final modules =
        accueil._routesAffichees(dossier).map((r) => accueil._parRoute[r]!).toList();

    return Scaffold(
      backgroundColor: fondAccueil,
      appBar: AppBar(
        title: Text(dossier.nom,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            tooltip: _edition ? "Terminé" : "Ranger les modules",
            icon: Icon(_edition ? Icons.check : Icons.tune),
            onPressed: () => setState(() => _edition = !_edition),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (choix) async {
              if (choix == 'renommer') {
                final nom = await accueil._demanderNom(
                    titre: "Renommer le dossier", initial: dossier.nom);
                if (nom == null || !mounted) return;
                accueil._renommer(dossier, nom);
                setState(() {});
              } else if (choix == 'icone') {
                await accueil._choisirIcone(dossier);
                if (mounted) setState(() {});
              } else if (choix == 'defaire') {
                accueil._defaire(dossier);
                if (mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'renommer',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text("Renommer"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'icone',
                child: ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text("Icône et couleur"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'defaire',
                child: ListTile(
                  leading: Icon(Icons.folder_off_outlined),
                  title: Text("Défaire le dossier"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Row(
            children: [
              _iconeDossier(dossier, taille: 26),
              const SizedBox(width: 8),
              Text(
                "${modules.length} module${modules.length > 1 ? 's' : ''}",
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF17262E)),
              ),
            ],
          ),
          if (_edition) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "Touchez × pour sortir un module du dossier : il retourne sur l'accueil. "
                "Le bouton ⋮ permet de le renommer ou de le masquer.",
                style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF28414F)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: _edition ? 3 : 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: _edition ? .95 : .84,
            children: modules
                .map((m) => Stack(
                      fit: StackFit.expand,
                      children: [
                        _CarteModule(
                          module: m,
                          titre: accueil._titre(m),
                          onTap: _edition ? () {} : null,
                          onMenu: _edition
                              ? () async {
                                  await accueil._menuModule(m);
                                  if (!context.mounted) return;
                                  if (accueil._routesAffichees(dossier).isEmpty) {
                                    Navigator.of(context).pop();
                                  } else {
                                    setState(() {});
                                  }
                                }
                              : null,
                        ),
                        if (_edition)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: const Color(0xFFB3261E),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  accueil._sortir(dossier, m.route);
                                  if (dossier.routes.isEmpty) {
                                    Navigator.of(context).pop();
                                  } else {
                                    setState(() {});
                                  }
                                },
                                child: const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Icon(Icons.close, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Barre du bas ───────────────────────────────────────────────────

/// Un emplacement de la barre du bas : module, raccourci ou dossier.
class _EntreeBarre {
  final String titre;
  final IconData icone;
  final VoidCallback onTap;

  /// Une image à la place de l'icône (dossier illustré par une photo).
  final Widget? visuel;

  const _EntreeBarre({
    required this.titre,
    required this.icone,
    required this.onTap,
    this.visuel,
  });
}

class _BarreBasse extends StatelessWidget {
  final List<_EntreeBarre> entrees;

  /// Un appui long sur la barre ouvre le choix de ses éléments.
  final VoidCallback onPersonnaliser;

  const _BarreBasse({required this.entrees, required this.onPersonnaliser});

  @override
  Widget build(BuildContext context) {
    final onglets = <(String, IconData, VoidCallback?, Widget?)>[
      ('Accueil', Icons.home_outlined, null, null),
      for (final e in entrees) (e.titre, e.icone, e.onTap, e.visuel),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8EC))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: onglets.map((o) {
              final actif = o.$3 == null;
              return Expanded(
                child: InkWell(
                  onTap: o.$3,
                  onLongPress: onPersonnaliser,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: actif
                                ? AppColors.primaryColor.withValues(alpha: .12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: o.$4 ?? Icon(
                            o.$2,
                            size: actif ? 20 : 17,
                            color: actif ? AppColors.primaryColor : const Color(0xFF98A6AE),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          o.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: actif ? AppColors.primaryColor : const Color(0xFF98A6AE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
