import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/models/manager.dart';

/// L'entrée du module des charges : les dépenses courantes d'un côté, ce
/// qui revient chaque mois de l'autre.
class ChargesHome extends StatefulWidget {
  final int? propertyId;

  const ChargesHome({super.key, this.propertyId});

  @override
  State<ChargesHome> createState() => _ChargesHomeState();
}

class _ChargesHomeState extends State<ChargesHome> {
  final Manager _manager = Dependencies.get<Manager>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text(
          'Charges',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _buildOptionCard(
            icon: Icons.receipt_long_outlined,
            title: "Charges courantes",
            description:
                "Les dépenses du quotidien : consulter, ajouter, valider",
            color: const Color(0xFFD97E1A),
            onTap: () => navigate(prepareRoute(Routes.chargesList)),
          ),
          if (_manager.can(AppPermission.viewFixedCharges)) ...[
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.event_repeat_outlined,
              title: "Charges fixes",
              description:
                  "Salaires, abonnements, loyers, taxes : par famille, et chaque mois",
              color: const Color(0xFF7B4FD6),
              onTap: () => navigate(Routes.chargesFixes),
            ),
          ],
          if (_manager.can(AppPermission.viewCancelledCharges)) ...[
            const SizedBox(height: 12),
            _buildOptionCard(
              icon: Icons.block_outlined,
              title: "Charges annulées",
              description: "Ce qui a été repris, par qui et quand",
              color: couleurRougeActivite,
              onTap: () => navigate(Routes.chargesAnnulees),
            ),
          ],
        ],
      ),
    );
  }

  String prepareRoute(String route) {
    if (widget.propertyId != null) {
      route += "?realestate=${widget.propertyId}";
    }
    return route;
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: couleurBordureActivite),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: couleurTexteActivite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 12, height: 1.3, color: couleurGrisActivite),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Color(0xFF98A6AE)),
            ],
          ),
        ),
      ),
    );
  }

  void navigate(String route) {
    GoRouter.of(context).push(route);
  }
}
