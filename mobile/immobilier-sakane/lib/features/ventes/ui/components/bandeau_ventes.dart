import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// En-tete des dossiers de vente : un compteur par statut, en ligne.
/// Chaque compteur ouvre la liste filtree.
class BandeauVentes extends StatefulWidget {
  const BandeauVentes({super.key});

  @override
  State<BandeauVentes> createState() => BandeauVentesState();
}

class BandeauVentesState extends State<BandeauVentes> {
  TableauVentes? _tableau;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  /// Les compteurs sont un plus : sans reponse, ils affichent un tiret.
  Future<void> recharger() async {
    if (!peutVoirVentes) return;
    try {
      final t = await Dependencies.get<Repository>().fetchTableauVentes();
      if (mounted) setState(() => _tableau = t);
    } catch (_) {}
  }

  Future<void> _ouvrir(String route) async {
    await GoRouter.of(context).push(route);
    if (mounted) recharger();
  }

  @override
  Widget build(BuildContext context) {
    if (!peutVoirVentes) return const SizedBox();
    final t = _tableau;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CouleursBail.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, size: 18, color: CouleursVente.teinte),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Statuts de vente',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
              ),
              TextButton(
                onPressed: () => _ouvrir(cheminVentes()),
                style: TextButton.styleFrom(foregroundColor: CouleursVente.teinte, visualDensity: VisualDensity.compact),
                child: const Text('Tous les biens'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _compteur('À vendre', t?.aVendre, CouleursVente.aVendre, Icons.sell_outlined, cheminVentes(filtre: 'a_vendre')),
                _compteur('Sous compromis', t?.compromis, CouleursVente.compromis, Icons.handshake_outlined,
                    cheminVentes(filtre: 'compromis')),
                _compteur('Vendus', t?.vendus, CouleursVente.vendu, Icons.verified_outlined, cheminVentes(filtre: 'vendu')),
                _compteur('Sans mandat', t?.sansMandat, CouleursVente.sansMandat, Icons.assignment_late_outlined,
                    cheminVentes(filtre: 'sans_mandat')),
                _compteur('Visites ce mois', t?.visitesCeMois, const Color(0xFFD64545), Icons.directions_walk,
                    Routes.visitesVentes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compteur(String libelle, int? nombre, Color couleur, IconData icone, String route) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: couleur.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _ouvrir(route),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icone, size: 15, color: couleur),
                    const SizedBox(width: 5),
                    Text(nombre == null ? '—' : '$nombre',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: couleur)),
                  ],
                ),
                Text(libelle, style: const TextStyle(fontSize: 11.5, color: CouleursBail.texte)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
