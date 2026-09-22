import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/ventes/cubit/dossier_vente_cubit.dart';
import 'package:immobilier/features/ventes/ui/components/mandat_outils.dart';
import 'package:immobilier/features/ventes/ui/components/suivi_vente.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/features/ventes/ui/components/visite_outils.dart';
import 'package:immobilier/features/ventes/ui/creer_mandat.dart';
import 'package:immobilier/features/ventes/ui/formulaires_vente.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

/// Dossier de vente d'un bien : statut, mandats et recus de visite.
class DossierVentePage extends StatefulWidget {
  /// Onglet d'ouverture : mandats ou visites.
  final String? onglet;

  /// Ouvre la creation du mandat des le chargement (apres l'ajout d'un bien).
  final bool nouveauMandat;

  const DossierVentePage({super.key, this.onglet, this.nouveauMandat = false});

  static Widget page(int id, {String? onglet, bool nouveauMandat = false}) => BlocProvider(
        create: (_) => DossierVenteCubit(id)..charger(),
        child: DossierVentePage(onglet: onglet, nouveauMandat: nouveauMandat),
      );

  @override
  State<DossierVentePage> createState() => _DossierVentePageState();
}

class _DossierVentePageState extends State<DossierVentePage> with SingleTickerProviderStateMixin {
  late final TabController _onglets =
      TabController(length: 2, vsync: this, initialIndex: widget.onglet == 'visites' ? 1 : 0)
        ..addListener(() {
          if (!_onglets.indexIsChanging) setState(() {});
        });

  bool _formulaireDemande = false;

  DossierVenteCubit get _cubit => context.read<DossierVenteCubit>();

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  void _resultat(ResultatVente res, String succes) {
    if (!mounted) return;
    if (res.erreur != null) {
      afficherMessage(context, res.erreur!, erreur: true);
    } else if (res.avertissement != null) {
      afficherAvertissement(context, '$succes ${res.avertissement}');
    } else {
      afficherMessage(context, succes);
    }
  }

  /// Creation du mandat pre-rempli depuis le bien : proprietaire, bien et
  /// conditions, apercu, puis signature du proprietaire.
  Future<void> _nouveauMandat(DossierVente d) async {
    final m = await ouvrirCreationMandat(context, d.bien.id, titreBien: d.bien.titre);
    if (!mounted) return;
    await _cubit.charger(silencieux: true);
    if (m == null || !mounted) return;
    _onglets.animateTo(0);
  }

  Future<void> _signer(MandatVente m) async {
    final signe = await faireSignerMandat(context, m);
    if (signe != null && mounted) await _cubit.charger(silencieux: true);
  }

  Future<void> _modifierMandat(DossierVente d, MandatVente m) async {
    final modifie = await ouvrirFormulaireMandatVente(
      context,
      initial: m,
      titreBien: d.bien.titre,
      types: d.types,
      enregistrer: (champs) => Dependencies.get<Repository>().modifierMandatVente(m.id, champs),
    );
    if (modifie == null || !mounted) return;
    await _cubit.charger(silencieux: true);
    if (mounted) afficherMessage(context, 'Mandat modifié.');
  }

  Future<void> _nouvelleVisite(DossierVente d) async {
    final cree = await ouvrirFormulaireVisite(context, d, _cubit);
    if (!mounted) return;
    // Le recu a pu etre signe apres sa creation : on relit le dossier.
    await _cubit.charger(silencieux: true);
    if (cree && mounted) _onglets.animateTo(1);
  }

  Future<void> _signerVisite(VisiteVente v) async {
    final signee = await faireSignerVisite(context, v);
    if (signee != null && mounted) await _cubit.charger(silencieux: true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DossierVenteCubit, DossierVenteState>(
      listenWhen: (a, b) => a.dossier == null && b.dossier != null,
      listener: (context, state) {
        // Apres l'ajout d'un bien : le formulaire du mandat s'ouvre seul, une fois.
        if (widget.nouveauMandat && !_formulaireDemande && peutCreerMandat) {
          _formulaireDemande = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && state.dossier != null) _nouveauMandat(state.dossier!);
          });
        }
      },
      builder: (context, state) {
        final d = state.dossier;
        return Scaffold(
          backgroundColor: CouleursBail.fond,
          appBar: AppBar(
            title: const Text('Dossier de vente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: CouleursVente.teinte,
          ),
          floatingActionButton: d != null && (_onglets.index == 0 ? peutCreerMandat : peutCreerVisite)
              ? FloatingActionButton.extended(
                  onPressed: state.enCours
                      ? null
                      : () => _onglets.index == 0 ? _nouveauMandat(d) : _nouvelleVisite(d),
                  backgroundColor: CouleursVente.teinte,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(_onglets.index == 0 ? 'Créer un mandat' : 'Ajouter une visite',
                      style: const TextStyle(color: Colors.white)),
                )
              : null,
          body: _corps(state),
        );
      },
    );
  }

  Widget _corps(DossierVenteState state) {
    final d = state.dossier;
    if (d == null) {
      if (state.statut == AppStatus.error) {
        return Center(
          child: SingleChildScrollView(
            child: MyErrorWidget(
              error: state.erreur ?? 'Erreur',
              action: AppStrings.tryAgain,
              actionCLick: () => _cubit.charger(),
            ),
          ),
        );
      }
      return Center(child: MyLoadingIndicator());
    }
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _entete(d, state.enCours)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _BarreOnglets(
            TabBar(
              controller: _onglets,
              labelColor: CouleursVente.teinte,
              unselectedLabelColor: CouleursBail.texteDoux,
              indicatorColor: CouleursVente.teinte,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              tabs: [
                Tab(text: 'Mandats (${d.mandats.length})'),
                Tab(text: 'Reçus de visite (${d.visites.length})'),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _onglets,
        children: [_mandats(d), _visites(d)],
      ),
    );
  }

  // ── En-tete ──────────────────────────────────────────────────────

  Widget _entete(DossierVente d, bool enCours) {
    final b = d.bien;
    final statuts = d.statuts.isNotEmpty ? d.statuts : StatutVente.libelles;
    final proprietaire = b.proprietaire;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhotoBien(url: b.photo, taille: 84),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CouleursBail.texte)),
                    if ((b.adresse ?? '').isNotEmpty)
                      Text(b.adresse!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                    const SizedBox(height: 4),
                    Text(
                      '${prixVente(b.prix)}${(b.surface ?? 0) > 0 ? ' • ${prixSimple(b.surface!)} m²' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CouleursVente.teinte),
                    ),
                    const SizedBox(height: 6),
                    PastilleMandat(mandat: b.mandat),
                  ],
                ),
              ),
            ],
          ),
          if (proprietaire != null && proprietaire.nom.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: CouleursBail.fond,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: CouleursBail.texteDoux),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Propriétaire', style: TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
                        Text(proprietaire.nom,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
                        if ((proprietaire.tel ?? '').isNotEmpty)
                          Text(proprietaire.tel!, style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                      ],
                    ),
                  ),
                  BoutonsContact(tel: proprietaire.tel),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          CarteSuiviVente(
            dossier: d,
            onCreerMandat: peutCreerMandat && !enCours ? () => _nouveauMandat(d) : null,
            onAjouterVisite: peutCreerVisite && !enCours ? () => _nouvelleVisite(d) : null,
          ),
          const SizedBox(height: 12),
          const Text('Statut de la vente',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CouleursBail.texteDoux)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final s in statuts.entries)
                ChoiceChip(
                  avatar: Icon(CouleursVente.iconeStatut(s.key),
                      size: 16, color: b.statutVente == s.key ? CouleursVente.statut(s.key) : CouleursBail.texteDoux),
                  label: Text(s.value),
                  selected: b.statutVente == s.key,
                  onSelected: !peutChangerStatutVente || enCours || b.statutVente == s.key
                      ? null
                      : (_) => _changerStatut(s.key, s.value),
                  selectedColor: CouleursVente.statut(s.key).withValues(alpha: .15),
                  disabledColor: Colors.white,
                  labelStyle: TextStyle(
                    fontWeight: b.statutVente == s.key ? FontWeight.w700 : FontWeight.w500,
                    color: b.statutVente == s.key ? CouleursVente.statut(s.key) : CouleursBail.texte,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: CouleursBail.bordure),
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changerStatut(String code, String libelle) async {
    if (code == StatutVente.vendu) {
      final ok = await confirmer(
        context,
        titre: 'Marquer comme vendu ?',
        message: 'Le bien passera au statut « $libelle ».',
        action: 'Confirmer',
        couleur: CouleursVente.vendu,
      );
      if (!ok || !mounted) return;
    }
    _resultat(await _cubit.changerStatut(code), 'Statut : $libelle.');
  }

  Widget _vide(String texte, IconData icone, {String? action, VoidCallback? onAction}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 96),
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: CouleursVente.fondTeinte, shape: BoxShape.circle),
            child: Icon(icone, size: 38, color: CouleursVente.teinte),
          ),
        ),
        const SizedBox(height: 14),
        Text(texte,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CouleursBail.texteDoux, fontSize: 14, height: 1.4)),
        if (action != null && onAction != null) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 19),
              label: Text(action),
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursVente.teinte,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Mandats ──────────────────────────────────────────────────────

  Widget _mandats(DossierVente d) {
    if (d.mandats.isEmpty) {
      return _vide(
        "Aucun mandat de vente.\nCréez le mandat (عقد وساطة عقارية) : les données du bien et du propriétaire "
        'sont pré-remplies, il ne reste qu\'à vérifier et faire signer.',
        Icons.assignment_outlined,
        action: peutCreerMandat ? 'Créer un mandat' : null,
        onAction: () => _nouveauMandat(d),
      );
    }
    final mandats = [...d.mandats]..sort((a, b) {
        if (a.actif != b.actif) return a.actif ? -1 : 1;
        return (b.dateSignature ?? DateTime(0)).compareTo(a.dateSignature ?? DateTime(0));
      });
    return RefreshIndicator(
      onRefresh: () => _cubit.charger(silencieux: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
        itemCount: mandats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _carteMandat(d, mandats[i]),
      ),
    );
  }

  Widget _carteMandat(DossierVente d, MandatVente m) {
    final jours = m.actif ? libelleJoursRestants(m.joursRestants) : '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: m.actif ? CouleursVente.teinte : CouleursBail.bordure,
            width: m.actif ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: m.actif ? CouleursVente.teinte : CouleursBail.texteDoux),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.proprietaireNom.isEmpty ? 'Propriétaire' : m.proprietaireNom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                ),
                m.actif
                    ? const PastilleBail(texte: 'Actif', couleur: CouleursVente.aVendre, icone: Icons.check_circle_outline)
                    : const PastilleBail(texte: 'Expiré', couleur: CouleursBail.aVenir),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Mandat du ${dateBail(m.dateSignature)}'
              '${m.dateFin == null ? '' : " • jusqu'au ${dateBail(m.dateFin)}"}',
              style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                PastilleSignature(mandat: m),
                if (m.prixDemande != null) PastilleBail(texte: prixVente(m.prixDemande), couleur: CouleursVente.teinte),
                PastilleBail(texte: 'Commission ${pourcentage(m.commission)}', couleur: CouleursBail.texteDoux),
                if (m.dureeMois != null) PastilleBail(texte: '${m.dureeMois} mois', couleur: CouleursBail.texteDoux),
                if (jours.isNotEmpty)
                  PastilleBail(
                    texte: jours,
                    couleur: (m.joursRestants ?? 999) <= 30 ? CouleursVente.sansMandat : CouleursVente.compromis,
                  ),
                if ((m.typeBien ?? '').isNotEmpty) PastilleBail(texte: m.typeBien!, couleur: CouleursBail.texteDoux),
              ],
            ),
            if ((m.remarques ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(m.remarques!, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
            ],
            if (peutSignerMandat && !m.signe) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _signer(m),
                  icon: const Icon(Icons.draw_outlined, size: 19),
                  label: const Text('Faire signer le propriétaire'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CouleursVente.teinte,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                _action(Icons.picture_as_pdf_outlined, 'Voir le contrat', CouleursBail.aPayer, () => _pdfMandat(m)),
                if (peutModifierMandat) ...[
                  const SizedBox(width: 6),
                  _action(Icons.send_outlined, 'Envoyer au propriétaire', const Color(0xFF25A244), () => _envoyerMandat(m)),
                ],
                if ((peutModifierMandat && !m.signe) || peutSupprimerMandat) ...[
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: CouleursBail.texteDoux),
                    color: Colors.white,
                    onSelected: (a) => a == 'modifier' ? _modifierMandat(d, m) : _supprimerMandat(m),
                    itemBuilder: (_) => [
                      if (peutModifierMandat && !m.signe) const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                      if (peutSupprimerMandat)
                        const PopupMenuItem(
                            value: 'supprimer', child: Text('Supprimer', style: TextStyle(color: CouleursBail.retard))),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icone, String texte, Color couleur, VoidCallback onTap) {
    return Flexible(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(texte, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
        style: TextButton.styleFrom(
          foregroundColor: couleur,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Future<void> _pdfMandat(MandatVente m) =>
      voirContratMandat(context, m, titre: m.signe ? 'Mandat signé' : 'Mandat de vente');

  Future<void> _envoyerMandat(MandatVente m) async {
    if ((m.proprietaireTel ?? '').isEmpty) {
      afficherMessage(context, "Le propriétaire n'a pas de numéro de téléphone.", erreur: true);
      return;
    }
    final ok = await confirmer(
      context,
      titre: 'Envoyer le mandat ?',
      message: 'Le mandat de vente sera envoyé par WhatsApp à ${m.proprietaireNom} (${m.proprietaireTel}).',
      action: 'Envoyer',
      couleur: const Color(0xFF25A244),
    );
    if (!ok || !mounted) return;
    _resultat(await _cubit.envoyerMandat(m.id), 'Mandat envoyé.');
  }

  Future<void> _supprimerMandat(MandatVente m) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce mandat ?',
      message: 'Le mandat du ${dateBail(m.dateSignature)} sera supprimé.',
      action: 'Supprimer',
      couleur: CouleursBail.retard,
    );
    if (!ok || !mounted) return;
    _resultat(await _cubit.supprimerMandat(m.id), 'Mandat supprimé.');
  }

  // ── Visites ──────────────────────────────────────────────────────

  Widget _visites(DossierVente d) {
    if (d.visites.isEmpty) {
      return _vide(
        "Aucun reçu de visite.\nAprès chaque visite, touchez « Ajouter une visite » : le reçu (وصل زيارة عقار) "
        'est préparé et peut être envoyé au visiteur par WhatsApp.',
        Icons.receipt_long_outlined,
        action: peutCreerVisite ? 'Ajouter une visite' : null,
        onAction: () => _nouvelleVisite(d),
      );
    }
    final visites = [...d.visites]
      ..sort((a, b) => (b.dateVisite ?? DateTime(0)).compareTo(a.dateVisite ?? DateTime(0)));
    return RefreshIndicator(
      onRefresh: () => _cubit.charger(silencieux: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
        itemCount: visites.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _carteVisite(d, visites[i]),
      ),
    );
  }

  Widget _carteVisite(DossierVente d, VisiteVente v) {
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocDateVisite(date: v.dateVisite),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.visiteurNom.isEmpty ? 'Visiteur' : v.visiteurNom,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: CouleursBail.texte)),
                    if ((v.visiteurTel ?? '').isNotEmpty)
                      Text(v.visiteurTel!, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PastilleSignatureVisite(visite: v),
                        if ((v.agent ?? '').isNotEmpty)
                          PastilleBail(texte: v.agent!, couleur: CouleursBail.texteDoux, icone: Icons.badge_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              BoutonsContact(tel: v.visiteurTel),
            ],
          ),
          if ((v.remarques ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(v.remarques!, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
          ],
          if (peutSignerVisite && !v.signe) ...[
            const SizedBox(height: 10),
            BoutonSignerVisite(onPressed: () => _signerVisite(v)),
          ],
          const Divider(height: 20),
          Row(
            children: [
              _action(Icons.receipt_long_outlined, 'Voir le reçu', CouleursBail.aPayer, () => voirRecuVisite(context, v)),
              if (peutCreerVisite) ...[
                const SizedBox(width: 6),
                _action(Icons.send_outlined, 'Envoyer (WhatsApp)', const Color(0xFF25A244), () => _envoyerVisite(v)),
              ],
              if ((peutSignerVisite && !v.signe) || peutSupprimerVisite) ...[
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: CouleursBail.texteDoux),
                  color: Colors.white,
                  onSelected: (a) => a == 'signer' ? _signerVisite(v) : _supprimerVisite(v),
                  itemBuilder: (_) => [
                    if (peutSignerVisite && !v.signe) const PopupMenuItem(value: 'signer', child: Text('Faire signer le client')),
                    if (peutSupprimerVisite)
                      const PopupMenuItem(
                          value: 'supprimer', child: Text('Supprimer', style: TextStyle(color: CouleursBail.retard))),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _envoyerVisite(VisiteVente v) async {
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
    _resultat(await _cubit.envoyerRecu(v.id), 'Reçu envoyé.');
  }

  Future<void> _supprimerVisite(VisiteVente v) async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer ce reçu ?',
      message: 'Le reçu de visite de ${v.visiteurNom.isEmpty ? 'ce visiteur' : v.visiteurNom} '
          'du ${dateBail(v.dateVisite)} sera supprimé.',
      action: 'Supprimer',
      couleur: CouleursBail.retard,
    );
    if (!ok || !mounted) return;
    _resultat(await _cubit.supprimerVisite(v.id), 'Reçu supprimé.');
  }
}

/// Jour et mois d'une visite, dans un carre.
class BlocDateVisite extends StatelessWidget {
  final DateTime? date;

  const BlocDateVisite({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    const couleur = CouleursVente.teinte;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: couleur.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('${date?.day ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: couleur)),
          Text(date == null ? '' : moisCourtsFr[date!.month - 1], style: const TextStyle(fontSize: 11, color: couleur)),
          if (date != null && date!.year != DateTime.now().year)
            Text('${date!.year}', style: const TextStyle(fontSize: 10, color: couleur)),
        ],
      ),
    );
  }
}

class _BarreOnglets extends SliverPersistentHeaderDelegate {
  final TabBar barre;

  _BarreOnglets(this.barre);

  @override
  double get minExtent => barre.preferredSize.height;

  @override
  double get maxExtent => barre.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: CouleursBail.bordure)),
      ),
      child: barre,
    );
  }

  @override
  bool shouldRebuild(covariant _BarreOnglets oldDelegate) => oldDelegate.barre != barre;
}
