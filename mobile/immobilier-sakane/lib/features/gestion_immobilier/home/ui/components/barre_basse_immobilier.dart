import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/routes.dart';

/// Un emplacement de la barre.
class _Entree {
  final String titre;
  final IconData icone;

  /// Nul : l'onglet est celui de l'écran affiché.
  final String? route;
  final AppPermission? permission;

  const _Entree(this.titre, this.icone, {this.route, this.permission});
}

/// La barre du bas de l'accueil, reprise sur l'écran Immobilier : mêmes
/// onglets, même dessin, « Biens » actif puisque c'est l'écran affiché.
///
/// Les cinq onglets de la maquette sont fixes ici : la personnalisation
/// de la barre reste le fait de l'accueil, qui en garde le réglage.
class BarreBasseImmobilier extends StatelessWidget {
  const BarreBasseImmobilier({super.key});

  static const List<_Entree> _onglets = [
    _Entree('Accueil', Icons.home_outlined, route: Routes.home),
    _Entree('Biens', FontAwesomeIcons.building),
    _Entree('Calendrier', FontAwesomeIcons.calendarDays,
        route: Routes.calendrierBiens, permission: AppPermission.viewCalendar),
    _Entree('Réservations', FontAwesomeIcons.calendarCheck,
        route: Routes.reservation, permission: AppPermission.viewReservations),
    _Entree('Caisse', FontAwesomeIcons.wallet,
        route: Routes.caisses, permission: AppPermission.viewOwnCashbox),
  ];

  /// Un droit retiré fait disparaître l'onglet de lui-même.
  bool _autorise(_Entree e) {
    if (e.permission == null) return true;
    try {
      return Dependencies.get<Manager>().can(e.permission!);
    } catch (_) {
      return false;
    }
  }

  /// L'accueil se rejoint en revenant en arrière quand on en vient ;
  /// sinon la barre y mène directement.
  void _ouvrir(BuildContext context, String route) {
    if (route == Routes.home) {
      final navigateur = Navigator.of(context);
      if (navigateur.canPop()) {
        navigateur.pop();
      } else {
        GoRouter.of(context).go(Routes.home);
      }
      return;
    }
    GoRouter.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _onglets.where(_autorise).toList();

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
            children: visibles.map((e) {
              final actif = e.route == null;
              return Expanded(
                child: InkWell(
                  onTap: actif ? null : () => _ouvrir(context, e.route!),
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
                          child: Icon(
                            e.icone,
                            size: actif ? 20 : 17,
                            color: actif
                                ? AppColors.primaryColor
                                : const Color(0xFF98A6AE),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: actif
                                ? AppColors.primaryColor
                                : const Color(0xFF98A6AE),
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
