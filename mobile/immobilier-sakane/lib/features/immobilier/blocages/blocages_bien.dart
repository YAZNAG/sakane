import 'package:flutter/material.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/repository/repository.dart';

/// Les dates bloquées d'un bien.
///
/// Pendant une période bloquée, le bien ne peut pas être réservé : le
/// calendrier de réservation montre ces jours comme indisponibles. Le
/// premier et le dernier jour sont des nuits comprises.
class BlocagesBienPage extends StatefulWidget {
  final int realestateId;
  final String? titre;

  const BlocagesBienPage({super.key, required this.realestateId, this.titre});

  @override
  State<BlocagesBienPage> createState() => _BlocagesBienPageState();
}

class _BlocagesBienPageState extends State<BlocagesBienPage> {
  late Future<List<Map<String, dynamic>>> _chargement;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _chargement = _charger();
  }

  Future<List<Map<String, dynamic>>> _charger() =>
      Dependencies.get<Repository>().fetchBlocages(widget.realestateId);

  Future<void> _rafraichir() async {
    setState(() => _chargement = _charger());
    await _chargement;
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return iso ?? '-';
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)}/${d.year}';
  }

  static String _iso(DateTime d) {
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${deux(d.month)}-${deux(d.day)}';
  }

  void _message(String texte, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texte),
      backgroundColor: erreur ? const Color(0xFFB3261E) : null,
      duration: const Duration(seconds: 5),
    ));
  }

  Future<void> _bloquer() async {
    final maintenant = DateTime.now();
    final periode = await showDateRangePicker(
      context: context,
      firstDate: DateTime(maintenant.year, maintenant.month, maintenant.day),
      lastDate: DateTime(maintenant.year + 3, 12, 31),
      helpText: 'Période à bloquer',
      saveText: 'Suivant',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF17262E),
          ),
        ),
        child: child!,
      ),
    );
    if (periode == null || !mounted) return;

    final motif = TextEditingController();
    final nuits = periode.end.difference(periode.start).inDays + 1;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Bloquer ces dates', style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Du ${_date(_iso(periode.start))} au ${_date(_iso(periode.end))} '
              '($nuits nuit${nuits > 1 ? 's' : ''}). Le bien ne pourra pas être réservé '
              'pendant cette période.',
              style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF28414F)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: motif,
              maxLength: 200,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Motif (facultatif)',
                hintText: 'Travaux, séjour du propriétaire…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _enCours = true);
    try {
      await Dependencies.get<Repository>().ajouterBlocage(
        widget.realestateId,
        du: _iso(periode.start),
        au: _iso(periode.end),
        motif: motif.text.trim().isEmpty ? null : motif.text.trim(),
      );
      if (!mounted) return;
      _message('Dates bloquées.');
      await _rafraichir();
    } catch (ex) {
      if (mounted) _message(ex.toString().replaceFirst('Exception: ', ''), erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _debloquer(Map<String, dynamic> b) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Débloquer ces dates ?', style: TextStyle(fontSize: 17)),
        content: Text('Du ${_date(b['du'])} au ${_date(b['au'])} : le bien redeviendra réservable.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Débloquer')),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    try {
      await Dependencies.get<Repository>().supprimerBlocage((b['id'] as num).toInt());
      if (!mounted) return;
      _message('Dates débloquées.');
      await _rafraichir();
    } catch (ex) {
      if (mounted) _message(ex.toString().replaceFirst('Exception: ', ''), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        title: const Text('Dates bloquées',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: !peut(AppPermission.blockDates) ? null : FloatingActionButton.extended(
        onPressed: _enCours ? null : _bloquer,
        backgroundColor: const Color(0xFFB3261E),
        foregroundColor: Colors.white,
        icon: _enCours
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.event_busy),
        label: const Text('Bloquer des dates', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chargement,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: MyLoadingIndicator());
          }
          if (snap.hasError) {
            return MyErrorWidget(
              error: "Les dates bloquées n'ont pas pu être chargées.",
              action: 'Réessayer',
              actionCLick: _rafraichir,
            );
          }
          final blocages = snap.data ?? const [];

          return RefreshIndicator(
            onRefresh: _rafraichir,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                if ((widget.titre ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(widget.titre!,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDEBEC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Color(0xFFB3261E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pendant une période bloquée, le bien ne peut pas être réservé : '
                          'ces jours apparaissent indisponibles dans le calendrier de réservation.',
                          style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF5C1A15)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (blocages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Column(
                      children: [
                        Icon(Icons.event_available, size: 52, color: Color(0xFFB7C3CA)),
                        SizedBox(height: 10),
                        Text('Aucune date bloquée à venir.',
                            style: TextStyle(fontSize: 14.5, color: Color(0xFF6B7B84))),
                      ],
                    ),
                  ),
                ...blocages.map((b) {
                  final nuits = (b['nuits'] as num?)?.toInt() ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8EC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEBEC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event_busy, color: Color(0xFFB3261E)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Du ${_date(b['du'])} au ${_date(b['au'])}',
                                  style: const TextStyle(
                                      fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                              const SizedBox(height: 2),
                              Text(
                                '$nuits nuit${nuits > 1 ? 's' : ''}'
                                '${(b['motif'] ?? '').toString().isEmpty ? '' : ' • ${b['motif']}'}',
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5B64)),
                              ),
                              if ((b['par'] ?? '').toString().isNotEmpty)
                                Text('Bloquée par ${b['par']}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7B84))),
                            ],
                          ),
                        ),
                        if (peut(AppPermission.unblockDates))
                        IconButton(
                          tooltip: 'Débloquer',
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
                          onPressed: () => _debloquer(b),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
