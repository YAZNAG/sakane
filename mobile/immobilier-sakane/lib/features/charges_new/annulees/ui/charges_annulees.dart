import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/charge_annulee.dart';
import 'package:immobilier/repository/repository.dart';

/// L'historique des charges annulées.
///
/// Une charge annulée quitte la liste courante mais reste ici : on
/// retrouve ce qui avait été dépensé, ce qui en a été rendu, et qui a
/// fait quoi.
class ChargesAnnuleesPage extends StatefulWidget {
  const ChargesAnnuleesPage({super.key});

  static Widget page() => const ChargesAnnuleesPage();

  @override
  State<ChargesAnnuleesPage> createState() => _ChargesAnnuleesPageState();
}

class _ChargesAnnuleesPageState extends State<ChargesAnnuleesPage> {

  List<ChargeAnnulee>? _affichees;

  TableauExportable? _tableauExport() {
    final liste = _affichees;
    if (liste == null) return null;
    double montant = 0, rendu = 0;
    final lignes = liste.map((c) {
      montant += c.montant;
      rendu += c.rembourse ?? 0;
      return [
        dateHeureExport(c.annuleeLe),
        c.nom ?? '',
        c.bien ?? '',
        montantExport(c.montant),
        montantExport(c.rembourse ?? 0),
        c.motif ?? '',
        c.creeePar ?? '',
        c.annuleePar ?? '',
        dateExport(c.creeeLe),
      ];
    }).toList();
    return TableauExportable(
      titre: 'Charges annulées',
      colonnes: const ['Annulée le', 'Charge', 'Bien', 'Montant', 'Rendu en caisse', 'Motif',
          'Saisie par', 'Annulée par', 'Saisie le'],
      lignes: lignes,
      totaux: ['TOTAL', '', '', montantExport(montant), montantExport(rendu), '', '', '', ''],
    );
  }

  late Future<List<ChargeAnnulee>> _chargement;

  @override
  void initState() {
    super.initState();
    _chargement = _charger();
  }

  Future<List<ChargeAnnulee>> _charger() =>
      Dependencies.get<Repository>().chargesAnnulees();

  Future<void> _rafraichir() async {
    setState(() => _chargement = _charger());
    await _chargement;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Charges annulées",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [BoutonExport(tableau: _tableauExport)],
      ),
      body: FutureBuilder<List<ChargeAnnulee>>(
        future: _chargement,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: MyLoadingIndicator());
          }
          if (snap.hasError) {
            return MyErrorWidget(
              error: "L'historique n'a pas pu être chargé.",
              action: "Réessayer",
              actionCLick: _rafraichir,
            );
          }

          final liste = snap.data ?? const <ChargeAnnulee>[];
          _affichees = liste;
          final rendu = liste.fold<double>(0, (s, c) => s + (c.rembourse ?? 0));

          return RefreshIndicator(
            onRefresh: _rafraichir,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _Resume(nombre: liste.length, rendu: rendu),
                const SizedBox(height: 12),
                if (liste.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.block_outlined,
                            size: 46, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text("Aucune charge annulée.",
                            style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ...liste.map((c) => _Carte(charge: c)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Ce que représente l'historique, en deux chiffres.
class _Resume extends StatelessWidget {
  final int nombre;
  final double rendu;

  const _Resume({required this.nombre, required this.rendu});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2E7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFA8542B)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              nombre == 0
                  ? "Les charges annulées se retrouvent ici, avec le montant "
                      "rendu en caisse."
                  : "$nombre charge${nombre > 1 ? 's' : ''} annulée"
                      "${nombre > 1 ? 's' : ''} • "
                      "${rendu.toStringAsFixed(2)} MAD rendus en caisse.",
              style: const TextStyle(
                  fontSize: 12.5, color: Color(0xFF6B3A1C), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une charge annulée : ce qu'elle valait, ce qui en est revenu.
class _Carte extends StatelessWidget {
  final ChargeAnnulee charge;

  const _Carte({required this.charge});

  @override
  Widget build(BuildContext context) {
    final c = charge;
    final rendu = c.rembourse ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (c.nom ?? "").isEmpty ? "Charge" : c.nom!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.black87),
                ),
              ),
              Text(
                "${c.montant.toStringAsFixed(2)} MAD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          if ((c.bien ?? "").isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(c.bien!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: rendu > 0 ? const Color(0xFFE4F1EC) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(rendu > 0 ? Icons.south_west : Icons.remove,
                    size: 15,
                    color: rendu > 0
                        ? const Color(0xFF1E8560)
                        : Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  rendu > 0
                      ? "${rendu.toStringAsFixed(2)} MAD rendus en caisse"
                      : "Rien n'a été rendu",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: rendu > 0
                        ? const Color(0xFF14603F)
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if ((c.motif ?? "").isNotEmpty) ...[
            const SizedBox(height: 7),
            Text("Motif : ${c.motif}",
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 3,
            children: [
              if ((c.creeePar ?? "").isNotEmpty)
                _Mention(icone: Icons.person_outline, texte: "Saisie par ${c.creeePar}"),
              if ((c.annuleePar ?? "").isNotEmpty)
                _Mention(icone: Icons.block, texte: "Annulée par ${c.annuleePar}"),
              if (c.annuleeLe != null)
                _Mention(
                    icone: Icons.schedule,
                    texte: "Le ${_jour(c.annuleeLe!)}"),
            ],
          ),
        ],
      ),
    );
  }

  static String _jour(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}

class _Mention extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Mention({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(texte,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      ],
    );
  }
}
