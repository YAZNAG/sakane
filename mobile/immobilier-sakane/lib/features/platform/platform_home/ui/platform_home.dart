import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';


class PlatformHome extends StatefulWidget {
  const PlatformHome({Key? key}) : super(key: key);

  @override
  State<PlatformHome> createState() => _PlatformHomeState();
}

class _PlatformHomeState extends State<PlatformHome> {

  Manager manager=Dependencies.get<Manager>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Gestion de la Plateforme",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Header Card
            _buildPlatformHeaderCard(),

            const SizedBox(height: 24),

            // Website Management Section
            if(manager.can(AppPermission.viewSlider))
            _buildWebsiteManagementSection(),

            const SizedBox(height: 24),

            // Announcements Section
            if(manager.canAny(const [AppPermission.viewAnnounces, AppPermission.activateAnnounce, AppPermission.cancelAnnounce]))
            _buildAnnouncementsSection(),

            const SizedBox(height: 24),

            // Reservations Section
            //_buildReservationsSection(),

            const SizedBox(height: 24),

            // Additional Actions Section
            //_buildAdditionalActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.9),
            ),
            const SizedBox(height: 16),
            const Text(
              "Tableau de Bord",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Gérez tous les aspects de votre plateforme",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebsiteManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gestion du Site Web",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _buildActionCard(
            title: "Gérer les Images du Slider",
            subtitle: "Modifier les images de la page d'accueil",
            icon: Icons.photo_library_outlined,
            color: Colors.purple,
            onTap: _onManageSlider,
            isWide: true,
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gestion des Annonces",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _buildActionCard(
            title: "Annonces des Hôtes",
            subtitle: "Accepter ou refuser les annonces en attente",
            icon: Icons.announcement_outlined,
            color: Colors.orange,
            onTap: _onManageAnnouncements,
            isWide: true,
            showBadge: false,
            badgeCount: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Gestion des Réservations",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _buildActionCard(
            title: "Réservations de la Plateforme",
            subtitle: "Confirmer ou refuser les réservations",
            icon: Icons.event_available_outlined,
            color: Colors.teal,
            onTap: _onManageReservations,
            isWide: true,
            showBadge: true,
            badgeCount: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Autres Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: "Utilisateurs",
                icon: Icons.people_outline,
                color: Colors.blue,
                onTap: _onManageUsers,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: "Rapports",
                icon: Icons.assessment_outlined,
                color: Colors.green,
                onTap: _onViewReports,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isWide = false,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isWide
            ? Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                if (showBadge && badgeCount > 0)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        )
            : Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                if (showBadge && badgeCount > 0)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Navigation methods
  void _onManageSlider() {
    GoRouter.of(context).push(Routes.sliders);
  }

  void _onManageAnnouncements() {
     GoRouter.of(context).push(Routes.announces);
  }

  void _onManageReservations() {
    // GoRouter.of(context).push(Routes.platformReservations);
  }

  void _onManageUsers() {
    // GoRouter.of(context).push(Routes.manageUsers);
  }

  void _onViewReports() {
    // GoRouter.of(context).push(Routes.platformReports);
  }
}