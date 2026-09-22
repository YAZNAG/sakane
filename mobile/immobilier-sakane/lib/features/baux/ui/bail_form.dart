import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/baux/cubit/bail_form_cubit.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/baux/ui/components/choix_locataire.dart';
import 'package:immobilier/features/baux/ui/components/occupants_bail.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/models/client.dart';

/// Nouveau contrat de location longue duree, en cinq etapes sur une page.
/// Rend le bail cree.
class BailFormPage extends StatefulWidget {
  final BienLongueDuree? bien;

  const BailFormPage({super.key, this.bien});

  static Widget page({BienLongueDuree? bien}) => BlocProvider(
        create: (_) => BailFormCubit()..chargerBiens(),
        child: BailFormPage(bien: bien),
      );

  @override
  State<BailFormPage> createState() => _BailFormPageState();
}

class _BailFormPageState extends State<BailFormPage> {
  static const List<int> _dureesProposees = [6, 12, 24];
  static const int _dureeMax = 120;

  final _formulaire = GlobalKey<FormState>();
  final _loyer = TextEditingController();
  final _charges = TextEditingController();
  final _depot = TextEditingController();
  final _eau = TextEditingController();
  final _elec = TextEditingController();
  final _remarques = TextEditingController();

  BienLongueDuree? _bien;
  Client? _locataire;
  DateTime _debut = aujourdhui();
  late DateTime _fin = finDeBail(_debut, 12);
  bool _depotRecu = false;
  bool _relances = true;
  bool _envoyerContrat = true;
  final List<File> _photos = [];
  final List<File> _photosCin = [];
  final List<LigneOccupant> _occupants = [];

  @override
  void initState() {
    super.initState();
    if (widget.bien != null) _choisirBien(widget.bien!);
  }

  @override
  void dispose() {
    for (final c in [_loyer, _charges, _depot, _eau, _elec, _remarques]) {
      c.dispose();
    }
    for (final l in _occupants) {
      l.dispose();
    }
    super.dispose();
  }

  /// Null tant que la fin ne suit pas le debut.
  int? get _dureeMois => _fin.isAfter(_debut) ? dureeMoisEntre(_debut, _fin) : null;

  double get _loyerSaisi => lireMontant(_loyer.text) ?? 0;
  double get _chargesSaisies => lireMontant(_charges.text) ?? 0;
  double get _depotSaisi => lireMontant(_depot.text) ?? 0;

  String get _nomLocataire => _locataire == null
      ? ''
      : '${_locataire!.firstName ?? ''} ${_locataire!.lastName ?? ''}'.trim();

  void _choisirBien(BienLongueDuree b) {
    setState(() {
      _bien = b;
      if (_loyer.text.trim().isEmpty && b.loyerPropose != null) {
        _loyer.text = prixSimple(b.loyerPropose!);
      }
    });
  }

  // ── Choix ────────────────────────────────────────────────────────

  Future<void> _ouvrirChoixBien() async {
    final cubit = context.read<BailFormCubit>();
    if (cubit.state.biens == null && cubit.state.statutBiens != AppStatus.loading) cubit.chargerBiens();
    final choisi = await showModalBottomSheet<BienLongueDuree>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(value: cubit, child: const _ChoixBien()),
    );
    if (choisi != null) _choisirBien(choisi);
  }

  Future<void> _ouvrirChoixLocataire() async {
    final c = await choisirLocataire(context);
    if (c != null) {
      setState(() {
        _locataire = c;
        if ((c.tel ?? '').trim().isEmpty) _envoyerContrat = false;
      });
    }
  }

  Future<void> _choisirDebut() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _debut,
      firstDate: DateTime(aujourdhui().year - 2),
      lastDate: DateTime(aujourdhui().year + 3),
      helpText: 'Date de début',
    );
    if (d == null) return;
    setState(() {
      final duree = _dureeMois;
      _debut = CalendrierBien.jour(d);
      // La duree choisie suit le nouveau debut.
      _fin = finDeBail(_debut, duree ?? 12);
    });
  }

  Future<void> _choisirFin() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fin.isAfter(_debut) ? _fin : ajouterJours(_debut, 1),
      firstDate: ajouterJours(_debut, 1),
      lastDate: finDeBail(_debut, _dureeMax),
      helpText: 'Date de fin',
    );
    if (d != null) setState(() => _fin = CalendrierBien.jour(d));
  }

  // ── Envoi ────────────────────────────────────────────────────────

  Future<void> _valider() async {
    FocusScope.of(context).unfocus();
    if (_bien == null) {
      afficherMessage(context, 'Étape 1 : choisissez le logement.', erreur: true);
      return;
    }
    if (_locataire == null) {
      afficherMessage(context, 'Étape 2 : choisissez le locataire.', erreur: true);
      return;
    }
    if (_locataire!.listeNoire != null) {
      afficherMessage(context, messageListeNoireBail(_locataire!), erreur: true);
      return;
    }
    if (!(_formulaire.currentState?.validate() ?? false)) {
      afficherMessage(context, 'Vérifiez les champs signalés en rouge.', erreur: true);
      return;
    }
    final duree = _dureeMois;
    if (duree == null) {
      afficherMessage(context, 'La date de fin doit être après la date de début.', erreur: true);
      return;
    }
    if (duree > _dureeMax) {
      afficherMessage(context, 'La durée ne peut pas dépasser $_dureeMax mois.', erreur: true);
      return;
    }

    context.read<BailFormCubit>().creer(
          bien: _bien!.id,
          client: _locataire!.id!,
          dateDebut: _debut,
          dateFin: _fin,
          loyer: _loyerSaisi,
          charges: _charges.text.trim().isEmpty ? null : _chargesSaisies,
          depot: _depot.text.trim().isEmpty ? null : _depotSaisi,
          depotRecu: _depotRecu && _depotSaisi > 0,
          compteurEauEntree: _eau.text,
          compteurElecEntree: _elec.text,
          remarques: _remarques.text,
          relancesActives: _relances,
          envoyerContrat: _envoyerContrat && (_locataire!.tel ?? '').trim().isNotEmpty,
          photos: List.of(_photos),
          colocataires: occupantsSaisis(_occupants),
          cinPhotos: List.of(_photosCin),
        );
  }

  // ── Ecran ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BailFormCubit, BailFormState>(
      listenWhen: (a, b) => a.statutEnvoi != b.statutEnvoi,
      listener: (context, state) {
        if (state.statutEnvoi == AppStatus.success && state.cree != null) {
          afficherMessage(context, 'Contrat créé.');
          afficherAvertissement(context, state.avertissement);
          GoRouter.of(context).pop(state.cree);
        } else if (state.statutEnvoi == AppStatus.error) {
          afficherMessage(context, state.erreurEnvoi ?? "Le contrat n'a pas pu être créé.", erreur: true);
        }
      },
      builder: (context, state) {
        final envoi = state.statutEnvoi == AppStatus.loading;
        return Scaffold(
          backgroundColor: CouleursBail.fond,
          appBar: AppBar(
            title: const Text('Nouveau contrat', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            bottom: envoi
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3, color: Colors.white, backgroundColor: Colors.transparent),
                  )
                : null,
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton.icon(
                onPressed: envoi ? null : _valider,
                icon: envoi
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: Text(envoi ? 'Création…' : 'Créer le contrat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CouleursBail.teinte,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          body: AbsorbPointer(
            absorbing: envoi,
            child: Form(
              key: _formulaire,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                children: [
                  _etape(1, 'Logement', Icons.home_work_outlined, fait: _bien != null),
                  _selecteur(
                    icone: Icons.home_outlined,
                    titre: _bien?.titre ?? 'Choisir le logement',
                    sousTitre: _bien == null
                        ? 'Seuls les logements libres peuvent être choisis'
                        : (_bien!.adresse ??
                            (_bien!.loyerPropose == null ? '' : 'Loyer proposé : ${montantLisible(_bien!.loyerPropose!)}')),
                    vide: _bien == null,
                    onTap: _ouvrirChoixBien,
                  ),
                  _etape(2, 'Locataire', Icons.person_outline, fait: _locataire != null),
                  _sectionLocataire(),
                  _etape(3, 'Autres occupants (facultatif)', Icons.groups_outlined,
                      fait: occupantsSaisis(_occupants).isNotEmpty),
                  _sectionOccupants(),
                  _etape(4, 'Conditions', Icons.payments_outlined, fait: _loyerSaisi > 0 && _dureeMois != null),
                  _sectionConditions(),
                  const SizedBox(height: 10),
                  _sectionEtatDesLieux(),
                  _etape(5, 'Récapitulatif', Icons.fact_check_outlined, fait: false),
                  _sectionResume(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Titre d'etape numerote ; la pastille passe au vert une fois l'etape remplie.
  Widget _etape(int numero, String texte, IconData icone, {required bool fait}) {
    final couleur = fait ? CouleursBail.paye : CouleursBail.teinte;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: couleur,
            child: fait
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : Text('$numero',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
          ),
          Icon(icone, size: 18, color: CouleursBail.texteDoux),
        ],
      ),
    );
  }

  Widget _selecteur({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required bool vide,
    required VoidCallback onTap,
  }) {
    return CarteBail(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: CouleursBail.fondTeinte, borderRadius: BorderRadius.circular(12)),
            child: Icon(icone, color: CouleursBail.teinte),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: vide ? CouleursBail.teinte : CouleursBail.texte,
                    )),
                if (sousTitre.isNotEmpty)
                  Text(sousTitre, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              ],
            ),
          ),
          Icon(vide ? Icons.add_circle_outline : Icons.edit_outlined, color: CouleursBail.teinte),
        ],
      ),
    );
  }

  Widget _bandeau(String texte, Color couleur, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: couleur.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: TextStyle(fontSize: 12.5, color: couleur, height: 1.35))),
        ],
      ),
    );
  }

  Widget _sectionLocataire() {
    final c = _locataire;
    final sansArabe = c != null && '${c.firstNameAr ?? ''}${c.lastNameAr ?? ''}'.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _selecteur(
          icone: Icons.person_outline,
          titre: c == null ? 'Choisir le locataire' : _nomLocataire,
          sousTitre: c == null ? 'Client existant ou nouveau client (avec sa CIN)' : 'Changer de locataire',
          vide: c == null,
          onTap: _ouvrirChoixLocataire,
        ),
        if (c != null) ...[
          const SizedBox(height: 8),
          CarteBail(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                _ligneInfo(Icons.badge_outlined, 'CIN',
                    (c.identityNumber ?? '').trim().isEmpty ? 'Non renseignée' : c.identityNumber!),
                _ligneInfo(Icons.phone_outlined, 'Téléphone', (c.tel ?? '').trim().isEmpty ? 'Aucun' : c.tel!),
                if (!sansArabe)
                  _ligneInfo(Icons.translate, 'Nom en arabe', '${c.firstNameAr ?? ''} ${c.lastNameAr ?? ''}'.trim()),
              ],
            ),
          ),
          if (sansArabe)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _bandeau(
                  'Nom en arabe inconnu : le contrat reprendra le nom en lettres latines.',
                  CouleursBail.aPayer,
                  Icons.info_outline),
            ),
        ],
        if (c?.listeNoire != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _bandeau(messageListeNoireBail(c!), CouleursBail.retard, Icons.block),
          ),
        const SizedBox(height: 10),
        CarteBail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photos de la CIN (${_photosCin.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
              const SizedBox(height: 2),
              const Text(
                'Recto et verso de la CIN du locataire. Ajoutez ici aussi celles des autres occupants.',
                style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux),
              ),
              const SizedBox(height: 8),
              SelecteurPhotosBail(photos: _photosCin, onChange: () => setState(() {})),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligneInfo(IconData icone, String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icone, size: 16, color: CouleursBail.texteDoux),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(libelle, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
          ),
          Expanded(
            child: Text(valeur, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sectionOccupants() {
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Les personnes qui habiteront avec le locataire (conjoint, enfants, colocataires). '
            'Elles figureront sur le contrat. Leurs CIN se photographient à l\'étape 2.',
            style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux, height: 1.35),
          ),
          const SizedBox(height: 10),
          EditeurOccupants(lignes: _occupants, onChange: () => setState(() {})),
        ],
      ),
    );
  }

  String? _montantObligatoire(String? v) {
    final m = lireMontant(v ?? '');
    return (m == null || m <= 0) ? 'Montant requis' : null;
  }

  String? _montantFacultatif(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    final m = lireMontant(v!);
    return (m == null || m < 0) ? 'Montant invalide' : null;
  }

  Widget _champMontant(TextEditingController c, String label,
      {String? Function(String?)? validator, String? aide}) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {}),
      validator: validator ?? _montantFacultatif,
      decoration: decorationBail(label, suffixe: 'MAD', aide: aide),
    );
  }

  Widget _champDate(String libelle, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: decorationBail(libelle, icone: Icons.event),
        child: Text(dateMoyenne(date), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _sectionConditions() {
    final mensuel = _loyerSaisi + _chargesSaisies;
    final duree = _dureeMois;
    final dureeValide = duree != null && duree <= _dureeMax;
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _champMontant(_loyer, 'Loyer mensuel *', validator: _montantObligatoire),
          const SizedBox(height: 12),
          _champMontant(_charges, 'Charges mensuelles', aide: 'Syndic, eau, entretien… (facultatif)'),
          if (mensuel > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Total par mois : ${montantLisible(mensuel)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: CouleursBail.teinte)),
            ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(child: _champDate('Date de début', _debut, _choisirDebut)),
              const SizedBox(width: 10),
              Expanded(child: _champDate('Date de fin', _fin, _choisirFin)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Raccourcis :', style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
              for (final m in _dureesProposees)
                ChoiceChip(
                  label: Text('$m mois'),
                  selected: _fin == finDeBail(_debut, m),
                  onSelected: (_) => setState(() => _fin = finDeBail(_debut, m)),
                  selectedColor: CouleursBail.fondTeinte,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: dureeValide ? CouleursBail.fondTeinte : CouleursBail.retard.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              duree == null
                  ? 'La date de fin doit être après la date de début.'
                  : !dureeValide
                      ? 'Durée de $duree mois : maximum $_dureeMax mois.'
                      : 'Durée : $duree mois (un mois commencé compte)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dureeValide ? CouleursBail.teinte : CouleursBail.retard,
              ),
            ),
          ),
          const Divider(height: 28),
          _champMontant(_depot, 'Caution (dépôt de garantie)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _depotRecu && _depotSaisi > 0,
            activeThumbColor: CouleursBail.teinte,
            onChanged: _depotSaisi > 0 ? (v) => setState(() => _depotRecu = v) : null,
            title: const Text('Caution reçue maintenant', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Le montant entre dans votre caisse.', style: TextStyle(fontSize: 12)),
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _relances,
            activeThumbColor: CouleursBail.teinte,
            onChanged: (v) => setState(() => _relances = v),
            title: const Text('Relances automatiques', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Rappels WhatsApp avant et après chaque échéance.', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionEtatDesLieux() {
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("État des lieux d'entrée",
              style: TextStyle(fontWeight: FontWeight.w800, color: CouleursBail.texte)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _eau,
                  decoration: decorationBail('Compteur eau', icone: Icons.water_drop_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _elec,
                  decoration: decorationBail('Compteur électricité', icone: Icons.bolt_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Photos du logement (${_photos.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
          const SizedBox(height: 8),
          SelecteurPhotosBail(photos: _photos, onChange: () => setState(() {})),
          const SizedBox(height: 12),
          TextFormField(
            controller: _remarques,
            maxLines: 3,
            minLines: 2,
            decoration: decorationBail('Remarques', aide: 'État du logement, équipements, clés remises…'),
          ),
        ],
      ),
    );
  }

  Widget _sectionResume() {
    final duree = _dureeMois;
    final mensuel = _loyerSaisi + _chargesSaisies;
    final occupants = occupantsSaisis(_occupants);
    final sansTel = _locataire != null && (_locataire!.tel ?? '').trim().isEmpty;
    Widget ligne(String libelle, String valeur, {bool fort = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(libelle, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              ),
              Expanded(
                child: Text(valeur,
                    style: TextStyle(fontSize: 13.5, fontWeight: fort ? FontWeight.w800 : FontWeight.w600)),
              ),
            ],
          ),
        );
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ligne('Logement', _bien?.titre ?? '—', fort: true),
          ligne('Locataire', _locataire == null ? '—' : _nomLocataire, fort: true),
          if (occupants.isNotEmpty)
            ligne('Occupants', occupants.map((o) => (o.lien ?? '').isEmpty ? o.nom : '${o.nom} (${o.lien})').join(', ')),
          ligne('Période', duree == null ? '—' : '${periodeBail(_debut, _fin)} ($duree mois)'),
          ligne('Loyer', _loyerSaisi > 0 ? montantLisible(_loyerSaisi) : '—'),
          if (_chargesSaisies > 0) ligne('Charges', montantLisible(_chargesSaisies)),
          ligne('Total mensuel', mensuel > 0 ? montantLisible(mensuel) : '—', fort: true),
          if (_depotSaisi > 0)
            ligne('Caution',
                '${montantLisible(_depotSaisi)}${_depotRecu ? ' — reçue, entre en caisse' : ' — non reçue'}'),
          if (_photosCin.isNotEmpty) ligne('CIN', pluriel(_photosCin.length, 'photo')),
          if (_photos.isNotEmpty) ligne('État des lieux', pluriel(_photos.length, 'photo')),
          ligne('Relances', _relances ? 'Automatiques' : 'Désactivées'),
          const Divider(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _envoyerContrat && !sansTel,
            activeThumbColor: CouleursBail.teinte,
            onChanged: sansTel ? null : (v) => setState(() => _envoyerContrat = v),
            title: const Text('Envoyer le contrat au locataire par WhatsApp',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              sansTel ? 'Le locataire n\'a pas de numéro.' : 'Contrat en arabe, rempli automatiquement (PDF).',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Choix du logement ──────────────────────────────────────────────

class _ChoixBien extends StatelessWidget {
  const _ChoixBien();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .8,
      minChildSize: .4,
      maxChildSize: .95,
      expand: false,
      builder: (context, controleur) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: BlocBuilder<BailFormCubit, BailFormState>(
          builder: (context, state) {
            final biens = state.biens;
            Widget corps;
            if (biens == null) {
              corps = Center(
                child: state.statutBiens == AppStatus.error
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.erreurBiens ?? 'Erreur',
                              textAlign: TextAlign.center, style: const TextStyle(color: CouleursBail.retard)),
                          TextButton(
                            onPressed: () => context.read<BailFormCubit>().chargerBiens(),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(color: CouleursBail.teinte),
              );
            } else if (biens.isEmpty) {
              corps = const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucun bien proposé en location longue durée.',
                      textAlign: TextAlign.center, style: TextStyle(color: CouleursBail.texteDoux)),
                ),
              );
            } else {
              final tries = [...biens]..sort((a, b) => (a.libre == b.libre) ? 0 : (a.libre ? -1 : 1));
              corps = ListView.separated(
                controller: controleur,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: tries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final b = tries[i];
                  return Opacity(
                    opacity: b.libre ? 1 : .5,
                    child: CarteBail(
                      onTap: b.libre ? () => Navigator.of(context).pop(b) : null,
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          PhotoBien(url: b.photo, taille: 48),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.titre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  b.libre
                                      ? (b.loyerPropose == null
                                          ? 'Libre'
                                          : 'Libre • ${montantLisible(b.loyerPropose!)} / mois')
                                      : 'Loué à ${b.bail!.locataire}'
                                          "${b.bail!.dateFin == null ? '' : " jusqu'au ${dateBail(b.bail!.dateFin)}"}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: b.libre ? CouleursBail.paye : CouleursBail.texteDoux,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: CouleursBail.bordure, borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choisir le logement',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                  ),
                ),
                Expanded(child: corps),
              ],
            );
          },
        ),
      ),
    );
  }
}
