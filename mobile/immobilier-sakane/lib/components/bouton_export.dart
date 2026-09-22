import 'dart:io';

import 'package:flutter/material.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Ce qu'une page exporte : ce qu'elle affiche, une ligne par élément.
class TableauExportable {
  final String titre;
  final String? sousTitre;
  final List<String> colonnes;
  final List<List<String>> lignes;
  final List<String>? totaux;

  const TableauExportable({
    required this.titre,
    this.sousTitre,
    required this.colonnes,
    required this.lignes,
    this.totaux,
  });

  Map<String, dynamic> versJson(String format) => {
        'format': format,
        'titre': titre,
        if (sousTitre != null && sousTitre!.isNotEmpty) 'sousTitre': sousTitre,
        'colonnes': colonnes,
        'lignes': lignes,
        if (totaux != null) 'totaux': totaux,
      };
}

/// Un montant tel que le tableur sait l'additionner.
String montantExport(num? v) => (v ?? 0).toStringAsFixed(2);

String dateExport(DateTime? d) {
  if (d == null) return '';
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${deux(d.day)}/${deux(d.month)}/${d.year}';
}

String dateHeureExport(DateTime? d) {
  if (d == null) return '';
  String deux(int n) => n.toString().padLeft(2, '0');
  return '${dateExport(d)} ${deux(d.hour)}:${deux(d.minute)}';
}

/// Le bouton « Exporter » d'une barre de titre : Excel ou PDF, avec le
/// détail de chaque ligne affichée.
class BoutonExport extends StatelessWidget {
  /// Construit le tableau au moment de l'appui, pour exporter ce qui est
  /// affiché à cet instant. Nul quand rien n'est encore chargé.
  final TableauExportable? Function() tableau;
  final Color couleur;

  const BoutonExport({super.key, required this.tableau, this.couleur = Colors.white});

  @override
  Widget build(BuildContext context) {
    // Droit « Exporter en Excel / PDF ».
    if (!peut(AppPermission.exportData)) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Exporter (Excel / PDF)',
      icon: Icon(Icons.file_download_outlined, color: couleur),
      onPressed: () => _choisir(context),
    );
  }

  Future<void> _choisir(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    final t = tableau();
    if (t == null) {
      messager.showSnackBar(const SnackBar(
          content: Text("Rien à exporter pour l'instant : attendez la fin du chargement.")));
      return;
    }

    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DDE2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Exporter « ${t.titre} »',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
              ),
              const SizedBox(height: 4),
              Text(
                '${t.lignes.length} ligne${t.lignes.length > 1 ? 's' : ''}'
                '${(t.sousTitre ?? '').isEmpty ? '' : ' • ${t.sousTitre}'}',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7B84)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ChoixFormat(
                      icone: Icons.table_chart_outlined,
                      titre: 'Excel',
                      detail: 'Tableur .xlsx',
                      couleur: const Color(0xFF1E7B45),
                      onTap: () => Navigator.of(feuille).pop('xlsx'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChoixFormat(
                      icone: Icons.picture_as_pdf_outlined,
                      titre: 'PDF',
                      detail: 'Document à imprimer',
                      couleur: const Color(0xFFB3261E),
                      onTap: () => Navigator.of(feuille).pop('pdf'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (format == null || !context.mounted) return;
    await _exporter(context, t, format);
  }

  Future<void> _exporter(BuildContext context, TableauExportable t, String format) =>
      lancerExport(context, t, format);
}

/// Lance l'export d'un tableau au format voulu ('xlsx' ou 'pdf') : le
/// fichier est fabriqué par le serveur, ouvert, et proposé au partage.
Future<void> lancerExport(BuildContext context, TableauExportable t, String format) async {
  final messager = ScaffoldMessenger.of(context);
  final navigateur = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 16),
          Expanded(child: Text('Préparation du fichier…')),
        ],
      ),
    ),
  );

  try {
    final octets = await Dependencies.get<Repository>().exporterTableau(t.versJson(format));
    final dossier = await getTemporaryDirectory();
    final base = t.titre
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9àâäéèêëîïôöùûüç]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final horodatage = DateTime.now().millisecondsSinceEpoch;
    final chemin = '${dossier.path}/${base.isEmpty ? 'export' : base}_$horodatage.$format';
    await File(chemin).writeAsBytes(octets, flush: true);

    navigateur.pop();

    final ouverture = await OpenFile.open(chemin);
    final message = messager.showSnackBar(SnackBar(
      content: Text(ouverture.type == ResultType.done
          ? 'Fichier ${format == 'pdf' ? 'PDF' : 'Excel'} prêt.'
          : 'Aucune application pour ouvrir ce fichier : partagez-le.'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Partager',
        onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(chemin)])),
      ),
    ));
    // Un message qui porte un bouton reste affiché tant qu'on ne le ferme
    // pas : on le retire nous-mêmes après 5 secondes.
    Future.delayed(const Duration(seconds: 5), () {
      try {
        message.close();
      } catch (_) {}
    });
  } catch (_) {
    navigateur.pop();
    messager.showSnackBar(const SnackBar(
      content: Text("L'export a échoué. Vérifiez la connexion puis réessayez."),
    ));
  }
}

class _ChoixFormat extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;
  final Color couleur;
  final VoidCallback onTap;

  const _ChoixFormat({
    required this.icone,
    required this.titre,
    required this.detail,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: couleur.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: couleur.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icone, size: 32, color: couleur),
              const SizedBox(height: 8),
              Text(titre,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur)),
              const SizedBox(height: 2),
              Text(detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF4A5B64))),
            ],
          ),
        ),
      ),
    );
  }
}
