import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/cubit/bail_detail_cubit.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/baux/ui/components/dialogues_bail.dart';
import 'package:immobilier/features/baux/ui/components/feuille_loyer.dart';
import 'package:immobilier/features/baux/ui/components/occupants_bail.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/repository/repository.dart';

enum _Action { contrat, envoyer, prolonger, modifier, terminer, supprimer }

/// Fiche d'un bail : resume, actions et echeancier.
class BailDetailPage extends StatefulWidget {
  /// Bail tout juste cree : la fiche propose d'ouvrir le contrat.
  final bool nouveau;

  const BailDetailPage({super.key, this.nouveau = false});

  static Widget page(int id, {Bail? initial, bool nouveau = false}) => BlocProvider(
        create: (_) => BailDetailCubit(id, initial: initial)..charger(silencieux: initial != null),
        child: BailDetailPage(nouveau: nouveau),
      );

  @override
  State<BailDetailPage> createState() => _BailDetailPageState();
}

class _BailDetailPageState extends State<BailDetailPage> {
  BailDetailCubit get _cubit => context.read<BailDetailCubit>();

  @override
  void initState() {
    super.initState();
    if (widget.nouveau) WidgetsBinding.instance.addPostFrameCallback((_) => _proposerContrat());
  }

  Future<void> _proposerContrat() async {
    if (!mounted) return;
    final voir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle_outline, color: CouleursBail.paye, size: 40),
        title: const Text('Contrat créé', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          'Le contrat de location en arabe a été rempli automatiquement '
          'avec le logement, le locataire et les conditions.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Plus tard')),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Voir le contrat'),
            style: ElevatedButton.styleFrom(backgroundColor: CouleursBail.teinte, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (voir != true || !mounted) return;
    await ouvrirPdfBail(
      context,
      () => Dependencies.get<Repository>().telechargerContratBail(_cubit.id),
      'Contrat de bail',
    );
  }

  void _resultat(ResultatBail res, String succes) {
    if (!mounted) return;
    if (res.erreur != null) {
      afficherMessage(context, res.erreur!, erreur: true);
    } else if (res.avertissement != null) {
      afficherAvertissement(context, '$succes ${res.avertissement}');
    } else {
      afficherMessage(context, succes);
    }
  }

  Future<void> _action(_Action action, Bail bail) async {
    switch (action) {
      case _Action.contrat:
        await ouvrirPdfBail(
          context,
          () => Dependencies.get<Repository>().telechargerContratBail(bail.id),
          'Contrat de bail',
        );
      case _Action.envoyer:
        if ((bail.locataire.tel ?? '').isEmpty) {
          afficherMessage(context, "Le locataire n'a pas de numéro de téléphone.", erreur: true);
          return;
        }
        final ok = await confirmer(
          context,
          titre: 'Envoyer le contrat ?',
          message: 'Le contrat de bail sera envoyé par WhatsApp à ${bail.locataire.nom} (${bail.locataire.tel}).',
          action: 'Envoyer',
          couleur: CouleursBail.teinte,
        );
        if (!ok || !mounted) return;
        _resultat(await _cubit.envoyerContrat(), 'Contrat envoyé.');
      case _Action.prolonger:
        final choix = await demanderProlongation(context, bail);
        if (choix == null || !mounted) return;
        _resultat(
          await _cubit.prolonger(mois: choix.mois, loyer: choix.loyer, envoyerContrat: choix.envoyerContrat),
          'Bail prolongé.',
        );
      case _Action.modifier:
        final choix = await demanderModification(context, bail);
        if (choix == null || !mounted) return;
        if (choix.loyer == null &&
            choix.charges == null &&
            choix.remarques == null &&
            choix.relances == null &&
            !choix.depotRecu &&
            choix.colocataires == null &&
            choix.cinPhotos.isEmpty) {
          afficherMessage(context, 'Aucune modification.');
          return;
        }
        _resultat(
          await _cubit.modifier(
            loyer: choix.loyer,
            charges: choix.charges,
            remarques: choix.remarques,
            relancesActives: choix.relances,
            depotRecu: choix.depotRecu,
            colocataires: choix.colocataires,
            cinPhotos: choix.cinPhotos,
          ),
          'Bail modifié.',
        );
      case _Action.terminer:
        final choix = await demanderFinBail(context, bail);
        if (choix == null || !mounted) return;
        _resultat(
          await _cubit.terminer(
            dateSortie: choix.date,
            motif: choix.motif,
            depotRendu: choix.depotRendu,
            compteurEauSortie: choix.eau,
            compteurElecSortie: choix.elec,
          ),
          'Bail terminé.',
        );
      case _Action.supprimer:
        final ok = await confirmer(
          context,
          titre: 'Supprimer ce bail ?',
          message: 'Le bail et son échéancier seront supprimés. Cette action est impossible '
              'si un paiement a été encaissé ou le dépôt reçu.',
          action: 'Supprimer',
          couleur: CouleursBail.retard,
        );
        if (!ok || !mounted) return;
        final erreur = await _cubit.supprimer();
        if (!mounted) return;
        if (erreur != null) {
          afficherMessage(context, erreur, erreur: true);
        } else {
          afficherMessage(context, 'Bail supprimé.');
          GoRouter.of(context).pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BailDetailCubit, BailDetailState>(
      builder: (context, state) {
        final bail = state.bail;
        return Scaffold(
          backgroundColor: CouleursBail.fond,
          appBar: AppBar(
            title: const Text('Bail', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            bottom: state.enCours || (state.statut == AppStatus.loading && bail != null)
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3, color: Colors.white, backgroundColor: Colors.transparent),
                  )
                : null,
            actions: [
              if (bail != null)
                PopupMenuButton<_Action>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  enabled: !state.enCours,
                  onSelected: (a) => _action(a, bail),
                  itemBuilder: (_) => [
                    _menu(_Action.contrat, Icons.picture_as_pdf_outlined, 'Contrat PDF'),
                    if (peutModifierBail) _menu(_Action.envoyer, Icons.send_outlined, 'Envoyer le contrat'),
                    if (peutModifierBail && bail.actif) _menu(_Action.prolonger, Icons.more_time, 'Prolonger'),
                    if (peutModifierBail && bail.actif) _menu(_Action.modifier, Icons.edit_outlined, 'Modifier'),
                    if (peutTerminerBail && bail.actif)
                      _menu(_Action.terminer, Icons.logout, 'Terminer le bail', couleur: CouleursBail.partiel),
                    if (peutSupprimerBail && bail.loyers != null && bail.supprimable)
                      _menu(_Action.supprimer, Icons.delete_outline, 'Supprimer', couleur: CouleursBail.retard),
                  ],
                ),
            ],
          ),
          body: _corps(state),
        );
      },
    );
  }

  PopupMenuItem<_Action> _menu(_Action a, IconData icone, String texte, {Color? couleur}) {
    return PopupMenuItem(
      value: a,
      child: Row(
        children: [
          Icon(icone, size: 20, color: couleur ?? CouleursBail.texte),
          const SizedBox(width: 10),
          Text(texte, style: TextStyle(color: couleur ?? CouleursBail.texte)),
        ],
      ),
    );
  }

  Widget _corps(BailDetailState state) {
    final bail = state.bail;
    if (bail == null) {
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
    return RefreshIndicator(
      onRefresh: () => _cubit.charger(silencieux: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
        children: [
          _entete(bail),
          const SizedBox(height: 10),
          _resume(bail),
          const SizedBox(height: 10),
          _actions(bail, state.enCours),
          if (!bail.actif) ...[const SizedBox(height: 10), _fin(bail)],
          _occupants(bail),
          _photos(bail),
          _infos(bail),
          TitreSection(
            texte: 'Échéancier',
            icone: Icons.calendar_view_month_outlined,
            compteur: bail.loyers == null ? null : '${bail.loyers!.length}',
          ),
          if (bail.loyers == null)
            state.statut == AppStatus.error
                ? Text(state.erreur ?? "L'échéancier n'a pas pu être chargé.",
                    style: const TextStyle(color: CouleursBail.retard))
                : const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: CouleursBail.teinte)),
                  )
          else if (bail.loyers!.isEmpty)
            const Text('Aucune échéance.', style: TextStyle(color: CouleursBail.texteDoux))
          else
            for (final l in bail.loyers!) ...[_ligneLoyer(l), const SizedBox(height: 8)],
        ],
      ),
    );
  }

  Widget _entete(Bail b) {
    final jours = b.actif ? libelleJoursRestants(b.joursRestants) : '';
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhotoBien(url: b.bien.photo, taille: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.bien.titre,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursBail.texte)),
                    if ((b.bien.adresse ?? '').isNotEmpty)
                      Text(b.bien.adresse!, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        b.actif
                            ? const PastilleBail(texte: 'Actif', couleur: CouleursBail.paye)
                            : const PastilleBail(texte: 'Terminé', couleur: CouleursBail.aVenir),
                        if (jours.isNotEmpty)
                          PastilleBail(
                            texte: jours,
                            couleur: (b.joursRestants ?? 999) <= 60 ? CouleursBail.partiel : CouleursBail.texteDoux,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: (b.locataire.listeNoire ? CouleursBail.retard : CouleursBail.teinte).withValues(alpha: .12),
                child: Text(
                  b.locataire.nom.isEmpty ? '?' : b.locataire.nom.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: b.locataire.listeNoire ? CouleursBail.retard : CouleursBail.teinte,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.locataire.nom.isEmpty ? 'Locataire' : b.locataire.nom,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      [
                        if ((b.locataire.tel ?? '').isNotEmpty) b.locataire.tel!,
                        if ((b.locataire.cin ?? '').isNotEmpty) 'CIN ${b.locataire.cin}',
                      ].join(' • '),
                      style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
                    ),
                  ],
                ),
              ),
              BoutonsContact(tel: b.locataire.tel),
            ],
          ),
          if (b.locataire.listeNoire)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PastilleBail(
                texte: 'Liste noire${(b.locataire.motifListeNoire ?? '').isEmpty ? '' : ' : ${b.locataire.motifListeNoire}'}',
                couleur: CouleursBail.retard,
                icone: Icons.block,
              ),
            ),
          if (b.proprietaire != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: CouleursBail.texteDoux),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Propriétaire : ${b.proprietaire!.nom}',
                      style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                ),
                if ((b.proprietaire!.tel ?? '').isNotEmpty) BoutonsContact(tel: b.proprietaire!.tel),
              ],
            ),
          ],
          const Divider(height: 22),
          Row(
            children: [
              const Icon(Icons.date_range_outlined, size: 18, color: CouleursBail.teinte),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${periodeBail(b.dateDebut, b.dateFin)} • ${b.dureeMois} mois',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resume(Bail b) {
    final r = b.resume;
    return Column(
      children: [
        Row(
          children: [
            _carteChiffre(
              'Mensuel',
              montantLisible(b.montantMensuel),
              CouleursBail.teinte,
              b.charges > 0 ? '${montantLisible(b.loyer)} + ${montantLisible(b.charges)} de charges' : 'Loyer',
            ),
            const SizedBox(width: 10),
            _carteChiffre(
              'Reste dû',
              montantLisible(r.resteDu),
              r.resteDu > 0.004 ? (r.enRetard > 0.004 ? CouleursBail.retard : CouleursBail.partiel) : CouleursBail.paye,
              r.enRetard > 0.004 ? 'dont ${montantLisible(r.enRetard)} en retard' : (r.resteDu > 0.004 ? 'à échoir' : 'À jour'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _carteChiffre(
              'Payé',
              montantLisible(r.totalPaye),
              CouleursBail.paye,
              'sur ${montantLisible(r.totalDu)} dus',
            ),
            const SizedBox(width: 10),
            _carteChiffre(
              'Dépôt',
              montantLisible(b.depot),
              b.depotStatut == 'recu' ? CouleursBail.paye : CouleursBail.texteDoux,
              b.depotStatut == 'restitue' && b.depotRendu != null
                  ? '${b.libelleDepot} (${montantLisible(b.depotRendu!)})'
                  : b.libelleDepot,
            ),
          ],
        ),
      ],
    );
  }

  Widget _carteChiffre(String titre, String valeur, Color couleur, String detail) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CouleursBail.bordure),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valeur, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: couleur)),
            ),
            const SizedBox(height: 2),
            Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
          ],
        ),
      ),
    );
  }

  Widget _actions(Bail b, bool enCours) {
    final modifier = peutModifierBail;
    final boutons = <Widget>[
      _bouton(Icons.picture_as_pdf_outlined, 'Contrat PDF', CouleursBail.teinte, () => _action(_Action.contrat, b)),
      if (modifier) _bouton(Icons.send_outlined, 'Envoyer le contrat', const Color(0xFF25A244), () => _action(_Action.envoyer, b)),
      if (modifier && b.actif) _bouton(Icons.more_time, 'Prolonger', CouleursBail.aPayer, () => _action(_Action.prolonger, b)),
      if (modifier && b.actif) _bouton(Icons.edit_outlined, 'Modifier', CouleursBail.texte, () => _action(_Action.modifier, b)),
      if (peutTerminerBail && b.actif)
        _bouton(Icons.logout, 'Terminer le bail', CouleursBail.partiel, () => _action(_Action.terminer, b)),
      if (peutSupprimerBail && b.loyers != null && b.supprimable)
        _bouton(Icons.delete_outline, 'Supprimer', CouleursBail.retard, () => _action(_Action.supprimer, b)),
    ];
    return AbsorbPointer(
      absorbing: enCours,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: boutons),
      ),
    );
  }

  Widget _bouton(IconData icone, String texte, Color couleur, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(texte),
        style: OutlinedButton.styleFrom(
          foregroundColor: couleur,
          backgroundColor: Colors.white,
          side: BorderSide(color: couleur.withValues(alpha: .4)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _occupants(Bail b) {
    if (b.colocataires.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitreSection(
          texte: 'Autres occupants',
          icone: Icons.groups_outlined,
          compteur: '${b.colocataires.length}',
        ),
        CarteBail(
          padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
          child: Column(
            children: [
              for (int i = 0; i < b.colocataires.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _occupant(b.colocataires[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _occupant(Colocataire c) {
    final details = [
      if ((c.cin ?? '').isNotEmpty) 'CIN ${c.cin}',
      if ((c.tel ?? '').isNotEmpty) c.tel!,
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: CouleursBail.fondTeinte,
            child: Text(
              c.nom.characters.first.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800, color: CouleursBail.teinte),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if ((c.lien ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      PastilleBail(texte: c.lien!, couleur: CouleursBail.teinte),
                    ],
                  ],
                ),
                if (details.isNotEmpty)
                  Text(details, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
              ],
            ),
          ),
          BoutonsContact(tel: c.tel),
        ],
      ),
    );
  }

  Widget _photos(Bail b) {
    if (b.cinPhotos.isEmpty && b.etatLieuxPhotos.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TitreSection(texte: 'Photos', icone: Icons.photo_library_outlined),
        CarteBail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (b.cinPhotos.isNotEmpty) ...[
                Text('CIN (${b.cinPhotos.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
                const SizedBox(height: 8),
                MiniaturesBail(urls: b.cinPhotos),
              ],
              if (b.cinPhotos.isNotEmpty && b.etatLieuxPhotos.isNotEmpty) const SizedBox(height: 14),
              if (b.etatLieuxPhotos.isNotEmpty) ...[
                Text("État des lieux (${b.etatLieuxPhotos.length})",
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
                const SizedBox(height: 8),
                MiniaturesBail(urls: b.etatLieuxPhotos),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fin(Bail b) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CouleursBail.aVenir.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Bail terminé${b.termineLe == null ? '' : ' le ${dateBail(b.termineLe)}'}'
        '${(b.motifFin ?? '').isEmpty ? '' : ' — ${b.motifFin}'}',
        style: const TextStyle(fontWeight: FontWeight.w600, color: CouleursBail.texte),
      ),
    );
  }

  Widget _infos(Bail b) {
    final lignes = <(String, String)>[
      ('Relances automatiques', b.relancesActives ? 'Activées' : 'Désactivées'),
      if (b.compteurEauEntree != null || b.compteurEauSortie != null)
        ('Compteur eau', '${b.compteurEauEntree ?? '—'} → ${b.compteurEauSortie ?? '—'}'),
      if (b.compteurElecEntree != null || b.compteurElecSortie != null)
        ('Compteur électricité', '${b.compteurElecEntree ?? '—'} → ${b.compteurElecSortie ?? '—'}'),
      if ((b.remarques ?? '').isNotEmpty) ('Remarques', b.remarques!),
      if ((b.creePar ?? '').isNotEmpty)
        ('Créé par', '${b.creePar}${(b.creeLe ?? '').isEmpty ? '' : ' le ${_dateTexte(b.creeLe!)}'}'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: CarteBail(
        child: Column(
          children: [
            for (final l in lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(l.$1, style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
                    ),
                    Expanded(child: Text(l.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dateTexte(String brut) {
    final d = DateTime.tryParse(brut);
    return d == null ? brut : dateBail(d.toLocal());
  }

  Widget _ligneLoyer(Loyer l) {
    final couleur = CouleursBail.statutLoyer(l.statut);
    return CarteBail(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: () => ouvrirFeuilleLoyer(context, _cubit, l),
      child: Row(
        children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.libelle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                Text('Échéance le ${dateBail(l.echeance)}',
                    style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(montantLisible(l.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (l.paye > 0.004 && l.reste > 0.004)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('reste ${montantLisible(l.reste)}',
                          style: TextStyle(fontSize: 11.5, color: couleur, fontWeight: FontWeight.w600)),
                    ),
                  PastilleBail(texte: libelleStatutLoyer(l.statut), couleur: couleur),
                ],
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: CouleursBail.texteDoux, size: 20),
        ],
      ),
    );
  }
}
