import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:immobilier/core/constants/app_colors.dart';

/// Valeurs saisies dans le formulaire de contrat.
class ContratFormulaireResultat {
  final String? titre;

  /// Format yyyy-MM-dd (attendu par le serveur).
  final String? dateDebut;
  final String? dateFin;

  const ContratFormulaireResultat({this.titre, this.dateDebut, this.dateFin});
}

/// Dialogue de saisie des informations d'un contrat avant envoi.
class FormulaireContratDialog extends StatefulWidget {
  final String nomFichier;
  final int? tailleOctets;
  final String? bien;

  const FormulaireContratDialog({
    super.key,
    required this.nomFichier,
    this.tailleOctets,
    this.bien,
  });

  static Future<ContratFormulaireResultat?> afficher(
    BuildContext context, {
    required String nomFichier,
    int? tailleOctets,
    String? bien,
  }) {
    return showDialog<ContratFormulaireResultat>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FormulaireContratDialog(
        nomFichier: nomFichier,
        tailleOctets: tailleOctets,
        bien: bien,
      ),
    );
  }

  @override
  State<FormulaireContratDialog> createState() => _FormulaireContratDialogState();
}

class _FormulaireContratDialogState extends State<FormulaireContratDialog> {
  static final DateFormat _affichage = DateFormat('dd/MM/yyyy');
  static final DateFormat _envoi = DateFormat('yyyy-MM-dd');

  final TextEditingController _titre = TextEditingController();
  DateTime? _debut;
  DateTime? _fin;
  String? _erreur;

  @override
  void dispose() {
    _titre.dispose();
    super.dispose();
  }

  Future<void> _choisirDate({required bool debut}) async {
    final maintenant = DateTime.now();
    final premiere = debut ? DateTime(2000) : (_debut ?? DateTime(2000));
    DateTime initiale = (debut ? _debut : _fin) ?? (debut ? maintenant : (_debut ?? maintenant));
    if (initiale.isBefore(premiere)) initiale = premiere;

    final choisie = await showDatePicker(
      context: context,
      initialDate: initiale,
      firstDate: premiere,
      lastDate: DateTime(2100),
      helpText: debut ? 'Date de début' : 'Date de fin',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (choisie == null) return;
    setState(() {
      _erreur = null;
      if (debut) {
        _debut = choisie;
        if (_fin != null && _fin!.isBefore(choisie)) _fin = null;
      } else {
        _fin = choisie;
      }
    });
  }

  void _valider() {
    if (_debut != null && _fin != null && _fin!.isBefore(_debut!)) {
      setState(() => _erreur = 'La date de fin doit être postérieure ou égale à la date de début.');
      return;
    }
    Navigator.of(context).pop(ContratFormulaireResultat(
      titre: _titre.text.trim().isEmpty ? null : _titre.text.trim(),
      dateDebut: _debut != null ? _envoi.format(_debut!) : null,
      dateFin: _fin != null ? _envoi.format(_fin!) : null,
    ));
  }

  String _taille(int octets) {
    if (octets < 1024) return '$octets o';
    if (octets < 1024 * 1024) return '${(octets / 1024).toStringAsFixed(0)} Ko';
    return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final estPdf = widget.nomFichier.toLowerCase().endsWith('.pdf');
    return AlertDialog(
      title: Text('Joindre un contrat', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.bien != null) ...[
              Row(
                children: [
                  Icon(Icons.home_outlined, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.bien!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
            ],
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    estPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                    color: estPdf ? Colors.red.shade600 : AppColors.primaryColor,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nomFichier,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.tailleOctets != null)
                          Text(
                            _taille(widget.tailleOctets!),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _titre,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Titre (optionnel)',
                hintText: 'Ex : Contrat de gestion 2026',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            SizedBox(height: 12),
            _champDate(
              libelle: 'Date de début (optionnelle)',
              valeur: _debut,
              onTap: () => _choisirDate(debut: true),
              onEffacer: () => setState(() => _debut = null),
            ),
            SizedBox(height: 12),
            _champDate(
              libelle: 'Date de fin (optionnelle)',
              valeur: _fin,
              onTap: () => _choisirDate(debut: false),
              onEffacer: () => setState(() => _fin = null),
            ),
            if (_erreur != null) ...[
              SizedBox(height: 10),
              Text(_erreur!, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Annuler'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _valider,
          icon: Icon(Icons.upload_file, size: 18),
          label: Text('Envoyer'),
        ),
      ],
    );
  }

  Widget _champDate({
    required String libelle,
    required DateTime? valeur,
    required VoidCallback onTap,
    required VoidCallback onEffacer,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: libelle,
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: valeur != null
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18),
                  tooltip: 'Effacer',
                  onPressed: onEffacer,
                )
              : Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          valeur != null ? _affichage.format(valeur) : 'jj/mm/aaaa',
          style: TextStyle(
            fontSize: 14,
            color: valeur != null ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
