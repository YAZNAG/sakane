import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/utils/icones_serveur.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/charge_fixe.dart';
import 'package:immobilier/models/realestate.dart';

/// Ce que le formulaire rend quand il est validé : la saisie, et le
/// justificatif s'il y en a un.
class ResultatChargeFixe {
  final SaisieChargeFixe saisie;
  final File? document;

  const ResultatChargeFixe(this.saisie, {this.document});
}

/// La feuille de saisie d'une charge fixe : un nom, un montant, une
/// famille, et le choix de la répéter chaque mois.
///
/// En modification, la répétition n'est plus proposée : elle se gère par
/// son échéance, dans la section « Chaque mois » — sans quoi modifier une
/// charge en poserait une deuxième.
class FeuilleChargeFixe extends StatefulWidget {
  final List<CategorieCharge> catalogue;
  final List<Realestate> biens;
  final Charge? charge;

  /// La famille pré-choisie quand on ajoute depuis une famille ouverte.
  final String? famillePreChoisie;

  const FeuilleChargeFixe({
    super.key,
    required this.catalogue,
    this.biens = const [],
    this.charge,
    this.famillePreChoisie,
  });

  /// Ouvre la feuille et rend la saisie, ou null si elle est abandonnée.
  static Future<ResultatChargeFixe?> ouvrir(
    BuildContext context, {
    required List<CategorieCharge> catalogue,
    List<Realestate> biens = const [],
    Charge? charge,
    String? famillePreChoisie,
  }) {
    return showModalBottomSheet<ResultatChargeFixe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeuilleChargeFixe(
        catalogue: catalogue,
        biens: biens,
        charge: charge,
        famillePreChoisie: famillePreChoisie,
      ),
    );
  }

  @override
  State<FeuilleChargeFixe> createState() => _FeuilleChargeFixeState();
}

class _FeuilleChargeFixeState extends State<FeuilleChargeFixe> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _montant = TextEditingController();
  final _description = TextEditingController();
  final _libelleLibre = TextEditingController();

  String? _famille;
  int? _bienId;
  bool _payee = true;
  bool _mensuelle = false;
  int _jour = DateTime.now().day > 28 ? 28 : DateTime.now().day;
  File? _document;

  bool get _modification => widget.charge != null;

  @override
  void initState() {
    super.initState();
    final charge = widget.charge;
    if (charge != null) {
      _nom.text = charge.nom ?? '';
      _description.text = charge.description ?? '';
      _montant.text = _sansZeroInutile(charge.amount);
      _famille = charge.categorie;
      _bienId = charge.realEstate?.id;
      _payee = charge.status != 'pending';
      if (charge.categorie == 'autre') {
        _libelleLibre.text = charge.categorieLibelle ?? '';
      }
    } else {
      _famille = widget.famillePreChoisie;
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _montant.dispose();
    _description.dispose();
    _libelleLibre.dispose();
    super.dispose();
  }

  String _sansZeroInutile(double? valeur) {
    if (valeur == null) return '';
    return valeur == valeur.roundToDouble()
        ? valeur.round().toString()
        : valeur.toString();
  }

  CategorieCharge? get _familleChoisie {
    for (final c in widget.catalogue) {
      if (c.code == _famille) return c;
    }
    return null;
  }

  bool get _demandeUnNom => _familleChoisie?.libre ?? false;

  @override
  Widget build(BuildContext context) {
    final basClavier = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: basClavier),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _poignee(),
            _entete(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                child: Form(
                  key: _formulaire,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titreChamp('Famille de charge'),
                      const SizedBox(height: 8),
                      _familles(),
                      if (_demandeUnNom) ...[
                        const SizedBox(height: 12),
                        _champ(
                          controleur: _libelleLibre,
                          etiquette: 'Nom de la famille',
                          indication: 'Frais bancaires, honoraires...',
                          icone: Icons.sell_outlined,
                          validateur: (v) => (v ?? '').trim().isEmpty
                              ? 'Donnez un nom à cette famille'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _titreChamp('La charge'),
                      const SizedBox(height: 8),
                      _champ(
                        controleur: _nom,
                        etiquette: 'Intitulé',
                        indication: 'Salaire de Karim, abonnement internet...',
                        icone: Icons.label_outline,
                        validateur: (v) => (v ?? '').trim().isEmpty
                            ? 'Indiquez ce que règle cette charge'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _champ(
                        controleur: _montant,
                        etiquette: 'Montant (MAD)',
                        indication: '0',
                        icone: Icons.payments_outlined,
                        clavier: const TextInputType.numberWithOptions(decimal: true),
                        formateurs: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        validateur: (v) {
                          final montant = _lireMontant(v);
                          if (montant == null) return 'Montant invalide';
                          if (montant <= 0) return 'Le montant doit être supérieur à 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _champ(
                        controleur: _description,
                        etiquette: 'Détail (optionnel)',
                        indication: 'Mois de septembre, n° de facture...',
                        icone: Icons.notes_outlined,
                        lignes: 2,
                      ),
                      const SizedBox(height: 18),
                      _titreChamp('Rattachement'),
                      const SizedBox(height: 8),
                      _choixBien(),
                      const SizedBox(height: 18),
                      _titreChamp('Règlement'),
                      const SizedBox(height: 8),
                      _choixReglement(),
                      if (!_modification) ...[
                        const SizedBox(height: 18),
                        _repetition(),
                        const SizedBox(height: 14),
                        _justificatif(),
                      ],
                      const SizedBox(height: 22),
                      _boutons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poignee() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD7DEE3),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _entete() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 10, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _modification ? Icons.edit_outlined : Icons.add_card_outlined,
                color: AppColors.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                _modification ? 'Modifier la charge fixe' : 'Nouvelle charge fixe',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: couleurTexteActivite,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: couleurGrisActivite),
            ),
          ],
        ),
      );

  Widget _titreChamp(String texte) => Text(
        texte.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          letterSpacing: .6,
          color: couleurGrisActivite,
        ),
      );

  /// Les familles, en pastilles : celle qui est choisie prend sa couleur.
  Widget _familles() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.catalogue.map((famille) {
        final choisie = famille.code == _famille;
        final teinte =
            couleurServeur(famille.couleur, defaut: AppColors.primaryColor);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _famille = famille.code),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: choisie ? teinte.withValues(alpha: .12) : Colors.white,
              border: Border.all(
                color: choisie ? teinte : couleurBordureActivite,
                width: choisie ? 1.4 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconeServeur(famille.icone), size: 16, color: teinte),
                const SizedBox(width: 7),
                Text(
                  famille.libelle,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: choisie ? FontWeight.bold : FontWeight.w500,
                    color: choisie ? teinte : couleurTexteActivite,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _champ({
    required TextEditingController controleur,
    required String etiquette,
    required IconData icone,
    String? indication,
    TextInputType? clavier,
    List<TextInputFormatter>? formateurs,
    String? Function(String?)? validateur,
    int lignes = 1,
  }) {
    return TextFormField(
      controller: controleur,
      keyboardType: clavier,
      inputFormatters: formateurs,
      validator: validateur,
      maxLines: lignes,
      style: const TextStyle(fontSize: 14, color: couleurTexteActivite),
      decoration: InputDecoration(
        labelText: etiquette,
        hintText: indication,
        prefixIcon: Icon(icone, size: 19, color: couleurGrisActivite),
        labelStyle: const TextStyle(fontSize: 13, color: couleurGrisActivite),
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFA9B4BA)),
        filled: true,
        fillColor: couleurFondActivite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: couleurBordureActivite),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: couleurBordureActivite),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryColor, width: 1.4),
        ),
      ),
    );
  }

  /// L'agence, ou l'un de ses appartements.
  Widget _choixBien() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: couleurFondActivite,
        border: Border.all(color: couleurBordureActivite),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _bienId,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: couleurGrisActivite),
          style: const TextStyle(fontSize: 13.5, color: couleurTexteActivite),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.business_outlined, size: 18, color: couleurGrisActivite),
                  SizedBox(width: 8),
                  Text('Agence (aucun bien)'),
                ],
              ),
            ),
            ...widget.biens.where((b) => b.id != null).map(
                  (b) => DropdownMenuItem<int?>(
                    value: b.id,
                    child: Row(
                      children: [
                        const Icon(Icons.home_work_outlined,
                            size: 18, color: couleurGrisActivite),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b.title ?? 'Bien #${b.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          onChanged: (v) => setState(() => _bienId = v),
        ),
      ),
    );
  }

  /// Réglée maintenant — et la caisse est débitée — ou en attente.
  Widget _choixReglement() {
    return Row(
      children: [
        Expanded(
          child: _bascule(
            titre: 'Réglée',
            sousTitre: 'Sort de votre caisse',
            icone: Icons.check_circle_outline,
            actif: _payee,
            teinte: couleurVertActivite,
            onTap: () => setState(() => _payee = true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _bascule(
            titre: 'En attente',
            sousTitre: 'À régler plus tard',
            icone: Icons.schedule,
            actif: !_payee,
            teinte: couleurOrangeActivite,
            onTap: () => setState(() => _payee = false),
          ),
        ),
      ],
    );
  }

  Widget _bascule({
    required String titre,
    required String sousTitre,
    required IconData icone,
    required bool actif,
    required Color teinte,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          color: actif ? teinte.withValues(alpha: .1) : couleurFondActivite,
          border: Border.all(
            color: actif ? teinte : couleurBordureActivite,
            width: actif ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 17, color: actif ? teinte : couleurGrisActivite),
                const SizedBox(width: 6),
                Text(
                  titre,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: actif ? teinte : couleurTexteActivite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              sousTitre,
              style: const TextStyle(fontSize: 11, color: couleurGrisActivite),
            ),
          ],
        ),
      ),
    );
  }

  /// La répétition mensuelle : le jour du mois où la charge reviendra.
  Widget _repetition() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: couleurFondActivite,
        border: Border.all(color: couleurBordureActivite),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            value: _mensuelle,
            onChanged: (v) => setState(() => _mensuelle = v),
            activeColor: AppColors.primaryColor,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Chaque mois',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: couleurTexteActivite,
              ),
            ),
            subtitle: const Text(
              'La charge sera recréée automatiquement, en attente de règlement',
              style: TextStyle(fontSize: 11.5, color: couleurGrisActivite),
            ),
          ),
          if (_mensuelle) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.event_repeat_outlined,
                    size: 17, color: couleurGrisActivite),
                const SizedBox(width: 8),
                const Text(
                  'Le',
                  style: TextStyle(fontSize: 13, color: couleurGrisActivite),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: couleurBordureActivite),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _jour,
                      icon: const Icon(Icons.expand_more,
                          size: 18, color: couleurGrisActivite),
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: couleurTexteActivite),
                      items: [
                        for (var j = 1; j <= 28; j++)
                          DropdownMenuItem(value: j, child: Text('$j'))
                      ],
                      onChanged: (v) => setState(() => _jour = v ?? _jour),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'de chaque mois',
                    style: TextStyle(fontSize: 12.5, color: couleurGrisActivite),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Au-delà du 28, un mois court sauterait l’échéance.',
                style: TextStyle(fontSize: 10.5, color: couleurGrisActivite),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _justificatif() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _choisirDocument,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: couleurFondActivite,
          border: Border.all(
            color: _document == null ? couleurBordureActivite : couleurVertActivite,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              _document == null
                  ? Icons.attach_file_outlined
                  : Icons.check_circle_outline,
              size: 19,
              color: _document == null ? couleurGrisActivite : couleurVertActivite,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _document == null
                    ? 'Joindre un justificatif (optionnel)'
                    : 'Justificatif joint',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _document == null
                      ? couleurGrisActivite
                      : couleurVertActivite,
                ),
              ),
            ),
            if (_document != null)
              IconButton(
                onPressed: () => setState(() => _document = null),
                icon: const Icon(Icons.delete_outline,
                    size: 19, color: couleurRougeActivite),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _choisirDocument() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final choisi = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (choisi != null && mounted) {
      setState(() => _document = File(choisi.path));
    }
  }

  Widget _boutons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: couleurBordureActivite),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Annuler',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: couleurGrisActivite)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _valider,
            icon: Icon(_modification ? Icons.save_outlined : Icons.check, size: 19),
            label: Text(
              _modification ? 'Enregistrer' : 'Ajouter la charge',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  /// « 1 250,50 » comme « 1250.5 » : le clavier donne l'une ou l'autre.
  double? _lireMontant(String? texte) =>
      double.tryParse((texte ?? '').trim().replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _valider() async {
    if (_famille == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Choisissez la famille de cette charge'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!(_formulaire.currentState?.validate() ?? false)) return;

    final montant = _lireMontant(_montant.text) ?? 0;

    // Une charge réglée sort de la caisse : on s'assure qu'elle peut la
    // couvrir avant d'envoyer, plutôt que de laisser le serveur refuser.
    if (_payee && (!_modification || widget.charge?.status == 'pending')) {
      final possible = await garantirCaisseOuverte(
        context,
        motif: 'cette charge fixe',
        sortie: montant,
      );
      if (!possible) return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(ResultatChargeFixe(
      SaisieChargeFixe(
        nom: _nom.text.trim(),
        description: _description.text.trim(),
        montant: montant,
        categorie: _famille!,
        categorieLibelle: _demandeUnNom ? _libelleLibre.text.trim() : null,
        bienId: _bienId,
        payee: _payee,
        mensuelle: !_modification && _mensuelle,
        jour: _jour,
      ),
      document: _document,
    ));
  }
}

/// La feuille d'une échéance mensuelle : son montant et son jour.
class FeuilleEcheance extends StatefulWidget {
  final RecurrenceCharge echeance;

  const FeuilleEcheance({super.key, required this.echeance});

  static Future<Map<String, dynamic>?> ouvrir(
      BuildContext context, RecurrenceCharge echeance) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeuilleEcheance(echeance: echeance),
    );
  }

  @override
  State<FeuilleEcheance> createState() => _FeuilleEcheanceState();
}

class _FeuilleEcheanceState extends State<FeuilleEcheance> {
  late final TextEditingController _montant = TextEditingController(
      text: widget.echeance.montant == widget.echeance.montant.roundToDouble()
          ? widget.echeance.montant.round().toString()
          : widget.echeance.montant.toString());
  late int _jour = widget.echeance.jour.clamp(1, 28);

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7DEE3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.echeance.nom,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: couleurTexteActivite),
            ),
            const SizedBox(height: 2),
            Text(
              widget.echeance.categorieLibelle,
              style: const TextStyle(fontSize: 12, color: couleurGrisActivite),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _montant,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Montant mensuel (MAD)',
                prefixIcon: const Icon(Icons.payments_outlined, size: 19),
                filled: true,
                fillColor: couleurFondActivite,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: couleurBordureActivite),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Le',
                    style: TextStyle(fontSize: 13, color: couleurGrisActivite)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: couleurFondActivite,
                    border: Border.all(color: couleurBordureActivite),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _jour,
                      items: [
                        for (var j = 1; j <= 28; j++)
                          DropdownMenuItem(value: j, child: Text('$j'))
                      ],
                      onChanged: (v) => setState(() => _jour = v ?? _jour),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('de chaque mois',
                      style: TextStyle(fontSize: 12.5, color: couleurGrisActivite)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: couleurBordureActivite),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(color: couleurGrisActivite)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final montant = double.tryParse(
                          _montant.text.trim().replaceAll(',', '.'));
                      if (montant == null || montant <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Montant invalide'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.of(context)
                          .pop({'montant': montant, 'jour': _jour});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enregistrer',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
