import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/ui/components/mandat_outils.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

// Creation du mandat de vente (عقد وساطة عقارية) depuis la fiche d'un bien :
// tout est pre-rempli depuis le bien et son proprietaire, l'agent relit,
// corrige, montre l'apercu puis fait signer le proprietaire une seule fois.

/// Ouvre la creation du mandat du bien [bienId]. Rend le mandat cree, ou null.
Future<MandatVente?> ouvrirCreationMandat(BuildContext context, int bienId, {String? titreBien}) {
  return Navigator.of(context).push<MandatVente>(MaterialPageRoute(
    builder: (_) => CreationMandatPage(bienId: bienId, titreBien: titreBien),
  ));
}

String _jour(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _nombre(double? v) => v == null || v <= 0 ? '' : prixSimple(v);

/// Nombre envoye au serveur : point decimal, sans « .0 » inutile.
String _envoi(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

class _Etape {
  final String titre;
  final IconData icone;

  const _Etape(this.titre, this.icone);
}

const List<_Etape> _etapes = [
  _Etape('Propriétaire', Icons.person_outline),
  _Etape('Bien et conditions', Icons.home_work_outlined),
  _Etape('Aperçu', Icons.fact_check_outlined),
  _Etape('Signature', Icons.draw_outlined),
];

class CreationMandatPage extends StatefulWidget {
  final int bienId;
  final String? titreBien;

  const CreationMandatPage({super.key, required this.bienId, this.titreBien});

  @override
  State<CreationMandatPage> createState() => _CreationMandatPageState();
}

class _CreationMandatPageState extends State<CreationMandatPage> {
  final _formulaire = GlobalKey<FormState>();

  MandatPrerempli? _donnees;
  String? _erreur;

  int _etape = 0;
  bool _enCours = false;

  /// Signature du proprietaire (PNG), recueillie a la derniere etape.
  Uint8List? _signature;

  /// Le mandat une fois cree : l'ecran de fin remplace les etapes.
  MandatVente? _cree;

  final _nom = TextEditingController();
  final _cin = TextEditingController();
  final _nationalite = TextEditingController();
  final _adresse = TextEditingController();
  final _tel = TextEditingController();
  final _ville = TextEditingController();
  final _surface = TextEditingController();
  final _titreFoncier = TextEditingController();
  final _adresseBien = TextEditingController();
  final _prix = TextEditingController();
  final _commission = TextEditingController();
  final _duree = TextEditingController();
  final _remarques = TextEditingController();
  DateTime _dateSignature = aujourdhui();

  /// Valeur arabe -> libelle francais.
  Map<String, String> _types = const {};
  String? _type;

  Repository get _depot => Dependencies.get<Repository>();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in [
      _nom, _cin, _nationalite, _adresse, _tel, _ville, _surface, _titreFoncier,
      _adresseBien, _prix, _commission, _duree, _remarques,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final d = await _depot.fetchMandatPrerempli(widget.bienId);
      if (!mounted) return;
      _remplir(d);
      setState(() => _donnees = d);
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreurBail(ex));
    }
  }

  void _remplir(MandatPrerempli d) {
    _nom.text = d.proprietaireNom;
    _cin.text = d.proprietaireCin ?? '';
    _nationalite.text = d.proprietaireNationalite ?? '';
    _adresse.text = d.proprietaireAdresse ?? '';
    _tel.text = d.proprietaireTel ?? '';
    _ville.text = d.ville ?? '';
    _surface.text = _nombre(d.surface);
    _titreFoncier.text = d.titreFoncier ?? '';
    _adresseBien.text = d.adresseBien ?? '';
    _prix.text = _nombre(d.prixDemande);
    _commission.text = pourcentage(d.commission).replaceAll(' %', '');
    _duree.text = '${d.dureeMois}';
    _dateSignature = d.dateSignature ?? aujourdhui();

    final source = d.types.isNotEmpty ? d.types : typesBienParDefaut;
    final types = <String, String>{for (final e in source.entries) e.value: e.key};
    final propose = d.typeBien;
    if (propose != null && propose.isNotEmpty) {
      // Le serveur peut proposer le libelle francais ou la valeur arabe.
      final arabe = source[propose] ?? propose;
      types.putIfAbsent(arabe, () => arabe);
      _type = arabe;
    }
    _types = types;
  }

  String? _texte(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, dynamic> _champs() {
    final surface = lireMontant(_surface.text);
    final prix = lireMontant(_prix.text);
    return {
      if (_donnees?.ownerId != null) 'owner': _donnees!.ownerId,
      'proprietaireNom': _nom.text.trim(),
      'proprietaireCin': _texte(_cin),
      'proprietaireNationalite': _texte(_nationalite),
      'proprietaireAdresse': _texte(_adresse),
      'proprietaireTel': _texte(_tel),
      'typeBien': _type,
      'ville': _texte(_ville),
      if (surface != null) 'surface': _envoi(surface),
      'titreFoncier': _texte(_titreFoncier),
      'adresseBien': _texte(_adresseBien),
      if (prix != null) 'prixDemande': _envoi(prix),
      'commission': _envoi(lireMontant(_commission.text) ?? 2.5),
      'dureeMois': int.tryParse(_duree.text.trim()) ?? 12,
      'dateSignature': _jour(_dateSignature),
      'remarques': _texte(_remarques),
    };
  }

  // ── Navigation ───────────────────────────────────────────────────

  void _suivant() {
    if (_etape < 2 && !(_formulaire.currentState?.validate() ?? true)) return;
    FocusScope.of(context).unfocus();
    if (_etape < _etapes.length - 1) setState(() => _etape++);
  }

  void _precedent() {
    FocusScope.of(context).unfocus();
    if (_etape > 0) setState(() => _etape--);
  }

  void _allerA(int etape) {
    FocusScope.of(context).unfocus();
    setState(() => _etape = etape);
  }

  Future<void> _faireSigner() async {
    final png = await Navigator.of(context).push<Uint8List>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaveSignaturePage(
        titre: 'Signature du propriétaire',
        nom: _nom.text.trim(),
        mention: 'Je confirme confier la vente de mon bien à l’agence (عقد وساطة عقارية).',
      ),
    ));
    if (png != null && mounted) setState(() => _signature = png);
  }

  Future<void> _creer({required bool avecSignature}) async {
    if (avecSignature && _signature == null) {
      await _faireSigner();
      if (_signature == null || !mounted) return;
    }
    if (!avecSignature) {
      final ok = await confirmer(
        context,
        titre: 'Signer plus tard ?',
        message: 'Le mandat sera créé « À signer ». Le propriétaire pourra le signer plus tard '
            'depuis le dossier de vente du bien.',
        action: 'Créer sans signature',
        couleur: CouleursVente.teinte,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _enCours = true);
    try {
      final m = await _depot.creerMandatAvecSignature(
        widget.bienId,
        _champs(),
        signature: avecSignature ? _signature : null,
      );
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _cree = m;
      });
    } catch (ex) {
      if (!mounted) return;
      setState(() => _enCours = false);
      afficherMessage(context, messageErreurBail(ex), erreur: true);
    }
  }

  // ── Apres la creation ────────────────────────────────────────────

  Future<void> _voir(MandatVente m) => voirContratMandat(context, m, titre: m.signe ? 'Mandat signé' : 'Mandat de vente');

  Future<void> _envoyer(MandatVente m) async {
    final tel = m.proprietaireTel ?? _texte(_tel);
    if ((tel ?? '').isEmpty) {
      afficherMessage(context, "Le propriétaire n'a pas de numéro de téléphone.", erreur: true);
      return;
    }
    final nom = m.proprietaireNom.isEmpty ? _nom.text.trim() : m.proprietaireNom;
    final ok = await confirmer(
      context,
      titre: 'Envoyer le mandat ?',
      message: 'Le mandat de vente sera envoyé par WhatsApp à $nom ($tel).',
      action: 'Envoyer',
      couleur: const Color(0xFF25A244),
    );
    if (!ok || !mounted) return;
    setState(() => _enCours = true);
    try {
      final avertissement = await _depot.envoyerMandatVente(m.id);
      if (!mounted) return;
      if ((avertissement ?? '').trim().isNotEmpty) {
        afficherAvertissement(context, 'Mandat envoyé. $avertissement');
      } else {
        afficherMessage(context, 'Mandat envoyé.');
      }
    } catch (ex) {
      if (mounted) afficherMessage(context, messageErreurBail(ex), erreur: true);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _signerMaintenant(MandatVente m) async {
    final signe = await faireSignerMandat(context, m);
    if (signe != null && mounted) setState(() => _cree = signe);
  }

  // ── Affichage ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cree = _cree;
    return PopScope(
      canPop: cree != null || _etape == 0 || _donnees == null,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte && cree == null && _etape > 0) _precedent();
      },
      child: Scaffold(
        backgroundColor: CouleursBail.fond,
        appBar: AppBar(
          title: Text(cree != null ? 'Mandat créé' : 'Nouveau mandat de vente',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: CouleursVente.teinte,
          leading: cree != null
              ? IconButton(
                  tooltip: 'Terminer',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(cree),
                )
              : null,
        ),
        body: cree != null ? _succes(cree) : _corps(),
        bottomNavigationBar: cree != null || _donnees == null ? null : _barreBas(),
      ),
    );
  }

  Widget _corps() {
    if (_donnees == null) {
      if (_erreur != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48, color: CouleursBail.texteDoux),
                const SizedBox(height: 10),
                Text(_erreur!, textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.texte)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _charger,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: OutlinedButton.styleFrom(foregroundColor: CouleursVente.teinte),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: CouleursVente.teinte));
    }
    return Column(
      children: [
        _indicateur(),
        Expanded(
          child: Form(
            key: _formulaire,
            child: ListView(
              key: ValueKey(_etape),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: switch (_etape) {
                0 => _etapeProprietaire(),
                1 => _etapeBien(),
                2 => _etapeApercu(),
                _ => _etapeSignature(),
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Pastilles numerotees et titre de l'etape.
  Widget _indicateur() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_etapes.length, (i) {
              final fait = i < _etape;
              final actif = i == _etape;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0 ? Colors.transparent : (i <= _etape ? CouleursVente.aVendre : CouleursBail.bordure),
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: fait ? CouleursVente.aVendre : (actif ? CouleursVente.teinte : CouleursBail.bordure),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(fait ? Icons.check : _etapes[i].icone,
                              size: 16, color: fait || actif ? Colors.white : CouleursBail.texteDoux),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == _etapes.length - 1
                                ? Colors.transparent
                                : (i < _etape ? CouleursVente.aVendre : CouleursBail.bordure),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _etapes[i].titre,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.15,
                        fontWeight: actif ? FontWeight.w800 : FontWeight.w500,
                        color: actif ? CouleursVente.teinte : CouleursBail.texteDoux,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: CouleursVente.fondTeinte, borderRadius: BorderRadius.circular(16)),
                child: Text('Étape ${_etape + 1}/${_etapes.length}',
                    style: const TextStyle(color: CouleursVente.teinte, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_etapes[_etape].titre,
                    style: const TextStyle(color: CouleursBail.texte, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Boutons fixes en bas : Precedent / Suivant, ou la creation a la derniere etape.
  Widget _barreBas() {
    final derniere = _etape == _etapes.length - 1;
    final String libelle;
    final IconData icone;
    if (!derniere) {
      libelle = _etape == 2 ? 'Passer à la signature' : 'Suivant';
      icone = Icons.arrow_forward;
    } else if (_signature == null) {
      libelle = 'Faire signer';
      icone = Icons.draw_outlined;
    } else {
      libelle = 'Créer le mandat signé';
      icone = Icons.check;
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: CouleursBail.bordure)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (_etape > 0) ...[
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _enCours ? null : _precedent,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CouleursBail.texte,
                        side: const BorderSide(color: CouleursBail.bordure),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Précédent', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _enCours
                        ? null
                        : derniere
                            ? (_signature == null ? _faireSigner : () => _creer(avecSignature: true))
                            : _suivant,
                    icon: _enCours
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(icone, size: 20),
                    label: Text(libelle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CouleursVente.teinte,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: CouleursVente.teinte.withValues(alpha: .6),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Elements communs ─────────────────────────────────────────────

  Widget _groupe(String titre, IconData icone, List<Widget> enfants, {VoidCallback? onModifier}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CarteBail(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icone, size: 19, color: CouleursVente.teinte),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titre,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                ),
                if (onModifier != null)
                  TextButton.icon(
                    onPressed: onModifier,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Modifier'),
                    style: TextButton.styleFrom(
                      foregroundColor: CouleursVente.teinte,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...enfants,
          ],
        ),
      ),
    );
  }

  Widget _espace() => const SizedBox(height: 12);

  Widget _bandeau(IconData icone, String texte, {Color fond = CouleursVente.fondTeinte, Color couleur = CouleursVente.teinte}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 13, height: 1.35, color: CouleursBail.texte, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget? _noteMandatsExistants() {
    final n = _donnees?.mandatsExistants ?? 0;
    if (n <= 0) return null;
    return _bandeau(
      Icons.info_outline,
      'Ce bien a déjà $n mandat${n > 1 ? 's' : ''}.',
      fond: const Color(0xFFFFF4DE),
      couleur: CouleursVente.sansMandat,
    );
  }

  /// Ce que le modele du contrat fixe : l'agence et les clauses.
  Widget _partiesFixes() {
    return Container(
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

  // ── Etape 1 : proprietaire ───────────────────────────────────────

  List<Widget> _etapeProprietaire() {
    final note = _noteMandatsExistants();
    final titre = widget.titreBien;
    return [
      _bandeau(
        Icons.assignment_outlined,
        titre == null || titre.isEmpty
            ? 'Mandat de vente (عقد وساطة عقارية). Les données du propriétaire sont reprises de la fiche du bien : vérifiez-les.'
            : 'Mandat de vente (عقد وساطة عقارية) pour « $titre ». Les données du propriétaire sont reprises '
                'de la fiche du bien : vérifiez-les.',
      ),
      if (note != null) note,
      _groupe('Propriétaire', Icons.person_outline, [
        TextFormField(
          controller: _nom,
          textCapitalization: TextCapitalization.words,
          decoration: decorationBail('Nom complet *', icone: Icons.badge_outlined),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Le nom du propriétaire est obligatoire' : null,
        ),
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
      ]),
    ];
  }

  // ── Etape 2 : bien et conditions ─────────────────────────────────

  List<Widget> _etapeBien() {
    return [
      _groupe('Bien', Icons.home_work_outlined, [
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
      ]),
      _groupe('Conditions', Icons.handshake_outlined, [
        TextFormField(
          controller: _prix,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimal],
          decoration: decorationBail('Prix demandé', suffixe: 'MAD', icone: Icons.payments_outlined),
          validator: (v) {
            if ((v ?? '').trim().isEmpty) return null;
            final p = lireMontant(v!);
            return p == null || p < 0 ? 'Prix invalide' : null;
          },
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
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _dateSignature,
              firstDate: DateTime(aujourdhui().year - 3),
              lastDate: DateTime(aujourdhui().year + 3),
              helpText: 'Date de signature',
            );
            if (d != null && mounted) setState(() => _dateSignature = CalendrierBien.jour(d));
          },
          child: InputDecorator(
            decoration: decorationBail('Date de signature', icone: Icons.event_outlined),
            child: Text(dateMoyenne(_dateSignature), style: const TextStyle(fontSize: 14.5)),
          ),
        ),
        _espace(),
        TextFormField(controller: _remarques, minLines: 2, maxLines: 5, decoration: decorationBail('Remarques')),
      ]),
      _partiesFixes(),
    ];
  }

  // ── Etape 3 : apercu ─────────────────────────────────────────────

  List<Widget> _etapeApercu() {
    final libelleType = _type == null ? '' : (_types[_type] == _type ? _type! : '$_type — ${_types[_type]}');
    final surface = lireMontant(_surface.text);
    final prix = lireMontant(_prix.text);
    return [
      _bandeau(
        Icons.fact_check_outlined,
        'Relisez le mandat avec le propriétaire avant de le faire signer.',
        fond: const Color(0xFFE8F4EC),
        couleur: CouleursVente.aVendre,
      ),
      _groupe('Propriétaire', Icons.person_outline, onModifier: () => _allerA(0), [
        _Recap(lignes: {
          'Nom': _nom.text.trim(),
          'CIN': _cin.text.trim(),
          'Nationalité': _nationalite.text.trim(),
          'Téléphone': _tel.text.trim(),
          'Adresse': _adresse.text.trim(),
        }),
      ]),
      _groupe('Bien', Icons.home_work_outlined, onModifier: () => _allerA(1), [
        _Recap(lignes: {
          'Type': libelleType,
          'Ville': _ville.text.trim(),
          'Surface': surface == null ? '' : '${prixSimple(surface)} m²',
          'Titre foncier': _titreFoncier.text.trim(),
          'Adresse': _adresseBien.text.trim(),
        }),
      ]),
      _groupe('Conditions', Icons.handshake_outlined, onModifier: () => _allerA(1), [
        _Recap(lignes: {
          'Prix demandé': prix == null ? '' : prixVente(prix),
          'Commission': pourcentage(lireMontant(_commission.text) ?? 2.5),
          'Durée': '${int.tryParse(_duree.text.trim()) ?? 12} mois',
          'Date de signature': dateMoyenne(_dateSignature),
          'Remarques': _remarques.text.trim(),
        }),
      ]),
      _partiesFixes(),
    ];
  }

  // ── Etape 4 : signature ──────────────────────────────────────────

  List<Widget> _etapeSignature() {
    final png = _signature;
    final nom = _nom.text.trim();
    return [
      _groupe('Signature du propriétaire', Icons.draw_outlined, [
        Text(
          '${nom.isEmpty ? 'Le propriétaire' : nom} signe une seule fois, sur ce téléphone. '
          'La signature est ajoutée au mandat à sa création.',
          style: const TextStyle(fontSize: 13, height: 1.35, color: CouleursBail.texteDoux),
        ),
        const SizedBox(height: 12),
        if (png == null)
          InkWell(
            onTap: _enCours ? null : _faireSigner,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: CouleursVente.fondTeinte.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CouleursVente.teinte, width: 1.4),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gesture, size: 36, color: CouleursVente.teinte),
                  SizedBox(height: 8),
                  Text('Toucher pour faire signer',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: CouleursVente.teinte)),
                ],
              ),
            ),
          )
        else ...[
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CouleursVente.aVendre, width: 1.4),
            ),
            child: Image.memory(png, fit: BoxFit.contain),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 18, color: CouleursVente.aVendre),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Signature recueillie',
                    style: TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
              ),
              TextButton.icon(
                onPressed: _enCours ? null : _faireSigner,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refaire'),
                style: TextButton.styleFrom(foregroundColor: CouleursVente.teinte),
              ),
            ],
          ),
        ],
      ]),
      Center(
        child: TextButton.icon(
          onPressed: _enCours ? null : () => _creer(avecSignature: false),
          icon: const Icon(Icons.schedule, size: 18),
          label: const Text('Signer plus tard (créer sans signature)'),
          style: TextButton.styleFrom(foregroundColor: CouleursBail.texteDoux, minimumSize: const Size.fromHeight(46)),
        ),
      ),
    ];
  }

  // ── Ecran de fin ─────────────────────────────────────────────────

  Widget _succes(MandatVente m) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: Color(0xFFE8F4EC), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 44, color: CouleursVente.aVendre),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Mandat créé',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
        const SizedBox(height: 6),
        Text(
          m.signe
              ? 'Le mandat est signé par le propriétaire. Vous pouvez le consulter ou le lui envoyer.'
              : 'Le mandat est « À signer ». Le propriétaire pourra le signer plus tard depuis le dossier de vente.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: CouleursBail.texteDoux),
        ),
        const SizedBox(height: 18),
        ResumeMandat(mandat: m),
        const SizedBox(height: 18),
        if (!m.signe && peutSignerMandat) ...[
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _enCours ? null : () => _signerMaintenant(m),
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Faire signer maintenant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursVente.teinte,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _enCours ? null : () => _voir(m),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  label: const Text('Voir le mandat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CouleursBail.aPayer,
                    side: const BorderSide(color: CouleursBail.aPayer),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _enCours || !peutModifierMandat ? null : () => _envoyer(m),
                  icon: const Icon(Icons.send_outlined, size: 20),
                  label: const Text('Envoyer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25A244),
                    side: const BorderSide(color: Color(0xFF25A244)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(m),
          style: TextButton.styleFrom(foregroundColor: CouleursBail.texte, minimumSize: const Size.fromHeight(48)),
          child: const Text('Terminer', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Lignes « libelle : valeur » ; une valeur vide s'affiche « — ».
class _Recap extends StatelessWidget {
  final Map<String, String> lignes;

  const _Recap({required this.lignes});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in lignes.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
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
    );
  }
}
