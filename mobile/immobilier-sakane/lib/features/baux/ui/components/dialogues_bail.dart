import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/baux/ui/components/occupants_bail.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bail.dart';

typedef ChoixProlongation = ({int mois, double? loyer, bool envoyerContrat});
typedef ChoixModification = ({
  double? loyer,
  double? charges,
  String? remarques,
  bool? relances,
  bool depotRecu,
  // Null : occupants inchanges.
  List<Colocataire>? colocataires,
  List<File> cinPhotos,
});
typedef ChoixFin = ({DateTime date, String? motif, double? depotRendu, String? eau, String? elec});
typedef ChoixEncaissement = ({
  double montant,
  DateTime date,
  String mode,
  String? reference,
  String? remarque,
  bool envoyerQuittance,
});

const _formatMontant = TextInputType.numberWithOptions(decimal: true);
final _filtreMontant = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

class _Dialogue extends StatelessWidget {
  final String titre;
  final List<Widget> contenu;
  final String action;
  final Color couleur;
  final VoidCallback? onValider;

  const _Dialogue({
    required this.titre,
    required this.contenu,
    required this.action,
    this.couleur = CouleursBail.teinte,
    required this.onValider,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: contenu,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: onValider,
          style: ElevatedButton.styleFrom(backgroundColor: couleur, foregroundColor: Colors.white),
          child: Text(action),
        ),
      ],
    );
  }
}

Widget _note(String texte, {Color couleur = CouleursBail.texteDoux, IconData? icone}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: couleur.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone ?? Icons.info_outline, size: 16, color: couleur),
        const SizedBox(width: 8),
        Expanded(child: Text(texte, style: TextStyle(fontSize: 12.5, color: couleur, height: 1.35))),
      ],
    ),
  );
}

Widget _champDate(BuildContext context, String label, DateTime valeur, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: decorationBail(label, icone: Icons.event),
      child: Text(dateLongue(valeur), style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

// ── Prolonger ──────────────────────────────────────────────────────

Future<ChoixProlongation?> demanderProlongation(BuildContext context, Bail bail) {
  return showDialog<ChoixProlongation>(context: context, builder: (_) => _Prolonger(bail: bail));
}

class _Prolonger extends StatefulWidget {
  final Bail bail;

  const _Prolonger({required this.bail});

  @override
  State<_Prolonger> createState() => _ProlongerState();
}

class _ProlongerState extends State<_Prolonger> {
  final _mois = TextEditingController(text: '12');
  final _loyer = TextEditingController();
  bool _envoyer = true;

  @override
  void dispose() {
    _mois.dispose();
    _loyer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mois = int.tryParse(_mois.text.trim());
    final valide = mois != null && mois >= 1 && mois <= 120;
    final loyer = lireMontant(_loyer.text);
    final loyerValide = _loyer.text.trim().isEmpty || (loyer != null && loyer > 0);
    final finActuelle = widget.bail.dateFin;
    final nouvelleFin = (valide && finActuelle != null) ? ajouterJours(ajouterMois(ajouterJours(finActuelle, 1), mois), -1) : null;
    final sansTel = (widget.bail.locataire.tel ?? '').isEmpty;
    return _Dialogue(
      titre: 'Prolonger le bail',
      action: 'Prolonger',
      onValider: valide && loyerValide
          ? () => Navigator.of(context).pop((
                mois: mois,
                loyer: _loyer.text.trim().isEmpty ? null : loyer,
                envoyerContrat: _envoyer && !sansTel,
              ))
          : null,
      contenu: [
        Text('Fin actuelle : ${dateBail(finActuelle)}', style: const TextStyle(color: CouleursBail.texteDoux)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final m in const [6, 12, 24])
              ChoiceChip(
                label: Text('$m mois'),
                selected: mois == m,
                showCheckmark: false,
                selectedColor: CouleursBail.fondTeinte,
                onSelected: (_) => setState(() => _mois.text = '$m'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mois,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: decorationBail('Nombre de mois', suffixe: 'mois'),
        ),
        if (nouvelleFin != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Nouvelle fin : ${dateLongue(nouvelleFin)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.teinte)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _loyer,
          keyboardType: _formatMontant,
          inputFormatters: [_filtreMontant],
          onChanged: (_) => setState(() {}),
          decoration: decorationBail('Nouveau loyer (facultatif)',
              suffixe: 'MAD', aide: 'Actuel : ${montantLisible(widget.bail.loyer)}. Vide : inchangé.'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _envoyer && !sansTel,
          activeThumbColor: CouleursBail.teinte,
          onChanged: sansTel ? null : (v) => setState(() => _envoyer = v),
          title: const Text('Envoyer le contrat par WhatsApp', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

// ── Modifier ───────────────────────────────────────────────────────

Future<ChoixModification?> demanderModification(BuildContext context, Bail bail) {
  return showDialog<ChoixModification>(context: context, builder: (_) => _Modifier(bail: bail));
}

class _Modifier extends StatefulWidget {
  final Bail bail;

  const _Modifier({required this.bail});

  @override
  State<_Modifier> createState() => _ModifierState();
}

class _ModifierState extends State<_Modifier> {
  late final _loyer = TextEditingController(text: prixSimple(widget.bail.loyer));
  late final _charges = TextEditingController(text: prixSimple(widget.bail.charges));
  late final _remarques = TextEditingController(text: widget.bail.remarques ?? '');
  late bool _relances = widget.bail.relancesActives;
  bool _depotRecu = false;
  late final List<LigneOccupant> _occupants = widget.bail.colocataires.map(LigneOccupant.new).toList();
  final List<File> _photosCin = [];

  @override
  void dispose() {
    _loyer.dispose();
    _charges.dispose();
    _remarques.dispose();
    for (final l in _occupants) {
      l.dispose();
    }
    super.dispose();
  }

  /// Null si la liste saisie est celle du bail.
  List<Colocataire>? get _occupantsModifies {
    final saisis = occupantsSaisis(_occupants);
    String cle(List<Colocataire> liste) => liste.map((c) => c.toJson().toString()).join('|');
    return cle(saisis) == cle(widget.bail.colocataires) ? null : saisis;
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bail;
    final loyer = lireMontant(_loyer.text);
    final charges = _charges.text.trim().isEmpty ? 0.0 : lireMontant(_charges.text);
    final valide = loyer != null && loyer > 0 && charges != null && charges >= 0;
    final loyerChange = valide && (loyer - b.loyer).abs() > 0.004;
    final chargesChange = valide && (charges - b.charges).abs() > 0.004;
    final peutRecevoirDepot = b.depotStatut == 'non_recu' && b.depot > 0 && b.actif;
    final sansNom = _occupants.any((l) => !l.vide && l.nom.text.trim().isEmpty);
    return _Dialogue(
      titre: 'Modifier le bail',
      action: 'Enregistrer',
      onValider: valide && !sansNom
          ? () {
              final remarques = _remarques.text.trim();
              Navigator.of(context).pop((
                loyer: loyerChange ? loyer : null,
                charges: chargesChange ? charges : null,
                remarques: remarques == (b.remarques ?? '') ? null : remarques,
                relances: _relances == b.relancesActives ? null : _relances,
                depotRecu: _depotRecu && peutRecevoirDepot,
                colocataires: _occupantsModifies,
                cinPhotos: List<File>.of(_photosCin),
              ));
            }
          : null,
      contenu: [
        TextField(
          controller: _loyer,
          keyboardType: _formatMontant,
          inputFormatters: [_filtreMontant],
          onChanged: (_) => setState(() {}),
          decoration: decorationBail('Loyer mensuel', suffixe: 'MAD'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _charges,
          keyboardType: _formatMontant,
          inputFormatters: [_filtreMontant],
          onChanged: (_) => setState(() {}),
          decoration: decorationBail('Charges mensuelles', suffixe: 'MAD'),
        ),
        if (loyerChange || chargesChange) ...[
          const SizedBox(height: 8),
          _note('Le nouveau montant s\'applique aux mois à venir non encore payés.',
              couleur: CouleursBail.partiel),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _remarques,
          minLines: 2,
          maxLines: 4,
          decoration: decorationBail('Remarques'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _relances,
          activeThumbColor: CouleursBail.teinte,
          onChanged: (v) => setState(() => _relances = v),
          title: const Text('Relances automatiques', style: TextStyle(fontSize: 14)),
        ),
        if (peutRecevoirDepot)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _depotRecu,
            activeThumbColor: CouleursBail.teinte,
            onChanged: (v) => setState(() => _depotRecu = v),
            title: Text('Dépôt de ${montantLisible(b.depot)} reçu maintenant', style: const TextStyle(fontSize: 14)),
            subtitle: const Text('Le montant entre dans votre caisse.', style: TextStyle(fontSize: 12)),
          ),
        const Divider(height: 24),
        const Text('Autres occupants', style: TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.maxFinite,
          child: EditeurOccupants(lignes: _occupants, onChange: () => setState(() {})),
        ),
        if (sansNom) ...[
          const SizedBox(height: 8),
          _note('Indiquez le nom de chaque occupant, ou retirez la ligne.', couleur: CouleursBail.retard),
        ],
        const Divider(height: 24),
        Text('Ajouter des photos de CIN (${_photosCin.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
        const SizedBox(height: 2),
        Text(
          b.cinPhotos.isEmpty
              ? 'Locataire et autres occupants, recto et verso.'
              : '${pluriel(b.cinPhotos.length, 'photo')} déjà enregistrée${b.cinPhotos.length > 1 ? 's' : ''} ; '
                  'les nouvelles s\'ajoutent.',
          style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux),
        ),
        const SizedBox(height: 8),
        // Largeur fixe : la boite de dialogue mesure son contenu, une liste defilante ne le permet pas.
        SizedBox(
          width: double.maxFinite,
          child: SelecteurPhotosBail(photos: _photosCin, onChange: () => setState(() {})),
        ),
      ],
    );
  }
}

// ── Terminer ───────────────────────────────────────────────────────

/// Le solde de la caisse est verifie ici quand un depot est rendu.
Future<ChoixFin?> demanderFinBail(BuildContext context, Bail bail) async {
  final choix = await showDialog<ChoixFin>(context: context, builder: (_) => _Terminer(bail: bail));
  if (choix == null || !context.mounted) return null;
  final rendu = choix.depotRendu ?? 0;
  if (rendu > 0) {
    final prete = await garantirCaisseOuverte(context, motif: 'la restitution du dépôt', sortie: rendu);
    if (!prete) return null;
  }
  return choix;
}

class _Terminer extends StatefulWidget {
  final Bail bail;

  const _Terminer({required this.bail});

  @override
  State<_Terminer> createState() => _TerminerState();
}

class _TerminerState extends State<_Terminer> {
  DateTime _date = aujourdhui();
  final _motif = TextEditingController();
  late final _rendu = TextEditingController(text: _depotEncaisse ? prixSimple(widget.bail.depot) : '');
  final _eau = TextEditingController();
  final _elec = TextEditingController();

  bool get _depotEncaisse => widget.bail.depotStatut == 'recu' && widget.bail.depot > 0;

  @override
  void dispose() {
    for (final c in [_motif, _rendu, _eau, _elec]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final debut = widget.bail.dateDebut ?? DateTime(2000);
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(debut) ? debut : _date,
      firstDate: debut,
      lastDate: ajouterJours(aujourdhui(), 366),
      helpText: 'Date de sortie',
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bail;
    final rendu = _rendu.text.trim().isEmpty ? 0.0 : lireMontant(_rendu.text);
    final renduValide = !_depotEncaisse || (rendu != null && rendu >= 0 && rendu <= b.depot + 0.004);
    final garde = _depotEncaisse && rendu != null ? (b.depot - rendu).clamp(0.0, b.depot).toDouble() : 0.0;
    return _Dialogue(
      titre: 'Terminer le bail',
      action: 'Terminer',
      couleur: CouleursBail.retard,
      onValider: renduValide
          ? () => Navigator.of(context).pop((
                date: _date,
                motif: _motif.text.trim().isEmpty ? null : _motif.text.trim(),
                depotRendu: _depotEncaisse ? rendu : null,
                eau: _eau.text.trim().isEmpty ? null : _eau.text.trim(),
                elec: _elec.text.trim().isEmpty ? null : _elec.text.trim(),
              ))
          : null,
      contenu: [
        _champDate(context, 'Date de sortie', _date, _choisirDate),
        const SizedBox(height: 10),
        TextField(controller: _motif, decoration: decorationBail('Motif (facultatif)')),
        const SizedBox(height: 12),
        if (_depotEncaisse) ...[
          TextField(
            controller: _rendu,
            keyboardType: _formatMontant,
            inputFormatters: [_filtreMontant],
            onChanged: (_) => setState(() {}),
            decoration: decorationBail('Dépôt rendu au locataire',
                suffixe: 'MAD',
                aide: 'Dépôt reçu : ${montantLisible(b.depot)}',
                icone: Icons.savings_outlined),
          ),
          const SizedBox(height: 8),
          if (!renduValide)
            _note('Le montant rendu ne peut pas dépasser le dépôt.', couleur: CouleursBail.retard)
          else ...[
            _note(
              garde > 0.004
                  ? 'Le montant rendu sort de votre caisse. Les ${montantLisible(garde)} restants sont conservés '
                      'et comptés comme revenu (réparations, impayés…).'
                  : 'Le montant rendu sort de votre caisse.',
              couleur: CouleursBail.aPayer,
            ),
            const SizedBox(height: 6),
            _note('Votre caisse doit contenir le montant rendu : sinon l\'opération est refusée.',
                couleur: CouleursBail.partiel, icone: Icons.account_balance_wallet_outlined),
          ],
          const SizedBox(height: 12),
        ] else if (b.depot > 0) ...[
          _note(b.depotStatut == 'restitue' ? 'Le dépôt a déjà été restitué.' : 'Le dépôt n\'a pas été encaissé : rien à rendre.'),
          const SizedBox(height: 12),
        ],
        if (b.resume.resteDu > 0.004) ...[
          _note('Il reste ${montantLisible(b.resume.resteDu)} de loyers impayés sur ce bail.',
              couleur: CouleursBail.retard, icone: Icons.warning_amber_rounded),
          const SizedBox(height: 12),
        ],
        const Text('Relevés de sortie', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: _eau, decoration: decorationBail('Eau', aide: 'Entrée : ${b.compteurEauEntree ?? '—'}'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: _elec, decoration: decorationBail('Électricité', aide: 'Entrée : ${b.compteurElecEntree ?? '—'}'))),
          ],
        ),
      ],
    );
  }
}

// ── Encaisser ──────────────────────────────────────────────────────

Future<ChoixEncaissement?> demanderEncaissement(BuildContext context, Loyer loyer, {bool telDisponible = true}) {
  return showDialog<ChoixEncaissement>(
    context: context,
    builder: (_) => _Encaisser(loyer: loyer, telDisponible: telDisponible),
  );
}

class _Encaisser extends StatefulWidget {
  final Loyer loyer;
  final bool telDisponible;

  const _Encaisser({required this.loyer, required this.telDisponible});

  @override
  State<_Encaisser> createState() => _EncaisserState();
}

class _EncaisserState extends State<_Encaisser> {
  late final _montant = TextEditingController(text: prixSimple(widget.loyer.reste));
  final _reference = TextEditingController();
  final _remarque = TextEditingController();
  DateTime _date = aujourdhui();
  String _mode = 'especes';
  bool _envoyer = true;

  @override
  void dispose() {
    _montant.dispose();
    _reference.dispose();
    _remarque.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(aujourdhui().year - 3),
      lastDate: aujourdhui(),
      helpText: 'Date du paiement',
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loyer;
    final montant = lireMontant(_montant.text);
    final valide = montant != null && montant > 0 && montant <= l.reste + 0.004;
    return _Dialogue(
      titre: 'Encaisser ${l.libelle}',
      action: 'Encaisser',
      couleur: CouleursBail.paye,
      onValider: valide
          ? () => Navigator.of(context).pop((
                montant: montant,
                date: _date,
                mode: _mode,
                reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
                remarque: _remarque.text.trim().isEmpty ? null : _remarque.text.trim(),
                envoyerQuittance: _envoyer && widget.telDisponible,
              ))
          : null,
      contenu: [
        Text('Reste à payer : ${montantLisible(l.reste)}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
        const SizedBox(height: 12),
        TextField(
          controller: _montant,
          autofocus: true,
          keyboardType: _formatMontant,
          inputFormatters: [_filtreMontant],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          decoration: decorationBail('Montant', suffixe: 'MAD'),
        ),
        if (montant != null && montant > l.reste + 0.004)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Le montant dépasse le reste à payer.', style: TextStyle(color: CouleursBail.retard, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        _champDate(context, 'Payé le', _date, _choisirDate),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final m in const ['especes', 'virement', 'cheque'])
              ChoiceChip(
                label: Text(libelleModePaiement(m)),
                selected: _mode == m,
                showCheckmark: false,
                selectedColor: CouleursBail.fondTeinte,
                onSelected: (_) => setState(() => _mode = m),
              ),
          ],
        ),
        if (_mode == 'especes')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _note('Le montant entre dans votre caisse.'),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _reference,
          decoration: decorationBail(_mode == 'cheque' ? 'N° de chèque' : 'Référence (facultatif)'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _remarque, decoration: decorationBail('Remarque (facultatif)')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _envoyer && widget.telDisponible,
          activeThumbColor: CouleursBail.teinte,
          onChanged: widget.telDisponible ? (v) => setState(() => _envoyer = v) : null,
          title: const Text('Envoyer la quittance par WhatsApp', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}

// ── Montant d'une echeance ─────────────────────────────────────────

Future<double?> demanderMontantEcheance(BuildContext context, Loyer loyer) {
  return showDialog<double>(context: context, builder: (_) => _Montant(loyer: loyer));
}

class _Montant extends StatefulWidget {
  final Loyer loyer;

  const _Montant({required this.loyer});

  @override
  State<_Montant> createState() => _MontantState();
}

class _MontantState extends State<_Montant> {
  late final _montant = TextEditingController(text: prixSimple(widget.loyer.montant));

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.loyer;
    final montant = lireMontant(_montant.text);
    final valide = montant != null && montant >= 0 && montant + 0.004 >= l.paye;
    return _Dialogue(
      titre: 'Montant de ${l.libelle}',
      action: 'Enregistrer',
      onValider: valide ? () => Navigator.of(context).pop(montant) : null,
      contenu: [
        _note('Remise, prorata d\'un mois incomplet… Le montant ne peut pas être inférieur à ce qui est déjà payé '
            '(${montantLisible(l.paye)}).'),
        const SizedBox(height: 12),
        TextField(
          controller: _montant,
          autofocus: true,
          keyboardType: _formatMontant,
          inputFormatters: [_filtreMontant],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          decoration: decorationBail('Montant de l\'échéance', suffixe: 'MAD'),
        ),
        if (montant != null && montant + 0.004 < l.paye)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Inférieur au montant déjà payé.', style: TextStyle(color: CouleursBail.retard, fontSize: 12)),
          ),
      ],
    );
  }
}

// ── Annuler un paiement ────────────────────────────────────────────

/// Rend le motif (eventuellement vide), ou null si l'utilisateur renonce.
Future<String?> demanderAnnulationPaiement(BuildContext context, PaiementLoyer p) {
  return showDialog<String>(context: context, builder: (_) => _Annuler(paiement: p));
}

class _Annuler extends StatefulWidget {
  final PaiementLoyer paiement;

  const _Annuler({required this.paiement});

  @override
  State<_Annuler> createState() => _AnnulerState();
}

class _AnnulerState extends State<_Annuler> {
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paiement;
    return _Dialogue(
      titre: 'Annuler ce paiement ?',
      action: 'Annuler le paiement',
      couleur: CouleursBail.retard,
      onValider: () => Navigator.of(context).pop(_motif.text.trim()),
      contenu: [
        Text('${montantLisible(p.montant)} du ${dateBail(p.payeLe)} (${p.libelleMode}).',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _note('Le montant est retiré de la caisse et des statistiques.',
            couleur: CouleursBail.partiel),
        const SizedBox(height: 12),
        TextField(controller: _motif, decoration: decorationBail('Motif (facultatif)')),
      ],
    );
  }
}
