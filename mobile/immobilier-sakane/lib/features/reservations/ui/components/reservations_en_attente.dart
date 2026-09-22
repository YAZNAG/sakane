import 'package:flutter/material.dart';
import 'package:immobilier/core/offline/operation_en_attente.dart';
import 'package:immobilier/core/offline/synchronisation.dart';

/// Reservations enregistrees sans connexion, affichees au dessus de la
/// liste tant que le serveur n'a pas confirme la disponibilite du bien.
class ReservationsEnAttente extends StatelessWidget {
  const ReservationsEnAttente({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Synchronisation.instance,
      builder: (context, _) {
        final synchro = Synchronisation.instance;
        final attente = synchro.enAttente
            .where((o) => o.type == 'booking')
            .toList();
        final refusees =
            synchro.refusees.where((o) => o.type == 'booking').toList();

        if (attente.isEmpty && refusees.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...attente.map((o) => _carte(
                    o,
                    couleur: Colors.orange.shade700,
                    fond: Colors.orange.shade50,
                    icone: Icons.schedule,
                    mention: "En attente de synchronisation",
                    detail:
                        "La disponibilité sera vérifiée par le serveur au retour de la connexion.",
                  )),
              ...refusees.map((o) => _carte(
                    o,
                    couleur: Colors.red.shade700,
                    fond: Colors.red.shade50,
                    icone: Icons.error_outline,
                    mention: "Refusée par le serveur",
                    detail: o.message ??
                        "Le bien n'était plus disponible à ces dates.",
                    onFermer: () => Synchronisation.instance.oublier(o.id),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _carte(
    OperationEnAttente operation, {
    required Color couleur,
    required Color fond,
    required IconData icone,
    required String mention,
    required String detail,
    VoidCallback? onFermer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: fond,
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mention,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: couleur,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  operation.libelle,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (onFermer != null)
            IconButton(
              onPressed: onFermer,
              icon: const Icon(Icons.close, size: 17),
              tooltip: "Retirer",
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
