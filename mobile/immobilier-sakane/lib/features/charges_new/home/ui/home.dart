import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes.dart';
import 'package:immobilier/core/constants/app_colors.dart';


class ChargesHome extends StatefulWidget {
  final int? propertyId;

  const ChargesHome({Key? key, this.propertyId}) : super(key: key);

  @override
  State<ChargesHome> createState() => _ChargesHomeState();
}

class _ChargesHomeState extends State<ChargesHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Charges',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildOptionCard(
              icon: Icons.receipt_long,
              title: "Charges",
              description: "Consulter et ajouter les charges enregistrées",
              color: Colors.orange.shade700,
              backgroundColor: Colors.orange.shade50,
              onTap: () {
                final route=prepareRoute(Routes.chargesList);
                print(route);
                navigate(route);
              },
            ),
            // La carte « Charges Programmées » a été retirée de ce
            // module : l'écran et sa route (Routes.programedCharges)
            // existent toujours, ils ne sont simplement plus proposés ici.
          ],
        ),
      ),
    );
  }
  String prepareRoute(String route){
    if(widget.propertyId!=null){
      route+="?realestate=${widget.propertyId}";
    }
    return route;
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  void navigate(String route) {
    GoRouter.of(context).push(route);
  }
}