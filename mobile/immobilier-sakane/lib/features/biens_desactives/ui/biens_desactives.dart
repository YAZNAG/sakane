import 'package:flutter/material.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bien_desactive.dart';
import 'package:immobilier/repository/repository.dart';

/// « Biens désactivés » : les biens retirés des listes, avec leur
/// réactivation. Le serveur reste juge des droits (403).
class BiensDesactivesPage extends StatefulWidget {
  const BiensDesactivesPage({super.key});

  @override
  State<BiensDesactivesPage> createState() => _BiensDesactivesPageState();
}

class _BiensDesactivesPageState extends State<BiensDesactivesPage> {
  List<BienDesactive>? _biens;
  String? _erreur;
  final Set<int> _enCours = {};

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _erreur = null;
      _biens = null;
    });
    try {
      final liste = await Dependencies.get<Repository>().biensDesactives();
      if (mounted) setState(() => _biens = liste);
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreur(ex));
    }
  }

  Future<void> _reactiver(BienDesactive bien) async {
    if (_enCours.contains(bien.id)) return;
    setState(() => _enCours.add(bien.id));
    final reactive = await reactiverBienAvecDialogue(context, bien.id, titre: bien.titre);
    if (!mounted) return;
    setState(() {
      _enCours.remove(bien.id);
      if (reactive != null) _biens?.removeWhere((b) => b.id == bien.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Biens désactivés', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (_erreur != null) {
      return MyErrorWidget(error: _erreur!, action: AppStrings.tryAgain, actionCLick: _charger);
    }
    final biens = _biens;
    if (biens == null) return Center(child: MyLoadingIndicator());

    if (biens.isEmpty) {
      return RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Aucun bien désactivé.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: biens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _carte(biens[i]),
      ),
    );
  }

  Widget _carte(BienDesactive bien) {
    final details = <String>[
      if (bien.desactiveLe != null) 'Désactivé le ${bien.desactiveLe!.toLocal().formattedDateFr}',
      if (bien.desactivePar != null) 'par ${bien.desactivePar}',
    ].join(' ');
    final enCours = _enCours.contains(bien.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: couleurDesactivation.withValues(alpha: 0.08),
            child: const Icon(Icons.visibility_off_outlined, color: couleurDesactivation),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (bien.titre ?? '').isEmpty ? 'Bien n°${bien.id}' : bien.titre!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(details, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                ],
                if (bien.motif != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Motif : ${bien.motif}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 10),
                if (peutReactiverBien())
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: enCours ? null : () => _reactiver(bien),
                    icon: enCours
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.restore, size: 18),
                    label: const Text('Réactiver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
