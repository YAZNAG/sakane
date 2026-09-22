import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/baux/ui/components/choix_locataire.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/cubit/dossier_vente_cubit.dart';
import 'package:immobilier/features/ventes/ui/components/mandat_outils.dart';
import 'package:immobilier/features/ventes/ui/components/visite_outils.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/client.dart';
import 'package:immobilier/models/owner.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

String _jour(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _nombre(double? v) => v == null || v <= 0 ? '' : prixSimple(v);

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Ouvre un formulaire plein ecran ; rend vrai une fois enregistre.
Future<bool> _ouvrir(BuildContext context, Widget page) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
  return ok == true;
}

/// Le squelette commun : titre, champs, bouton d'enregistrement.
class _Squelette extends StatelessWidget {
  final String titre;
  final GlobalKey<FormState> formulaire;
  final List<Widget> champs;
  final bool enCours;
  final String action;
  final VoidCallback onValider;
  final IconData icone;

  /// Action secondaire sous le bouton principal.
  final Widget? secondaire;

  const _Squelette({
    required this.titre,
    required this.formulaire,
    required this.champs,
    required this.enCours,
    required this.action,
    required this.onValider,
    this.icone = Icons.check,
    this.secondaire,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursBail.fond,
      appBar: AppBar(
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: CouleursVente.teinte,
      ),
      body: Form(
        key: formulaire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            ...champs,
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: enCours ? null : onValider,
                icon: enCours
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(icone),
                label: Text(action, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CouleursVente.teinte,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: CouleursVente.teinte.withValues(alpha: .6),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (secondaire != null) ...[const SizedBox(height: 6), secondaire!],
          ],
        ),
      ),
    );
  }
}

Widget _sousTitre(String texte, IconData icone) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
      child: Row(
        children: [
          Icon(icone, size: 18, color: CouleursVente.teinte),
          const SizedBox(width: 8),
          Text(texte, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
        ],
      ),
    );

Widget _espace() => const SizedBox(height: 12);

/// Champ de date au style du module.
class _ChampDate extends StatelessWidget {
  final String label;
  final DateTime valeur;
  final ValueChanged<DateTime> onChange;

  const _ChampDate({required this.label, required this.valeur, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: valeur,
          firstDate: DateTime(aujourdhui().year - 3),
          lastDate: DateTime(aujourdhui().year + 3),
          helpText: label,
        );
        if (d != null) onChange(CalendrierBien.jour(d));
      },
      child: InputDecorator(
        decoration: decorationBail(label, icone: Icons.event_outlined),
        child: Text(dateMoyenne(valeur), style: const TextStyle(fontSize: 14.5)),
      ),
    );
  }
}

// ── Mandat de vente ────────────────────────────────────────────────

/// Nouveau mandat de vente (عقد وساطة عقارية) depuis le dossier d'un bien,
/// pre-rempli depuis le dossier. Rend le mandat enregistre, ou null.
Future<MandatVente?> ouvrirFormulaireMandat(BuildContext context, DossierVente dossier, DossierVenteCubit cubit) {
  final b = dossier.bien;
  return ouvrirFormulaireMandatVente(
    context,
    titreBien: b.titre,
    types: dossier.types,
    typePropose: dossier.typeBienPropose,
    proprietaire: b.proprietaire,
    surface: b.surface,
    prix: b.prix,
    adresse: b.adresse,
    enregistrer: (champs) async {
      final m = await Dependencies.get<Repository>().creerMandatVente(b.id, champs);
      await cubit.charger(silencieux: true);
      return m;
    },
  );
}

/// Formulaire du mandat : saisie, puis verification des donnees avant
/// l'enregistrement. [initial] : mandat a modifier (tant qu'il n'est pas signe).
Future<MandatVente?> ouvrirFormulaireMandatVente(
  BuildContext context, {
  required Future<MandatVente> Function(Map<String, dynamic> champs) enregistrer,
  MandatVente? initial,
  Map<String, String> types = const {},
  String? typePropose,
  String? titreBien,
  ProprietaireVente? proprietaire,
  double? surface,
  double? prix,
  String? adresse,
}) {
  return Navigator.of(context).push<MandatVente>(MaterialPageRoute(
    builder: (_) => _FormulaireMandat(
      enregistrer: enregistrer,
      initial: initial,
      types: types,
      typePropose: typePropose,
      titreBien: titreBien,
      proprietaire: proprietaire,
      surface: surface,
      prix: prix,
      adresse: adresse,
    ),
  ));
}

class _FormulaireMandat extends StatefulWidget {
  final Future<MandatVente> Function(Map<String, dynamic> champs) enregistrer;
  final MandatVente? initial;
  final Map<String, String> types;
  final String? typePropose;
  final String? titreBien;
  final ProprietaireVente? proprietaire;
  final double? surface;
  final double? prix;
  final String? adresse;

  const _FormulaireMandat({
    required this.enregistrer,
    this.initial,
    this.types = const {},
    this.typePropose,
    this.titreBien,
    this.proprietaire,
    this.surface,
    this.prix,
    this.adresse,
  });

  @override
  State<_FormulaireMandat> createState() => _FormulaireMandatState();
}

class _FormulaireMandatState extends State<_FormulaireMandat> {
  final _formulaire = GlobalKey<FormState>();
  late final MandatVente? _m = widget.initial;
  late final _nom = TextEditingController(text: _m?.proprietaireNom ?? widget.proprietaire?.nom ?? '');
  late final _tel = TextEditingController(text: _m?.proprietaireTel ?? widget.proprietaire?.tel ?? '');
  late final _cin = TextEditingController(text: _m?.proprietaireCin ?? '');
  late final _nationalite = TextEditingController(text: _m?.proprietaireNationalite ?? '');
  late final _adresse = TextEditingController(text: _m?.proprietaireAdresse ?? '');
  late final _ville = TextEditingController(text: _m?.ville ?? 'Agadir');
  late final _surface = TextEditingController(text: _nombre(_m?.surface ?? widget.surface));
  late final _titreFoncier = TextEditingController(text: _m?.titreFoncier ?? '');
  late final _adresseBien = TextEditingController(text: _m?.adresseBien ?? widget.adresse ?? '');
  late final _prix = TextEditingController(text: _nombre(_m?.prixDemande ?? widget.prix));
  late final _commission =
      TextEditingController(text: _m?.commission == null ? '2,5' : pourcentage(_m!.commission).replaceAll(' %', ''));
  late final _duree = TextEditingController(text: '${_m?.dureeMois ?? 12}');
  late final _remarques = TextEditingController(text: _m?.remarques ?? '');
  late DateTime _signature = _m?.dateSignature ?? aujourdhui();
  String? _type;

  /// Proprietaire existant (fiche owner) ; null : nouveau proprietaire.
  Owner? _owner;

  /// Deuxieme temps : les donnees relues avant l'enregistrement.
  bool _verification = false;
  bool _enCours = false;

  /// Valeurs arabes proposees ; le libelle francais sert d'affichage.
  late final Map<String, String> _types;

  @override
  void initState() {
    super.initState();
    _types = _typesDisponibles();
    final ownerId = _m?.ownerId ?? widget.proprietaire?.id;
    if (ownerId != null) {
      _owner = Owner(
        id: ownerId,
        name: _m?.proprietaireNom ?? widget.proprietaire?.nom,
        tel: _m?.proprietaireTel ?? widget.proprietaire?.tel,
      );
    }
  }

  Map<String, String> _typesDisponibles() {
    final source = widget.types.isNotEmpty ? widget.types : typesBienParDefaut;
    final types = <String, String>{for (final e in source.entries) e.value: e.key};
    final propose = _m?.typeBien ?? widget.typePropose;
    if (propose != null) {
      final arabe = source[propose] ?? propose;
      types.putIfAbsent(arabe, () => arabe);
      _type = arabe;
    }
    return types;
  }

  @override
  void dispose() {
    for (final c in [
      _nom, _tel, _cin, _nationalite, _adresse, _ville, _surface, _titreFoncier,
      _adresseBien, _prix, _commission, _duree, _remarques,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _texte(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  String get _nomProprietaire => _owner != null ? (_owner!.name ?? '').trim() : _nom.text.trim();

  Map<String, dynamic> _champs() => {
        if (_owner?.id != null) 'owner': _owner!.id,
        if (_nomProprietaire.isNotEmpty) 'proprietaireNom': _nomProprietaire,
        if (_texte(_cin) != null) 'proprietaireCin': _texte(_cin),
        if (_texte(_nationalite) != null) 'proprietaireNationalite': _texte(_nationalite),
        if (_texte(_adresse) != null) 'proprietaireAdresse': _texte(_adresse),
        if (_texte(_tel) != null) 'proprietaireTel': _texte(_tel),
        if (_type != null) 'typeBien': _type,
        if (_texte(_ville) != null) 'ville': _texte(_ville),
        if (lireMontant(_surface.text) != null) 'surface': lireMontant(_surface.text),
        if (_texte(_titreFoncier) != null) 'titreFoncier': _texte(_titreFoncier),
        if (_texte(_adresseBien) != null) 'adresseBien': _texte(_adresseBien),
        if (lireMontant(_prix.text) != null) 'prixDemande': lireMontant(_prix.text),
        'commission': lireMontant(_commission.text) ?? 2.5,
        'dureeMois': int.tryParse(_duree.text.trim()) ?? 12,
        'dateSignature': _jour(_signature),
        if (_texte(_remarques) != null) 'remarques': _texte(_remarques),
      };

  Future<void> _choisirOwner() async {
    final o = await choisirProprietaire(context);
    if (!mounted) return;
    setState(() {
      _owner = o;
      if (o != null) {
        if ((o.tel ?? '').isNotEmpty) _tel.text = o.tel!;
        if ((o.address ?? '').isNotEmpty && _adresse.text.trim().isEmpty) _adresse.text = o.address!;
      }
    });
  }

  void _verifier() {
    if (!_formulaire.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _verification = true);
  }

  Future<void> _valider() async {
    setState(() => _enCours = true);
    try {
      final m = await widget.enregistrer(_champs());
      if (!mounted) return;
      Navigator.of(context).pop(m);
    } catch (ex) {
      if (!mounted) return;
      setState(() => _enCours = false);
      afficherMessage(context, messageErreurBail(ex), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titre = widget.initial != null ? 'Modifier le mandat' : 'Nouveau mandat de vente';
    return PopScope(
      canPop: !_verification,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte && _verification) setState(() => _verification = false);
      },
      child: _verification
          ? _Squelette(
              titre: titre,
              formulaire: _formulaire,
              enCours: _enCours,
              action: widget.initial != null ? 'Confirmer et enregistrer' : 'Confirmer et créer le mandat',
              onValider: _valider,
              secondaire: TextButton.icon(
                onPressed: _enCours ? null : () => setState(() => _verification = false),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier les données'),
                style: TextButton.styleFrom(foregroundColor: CouleursVente.teinte, minimumSize: const Size.fromHeight(48)),
              ),
              champs: _recapitulatif(),
            )
          : _Squelette(
              titre: titre,
              formulaire: _formulaire,
              enCours: false,
              action: 'Vérifier les données',
              icone: Icons.fact_check_outlined,
              onValider: _verifier,
              champs: _saisie(),
            ),
    );
  }

  Widget _etapes() {
    Widget pas(int n, String texte, bool actif, bool fait) => Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: fait ? CouleursVente.aVendre : (actif ? CouleursVente.teinte : CouleursBail.bordure),
                child: fait
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('$n',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: actif ? Colors.white : CouleursBail.texteDoux)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(texte,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: actif ? FontWeight.w800 : FontWeight.w500,
                        color: actif ? CouleursBail.texte : CouleursBail.texteDoux)),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          pas(1, 'Saisie', !_verification, _verification),
          pas(2, 'Vérification', _verification, false),
          pas(3, 'Signature', false, false),
        ],
      ),
    );
  }

  Widget _bandeau() {
    final bien = widget.titreBien;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: CouleursVente.fondTeinte, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: CouleursVente.teinte),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              bien == null || bien.isEmpty
                  ? 'Mandat de vente (عقد وساطة عقارية) signé par le propriétaire.'
                  : 'Mandat de vente (عقد وساطة عقارية) pour « $bien ».',
              style: const TextStyle(fontSize: 13, color: CouleursBail.texte, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Ce que le modele du contrat fixe : rien a saisir.
  Widget _partiesFixes() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CouleursBail.bordure),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: CouleursBail.texteDoux),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Informations de l'agence et conditions : fixées par le modèle",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CouleursBail.texte)),
                SizedBox(height: 4),
                Text(
                  "L'identité de l'agence et les 4 clauses du mandat sont ajoutées automatiquement au contrat.",
                  style: TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _saisie() {
    final owner = _owner;
    return [
      _etapes(),
      _bandeau(),
      _sousTitre('Propriétaire', Icons.person_outline),
      if (owner != null)
        CarteBail(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: CouleursVente.fondTeinte,
                child: Text((owner.name ?? '?').trim().isEmpty ? '?' : owner.name!.trim().characters.first.toUpperCase(),
                    style: const TextStyle(color: CouleursVente.teinte, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(owner.name ?? 'Propriétaire',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                    const Text('Propriétaire existant',
                        style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                  ],
                ),
              ),
              TextButton(onPressed: _choisirOwner, child: const Text('Changer')),
            ],
          ),
        )
      else ...[
        OutlinedButton.icon(
          onPressed: _choisirOwner,
          icon: const Icon(Icons.person_search_outlined),
          label: const Text('Choisir un propriétaire existant'),
          style: OutlinedButton.styleFrom(
            foregroundColor: CouleursVente.teinte,
            side: const BorderSide(color: CouleursVente.teinte),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('ou nouveau propriétaire :',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
        ),
        TextFormField(
          controller: _nom,
          textCapitalization: TextCapitalization.words,
          decoration: decorationBail('Nom complet *', icone: Icons.badge_outlined),
          validator: (v) => _owner == null && (v ?? '').trim().isEmpty ? 'Le nom du propriétaire est obligatoire' : null,
        ),
      ],
      _espace(),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _cin,
              textCapitalization: TextCapitalization.characters,
              decoration: decorationBail('CIN'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _nationalite, decoration: decorationBail('Nationalité'))),
        ],
      ),
      _espace(),
      TextFormField(
        controller: _tel,
        keyboardType: TextInputType.phone,
        decoration: decorationBail('Téléphone', icone: Icons.phone_outlined, aide: 'Pour envoyer le mandat par WhatsApp'),
      ),
      _espace(),
      TextFormField(controller: _adresse, decoration: decorationBail('Adresse', icone: Icons.home_outlined)),
      _sousTitre('Bien', Icons.home_work_outlined),
      DropdownButtonFormField<String>(
        initialValue: _type,
        isExpanded: true,
        decoration: decorationBail('Type de bien', icone: Icons.category_outlined),
        items: [
          for (final e in _types.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(e.key == e.value ? e.key : '${e.value} — ${e.key}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => _type = v),
      ),
      _espace(),
      Row(
        children: [
          Expanded(child: TextFormField(controller: _ville, decoration: decorationBail('Ville'))),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _surface,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimal],
              decoration: decorationBail('Surface', suffixe: 'm²'),
            ),
          ),
        ],
      ),
      _espace(),
      TextFormField(controller: _titreFoncier, decoration: decorationBail('Titre foncier', icone: Icons.description_outlined)),
      _espace(),
      TextFormField(controller: _adresseBien, decoration: decorationBail('Adresse du bien', icone: Icons.place_outlined)),
      _sousTitre('Conditions', Icons.handshake_outlined),
      TextFormField(
        controller: _prix,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_decimal],
        decoration: decorationBail('Prix demandé', suffixe: 'MAD', icone: Icons.payments_outlined),
      ),
      _espace(),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _commission,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimal],
              decoration: decorationBail('Commission', suffixe: '%'),
              validator: (v) {
                final c = lireMontant(v ?? '');
                return c == null || c < 0 || c > 100 ? 'Commission invalide' : null;
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _duree,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: decorationBail('Durée', suffixe: 'mois'),
              validator: (v) {
                final d = int.tryParse((v ?? '').trim());
                return d == null || d < 1 ? 'Durée invalide' : null;
              },
            ),
          ),
        ],
      ),
      _espace(),
      _ChampDate(label: 'Date de signature', valeur: _signature, onChange: (d) => setState(() => _signature = d)),
      _espace(),
      TextFormField(
        controller: _remarques,
        minLines: 2,
        maxLines: 5,
        decoration: decorationBail('Remarques'),
      ),
      _partiesFixes(),
    ];
  }

  List<Widget> _recapitulatif() {
    final type = _type == null ? null : (_types[_type] == _type ? _type : '$_type — ${_types[_type]}');
    final surface = lireMontant(_surface.text);
    final prix = lireMontant(_prix.text);
    return [
      _etapes(),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFE8F4EC), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Icons.fact_check_outlined, color: CouleursVente.aVendre),
            SizedBox(width: 10),
            Expanded(
              child: Text('Relisez les données avec le propriétaire avant de créer le mandat.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CouleursBail.texte)),
            ),
          ],
        ),
      ),
      _sousTitre('Propriétaire', Icons.person_outline),
      _Recap(lignes: {
        'Nom': _nomProprietaire,
        if (_owner != null) 'Fiche': 'Propriétaire existant',
        'CIN': _cin.text.trim(),
        'Nationalité': _nationalite.text.trim(),
        'Téléphone': _tel.text.trim(),
        'Adresse': _adresse.text.trim(),
      }),
      _sousTitre('Bien', Icons.home_work_outlined),
      _Recap(lignes: {
        'Type': type ?? '',
        'Ville': _ville.text.trim(),
        'Surface': surface == null ? '' : '${prixSimple(surface)} m²',
        'Titre foncier': _titreFoncier.text.trim(),
        'Adresse': _adresseBien.text.trim(),
      }),
      _sousTitre('Conditions', Icons.handshake_outlined),
      _Recap(lignes: {
        'Prix demandé': prix == null ? '' : prixVente(prix),
        'Commission': pourcentage(lireMontant(_commission.text) ?? 2.5),
        'Durée': '${int.tryParse(_duree.text.trim()) ?? 12} mois',
        'Date de signature': dateMoyenne(_signature),
        'Remarques': _remarques.text.trim(),
      }),
      _partiesFixes(),
    ];
  }
}

/// Lignes « libelle : valeur » d'un recapitulatif ; une valeur vide s'affiche « — ».
class _Recap extends StatelessWidget {
  final Map<String, String> lignes;

  const _Recap({required this.lignes});

  @override
  Widget build(BuildContext context) {
    return CarteBail(
      child: Column(
        children: [
          for (final e in lignes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(e.key, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                  ),
                  Expanded(
                    child: Text(
                      e.value.isEmpty ? '—' : e.value,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: e.value.isEmpty ? CouleursBail.aVenir : CouleursBail.texte,
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

// ── Visite ─────────────────────────────────────────────────────────

/// Nouveau recu de visite (وصل زيارة عقار) : un client existant, ou un
/// visiteur saisi a la main ; seules les mentions du recu sont demandees
/// (la commission vient du mandat du bien, cote serveur). Une fois le recu
/// cree, le client le signe, puis l'ecran final propose de le voir ou de
/// l'envoyer. Rend vrai si un recu a ete cree.
Future<bool> ouvrirFormulaireVisite(BuildContext context, DossierVente dossier, DossierVenteCubit cubit) =>
    _ouvrir(context, _FormulaireVisite(dossier: dossier, cubit: cubit));

/// Nationalite par defaut sur le recu.
const _nationaliteParDefaut = 'مغربي';

class _FormulaireVisite extends StatefulWidget {
  final DossierVente dossier;
  final DossierVenteCubit cubit;

  const _FormulaireVisite({required this.dossier, required this.cubit});

  @override
  State<_FormulaireVisite> createState() => _FormulaireVisiteState();
}

class _FormulaireVisiteState extends State<_FormulaireVisite> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _cin = TextEditingController();
  final _nationalite = TextEditingController(text: _nationaliteParDefaut);
  final _adresse = TextEditingController();
  final _tel = TextEditingController();
  Client? _client;
  DateTime _date = aujourdhui();
  bool _enCours = false;

  /// Le recu enregistre : l'ecran passe a la signature puis au resultat.
  VisiteVente? _visite;

  @override
  void dispose() {
    for (final c in [_nom, _cin, _nationalite, _adresse, _tel]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _texte(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Pre-remplit les mentions du recu depuis la fiche du client (modifiables).
  Future<void> _choisirClient() async {
    final c = await choisirLocataire(context, titre: 'Choisir le visiteur', listeNoireBloquante: false);
    if (c == null || !mounted) return;
    setState(() {
      _client = c;
      _nom.text = '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim();
      _cin.text = c.identityNumber ?? '';
      _nationalite.text = (c.nationalite ?? '').trim().isEmpty ? _nationaliteParDefaut : c.nationalite!.trim();
      _tel.text = c.tel ?? '';
    });
  }

  void _oublierClient() => setState(() => _client = null);

  Future<void> _valider() async {
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _enCours = true);
    // Pas de commission ni de suite : le serveur prend la commission du mandat du bien.
    final champs = <String, dynamic>{
      if (_client?.id != null) 'client': _client!.id,
      'visiteurNom': _nom.text.trim(),
      if (_texte(_cin) != null) 'visiteurCin': _texte(_cin),
      if (_texte(_nationalite) != null) 'visiteurNationalite': _texte(_nationalite),
      if (_texte(_adresse) != null) 'visiteurAdresse': _texte(_adresse),
      if (_texte(_tel) != null) 'visiteurTel': _texte(_tel),
      'dateVisite': _jour(_date),
    };
    final res = await widget.cubit.creerVisite(champs);
    if (!mounted) return;
    setState(() => _enCours = false);
    if (!res.reussi || res.visite == null) {
      afficherMessage(context, res.erreur ?? "La visite n'a pas pu être enregistrée.", erreur: true);
      return;
    }
    setState(() => _visite = res.visite);
    await _signer();
  }

  /// Pave « Signature du client » ; « Signer plus tard » laisse le recu « À signer ».
  Future<void> _signer() async {
    final v = _visite;
    if (v == null) return;
    final signee = await faireSignerVisite(context, v);
    if (signee != null && mounted) {
      setState(() => _visite = signee);
      await widget.cubit.charger(silencieux: true);
    }
  }

  Future<void> _envoyer() async {
    final v = _visite!;
    if ((v.visiteurTel ?? '').isEmpty) {
      afficherMessage(context, "Le visiteur n'a pas de numéro de téléphone.", erreur: true);
      return;
    }
    final ok = await confirmer(
      context,
      titre: 'Envoyer le reçu ?',
      message: 'Le reçu de visite sera envoyé par WhatsApp à ${v.visiteurNom} (${v.visiteurTel}).',
      action: 'Envoyer',
      couleur: const Color(0xFF25A244),
    );
    if (!ok || !mounted) return;
    setState(() => _enCours = true);
    try {
      final avertissement = await Dependencies.get<Repository>().envoyerRecuVisite(v.id);
      if (!mounted) return;
      if (avertissement != null) {
        afficherAvertissement(context, 'Reçu envoyé. $avertissement');
      } else {
        afficherMessage(context, 'Reçu envoyé.');
      }
    } catch (ex) {
      if (mounted) afficherMessage(context, messageErreurBail(ex), erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visite;
    if (v != null) return _resultat(v);
    return _Squelette(
      titre: 'Nouveau reçu de visite',
      formulaire: _formulaire,
      enCours: _enCours,
      action: 'Créer le reçu',
      onValider: _valider,
      champs: [
        _sousTitre('Visiteur', Icons.person_outline),
        if (_client != null)
          CarteBail(
            child: Row(
              children: [
                const Icon(Icons.person_pin_outlined, color: CouleursVente.teinte),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Client existant : ses informations sont reprises ci-dessous.',
                      style: TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                ),
                IconButton(
                  tooltip: 'Ne plus lier au client',
                  onPressed: _oublierClient,
                  icon: const Icon(Icons.close, color: CouleursBail.texteDoux),
                ),
              ],
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: _choisirClient,
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Choisir un client existant'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CouleursVente.teinte,
              side: const BorderSide(color: CouleursVente.teinte),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('ou saisir le visiteur :',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
          ),
        ],
        if (_client != null) _espace(),
        TextFormField(
          controller: _nom,
          textCapitalization: TextCapitalization.words,
          decoration: decorationBail('Nom complet *', icone: Icons.badge_outlined),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Le nom du visiteur est obligatoire' : null,
        ),
        _espace(),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cin,
                textCapitalization: TextCapitalization.characters,
                decoration: decorationBail('CIN / passeport'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: _nationalite, decoration: decorationBail('Nationalité'))),
          ],
        ),
        _espace(),
        TextFormField(
          controller: _adresse,
          decoration: decorationBail('Adresse (القاطن)', icone: Icons.home_outlined),
        ),
        _espace(),
        TextFormField(
          controller: _tel,
          keyboardType: TextInputType.phone,
          decoration: decorationBail('Téléphone', icone: Icons.phone_outlined, aide: 'Pour envoyer le reçu par WhatsApp'),
        ),
        _sousTitre('Visite', Icons.directions_walk),
        _ChampDate(label: 'Date de la visite', valeur: _date, onChange: (d) => setState(() => _date = d)),
      ],
    );
  }

  /// Ecran final : recu cree (signe ou « À signer »), voir, envoyer, terminer.
  Widget _resultat(VisiteVente v) {
    final signe = v.signe;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: CouleursBail.fond,
        appBar: AppBar(
          title: const Text('Reçu de visite', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: CouleursVente.teinte,
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          children: [
            Icon(signe ? Icons.verified_outlined : Icons.receipt_long_outlined,
                size: 64, color: signe ? CouleursVente.aVendre : CouleursVente.sansMandat),
            const SizedBox(height: 14),
            Text(signe ? 'Reçu signé' : 'Reçu enregistré',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
            const SizedBox(height: 6),
            Text(
              signe
                  ? 'Le reçu de visite de ${v.visiteurNom} est signé par le client.'
                  : 'Le reçu est « À signer ». Le client pourra le signer plus tard depuis le dossier de vente.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: CouleursBail.texteDoux),
            ),
            const SizedBox(height: 10),
            Center(child: PastilleSignatureVisite(visite: v)),
            const SizedBox(height: 24),
            if (!signe && peutSignerVisite) ...[
              BoutonSignerVisite(onPressed: _enCours ? null : _signer),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _enCours ? null : () => voirRecuVisite(context, v),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Voir le reçu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CouleursVente.teinte,
                  side: const BorderSide(color: CouleursVente.teinte),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _enCours ? null : _envoyer,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Envoyer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25A244),
                  side: const BorderSide(color: Color(0xFF25A244)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _enCours ? null : () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CouleursVente.teinte,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Terminer', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
