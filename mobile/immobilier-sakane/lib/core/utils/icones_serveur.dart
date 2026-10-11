import 'package:flutter/material.dart';

/// Les icônes que le serveur désigne par leur nom.
///
/// Les catalogues du serveur (familles de charges, caractéristiques des
/// biens, familles d'équipements) nomment une icône ; Flutter ne sait pas
/// résoudre un nom en icône, il faut cette table. Un nom inconnu reçoit
/// une icône neutre plutôt que rien.
const Map<String, IconData> _icones = {
  // Familles de charges
  'payments': Icons.payments_outlined,
  'autorenew': Icons.autorenew,
  'home_work': Icons.home_work_outlined,
  'bolt': Icons.bolt_outlined,
  'verified_user': Icons.verified_user_outlined,
  'account_balance': Icons.account_balance_outlined,
  'cleaning_services': Icons.cleaning_services_outlined,
  'local_gas_station': Icons.local_gas_station_outlined,
  'inventory_2': Icons.inventory_2_outlined,
  'more_horiz': Icons.more_horiz,

  // Caractéristiques des biens
  'weekend': Icons.weekend_outlined,
  'kitchen': Icons.kitchen_outlined,
  'balcony': Icons.balcony_outlined,
  'deck': Icons.deck_outlined,
  'chair': Icons.chair_outlined,
  'explore': Icons.explore_outlined,
  'receipt_long': Icons.receipt_long_outlined,
  'crop_landscape': Icons.crop_landscape_outlined,
  'yard': Icons.yard_outlined,
  'garage': Icons.garage_outlined,
  'grass': Icons.grass_outlined,
  'pool': Icons.pool_outlined,
  'bedroom_parent': Icons.bedroom_parent_outlined,
  'stairs': Icons.stairs_outlined,
  'storefront': Icons.storefront_outlined,
  'meeting_room': Icons.meeting_room_outlined,
  'wc': Icons.wc_outlined,
  'height': Icons.height,
  'shield': Icons.shield_outlined,
  'local_shipping': Icons.local_shipping_outlined,
  'badge': Icons.badge_outlined,
  'desk': Icons.desk_outlined,
  'groups': Icons.groups_outlined,
  'local_parking': Icons.local_parking_outlined,
  'space_dashboard': Icons.space_dashboard_outlined,
  'description': Icons.description_outlined,
  'map': Icons.map_outlined,
  'straighten': Icons.straighten_outlined,
  'foundation': Icons.foundation_outlined,
  'fence': Icons.fence_outlined,
  'water_drop': Icons.water_drop_outlined,
  'route': Icons.route_outlined,
  'park': Icons.park_outlined,
  'agriculture': Icons.agriculture_outlined,
  'waves': Icons.waves_outlined,
  'cottage': Icons.cottage_outlined,
  'hot_tub': Icons.hot_tub_outlined,
  'construction': Icons.construction_outlined,

  // Familles d'équipements
  'thermostat': Icons.thermostat_outlined,
  'apartment': Icons.apartment_outlined,
};

/// L'icône portant ce nom, ou [defaut] quand le nom est inconnu.
IconData iconeServeur(String? nom, {IconData defaut = Icons.label_outline}) =>
    _icones[nom ?? ''] ?? defaut;

/// La couleur écrite « #RRGGBB » par le serveur, ou [defaut].
Color couleurServeur(String? hexa, {required Color defaut}) {
  var propre = (hexa ?? '').trim().replaceFirst('#', '');
  if (propre.length == 6) propre = 'FF$propre';
  if (propre.length != 8) return defaut;
  final valeur = int.tryParse(propre, radix: 16);
  return valeur == null ? defaut : Color(valeur);
}
