import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/types_invites.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/detail_reservation/cubit/detail_reservation_cubit.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/components/outils_reservation.dart';
import 'package:immobilier/features/immobilier/facture/ui/appliquer_facture.dart';
import 'package:immobilier/features/immobilier/facture/ui/facture.dart';
import 'package:immobilier/features/immobilier/modifier_prix/ui/modifier_prix.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/routes.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tout sur une réservation : séjour, montants, facture, contrats,
/// historique des modifications et mouvements de caisse.
///
/// Rend vrai en se refermant si la réservation a été modifiée ici :
/// la liste d'origine se rafraîchit alors.
class DetailReservationPage extends StatefulWidget {
  const DetailReservationPage({super.key});

  static Widget page(int id) {
    return BlocProvider<DetailReservationCubit>(
      create: (_) => DetailReservationCubit(id)..charger(),
      child: const DetailReservationPage(),
    );
  }

  /// Ouvre le détail ; rend vrai si la réservation a changé.
  static Future<bool> ouvrir(BuildContext context, int id) async {
    final modifie = await GoRouter.of(context)
        .push<bool>(Routes.detailReservation.replaceFirst(':id', id.toString()));
    return modifie == true;
  }

  @override
  State<DetailReservationPage> createState() => _DetailReservationPageState();
}

class _DetailReservationPageState extends State<DetailReservationPage> {
  DetailReservationCubit get _cubit => context.read<DetailReservationCubit>();

  bool get _peutModifierPrix => peut(AppPermission.updateReservationPrice);

  /// Facture appliquée : il faut le droit de la voir ; sinon, celui de
  /// l'appliquer.
  bool _peutFacture(DetailReservation d) =>
      _factureAppliquee(d) ? peut(AppPermission.viewInvoice) : peut(AppPermission.applyInvoice);

  Future<void> _rafraichir() async {
    final erreur = await _cubit.rafraichir();
    if (erreur != null && mounted) afficherMessage(context, erreur, erreur: true);
  }

  Future<void> _modifierPrix(DetailReservation d) async {
    final nouveau = await ouvrirModifierPrix(context, d.id, detail: d);
    if (nouveau != null && mounted) _cubit.remplacer(nouveau);
  }

  Future<void> _appliquerFacture(DetailReservation d) async {
    final resume = await ouvrirAppliquerFacture(context, d.id);
    if (resume != null && mounted) await _cubit.apresModification();
  }

  Future<void> _voirFacture(DetailReservation d) async {
    final appliquee = await ouvrirFacture(context, d.id);
    if (appliquee && mounted) await _cubit.apresModification();
  }

  bool _factureAppliquee(DetailReservation d) => d.facture?.appliquee ?? false;

  Future<void> _lancer(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception();
    } catch (_) {
      if (mounted) afficherMessage(context, 'Action impossible sur cet appareil', erreur: true);
    }
  }

  void _whatsapp(String tel) {
    var chiffres = tel.replaceAll(RegExp(r'\D'), '');
    if (chiffres.startsWith('00')) chiffres = chiffres.substring(2);
    if (chiffres.startsWith('0')) chiffres = '212${chiffres.substring(1)}';
    _lancer(Uri.parse('https://wa.me/$chiffres'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetailReservationCubit, DetailReservationState>(
      builder: (context, state) {
        return PopScope<bool>(
          canPop: false,
          onPopInvokedWithResult: (dejaFait, _) {
            if (!dejaFait) Navigator.of(context).pop(state.modifie);
          },
          child: Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Text(
                'Réservation #${state.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              foregroundColor: Colors.white,
              backgroundColor: AppColors.primaryColor,
              elevation: 0,
              centerTitle: true,
              actions: [
                if (state.detail != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: Colors.white,
                    onSelected: (v) {
                      final d = state.detail!;
                      if (v == 'prix') _modifierPrix(d);
                      if (v == 'facture') {
                        // Appliquee : on la consulte ; sinon on l'applique.
                        _factureAppliquee(d) ? _voirFacture(d) : _appliquerFacture(d);
                      }
                    },
                    itemBuilder: (_) => [
                      if (_peutModifierPrix && !state.detail!.supprimee)
                        const PopupMenuItem(value: 'prix', child: Text('Modifier le prix')),
                      if (_peutFacture(state.detail!))
                      PopupMenuItem(
                        value: 'facture',
                        child: Text(_factureAppliquee(state.detail!) ? 'Facture' : 'Appliquer la facture'),
                      ),
                    ],
                  ),
              ],
            ),
            body: _corps(state),
          ),
        );
      },
    );
  }

  Widget _corps(DetailReservationState state) {
    if (state.statut == AppStatus.error && state.detail == null) {
      return MyErrorWidget(
        error: state.erreur ?? 'Erreur',
        action: AppStrings.tryAgain,
        actionCLick: _cubit.charger,
      );
    }
    final d = state.detail;
    if (d == null) return Center(child: MyLoadingIndicator());

    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          _entete(d),
          if (d.client != null) ...[
            const SizedBox(height: 12),
            _client(d.client!),
          ],
          const SizedBox(height: 12),
          _sejour(d),
          const SizedBox(height: 12),
          _montants(d),
          const SizedBox(height: 12),
          _actions(d),
          const SizedBox(height: 12),
          _facture(d),
          if (d.contratPublic != null || d.contratPrive != null) ...[
            const SizedBox(height: 12),
            _contrats(d),
          ],
          const SizedBox(height: 12),
          _historique(d),
          const SizedBox(height: 12),
          _caisse(d),
          if ((d.remarques ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            _carte(
              titre: 'Remarques',
              icone: Icons.sticky_note_2_outlined,
              enfant: Text(d.remarques!, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF5D4037))),
            ),
          ],
        ],
      ),
    );
  }

  // ── Blocs ───────────────────────────────────────────────────────

  Widget _carte({required String titre, required IconData icone, required Widget enfant, Widget? droite}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 19, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titre,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              if (droite != null) droite,
            ],
          ),
          const SizedBox(height: 10),
          enfant,
        ],
      ),
    );
  }

  Widget _entete(DetailReservation d) {
    final bien = d.bien;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_work_outlined, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (bien?.titre ?? '').isEmpty ? 'Bien' : bien!.titre,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
          if ((bien?.adresse ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(bien!.adresse!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if ((d.statutNom ?? d.statutCode ?? '').isNotEmpty)
                PastilleReservation(texte: d.statutNom ?? d.statutCode!, couleur: const Color(0xFF546E7A)),
              if (d.airbnb)
                const PastilleReservation(
                    texte: 'Airbnb', couleur: Color(0xFFFF5A5F), icone: FontAwesomeIcons.airbnb),
              if (d.modifiee)
                const PastilleReservation(
                    texte: 'Modifiée', couleur: Color(0xFF6153C9), icone: Icons.edit_note),
              if (d.supprimee)
                const PastilleReservation(
                    texte: 'Supprimée', couleur: CouleursCalendrier.erreur, icone: Icons.delete_outline),
              if (d.facture != null)
                PastilleReservation(
                  texte: d.facture!.appliquee
                      ? 'Facture appliquée${d.facture!.numero == null ? '' : ' N° ${d.facture!.numero}'}'
                      : 'Facture non appliquée',
                  couleur: d.facture!.appliquee ? CouleursCalendrier.paye : CouleursCalendrier.texteDoux,
                ),
            ],
          ),
          if ((d.creePar ?? '').isNotEmpty || d.creeLe != null) ...[
            const SizedBox(height: 8),
            Text(
              'Créée${(d.creePar ?? '').isNotEmpty ? ' par ${d.creePar}' : ''}'
              '${d.creeLe != null ? ' le ${dateHeureFr(d.creeLe)}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _client(ClientReservation c) {
    final tel = (c.tel ?? '').trim();
    return _carte(
      titre: 'Client',
      icone: Icons.person_outline,
      droite: c.listeNoire
          ? const PastilleReservation(texte: 'Liste noire', couleur: CouleursCalendrier.erreur, icone: Icons.block)
          : null,
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: c.id == null
                ? null
                : () => GoRouter.of(context).push(Routes.clientDetail.replaceFirst(':id', c.id.toString())),
            child: Row(
              children: [
                Expanded(
                  child: Text(c.nom.isEmpty ? 'Client' : c.nom,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                ),
                if (c.id != null) Icon(Icons.arrow_forward_ios, size: 15, color: Colors.grey.shade400),
              ],
            ),
          ),
          if ((c.cin ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('CIN : ${c.cin}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          ],
          if (tel.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 18, color: CouleursCalendrier.texteDoux),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
                ),
                _rond(Icons.call, const Color(0xFF1E88E5), 'Appeler',
                    () => _lancer(Uri(scheme: 'tel', path: tel.replaceAll(' ', '')))),
                const SizedBox(width: 8),
                _rond(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), 'WhatsApp', () => _whatsapp(tel)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rond(IconData icone, Color couleur, String aide, VoidCallback onTap) => Material(
        color: couleur.withValues(alpha: .12),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: aide,
          onPressed: onTap,
          icon: FaIcon(icone, color: couleur, size: 20),
        ),
      );

  Widget _sejour(DetailReservation d) {
    Widget date(String libelle, DateTime? jour, String? heure, IconData icone, {bool droite = false}) => Column(
          crossAxisAlignment: droite ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 15, color: Colors.purple.shade700),
                const SizedBox(width: 4),
                Text(libelle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 3),
            Text(jour == null ? '—' : dateMoyenne(jour),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
            Text(
              '${jour == null ? '' : joursFr[jour.weekday - 1]}'
              '${heureCourte(heure).isEmpty ? '' : ' • ${heureCourte(heure)}'}',
              style: const TextStyle(fontSize: 12, color: CouleursCalendrier.texteDoux),
            ),
          ],
        );

    return _carte(
      titre: 'Séjour',
      icone: Icons.date_range,
      enfant: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Row(
              children: [
                Expanded(child: date('Arrivée', d.checkin, d.heureArrivee, Icons.login)),
                Column(
                  children: [
                    const Icon(Icons.arrow_forward, size: 18, color: CouleursCalendrier.texteDoux),
                    Text(pluriel(d.nombreNuits, 'nuit'),
                        style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux)),
                  ],
                ),
                Expanded(child: date('Départ', d.checkout, d.heureDepart, Icons.logout, droite: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ligne('Personnes', d.personnes > 0 ? pluriel(d.personnes, 'personne') : '—'),
          if ((d.typeInvite ?? '').isNotEmpty) _ligne('Type', TypeInvite.libelleDe(d.typeInvite)),
        ],
      ),
    );
  }

  Widget _montants(DetailReservation d) {
    return _carte(
      titre: 'Montants',
      icone: Icons.payments_outlined,
      enfant: Column(
        children: [
          SizedBox(width: double.infinity, child: _montant('Total', d.montant, CouleursCalendrier.texte)),
          const SizedBox(height: 8),
          _ligne('Prix par nuit', montantLisible(d.prixNuit)),
          _ligne('Avance', montantLisible(d.avance)),
          _ligne('Caution', montantLisible(d.caution)),
        ],
      ),
    );
  }

  Widget _montant(String libelle, double valeur, Color couleur) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: CouleursCalendrier.bordure),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(libelle, style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(montantLisible(valeur),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: couleur)),
            ),
          ],
        ),
      );

  Widget _actions(DetailReservation d) {
    final boutons = <Widget>[
      if (_peutModifierPrix && !d.supprimee)
        _bouton(Icons.price_change_outlined, 'Modifier le prix', AppColors.primaryColor, () => _modifierPrix(d)),
      if (_peutFacture(d))
      _factureAppliquee(d)
          ? _bouton(Icons.receipt_long, 'Facture', const Color(0xFF2F6B4F), () => _voirFacture(d))
          : _bouton(Icons.request_quote_outlined, 'Appliquer la facture', const Color(0xFF2F6B4F),
              () => _appliquerFacture(d)),
    ];
    return Column(children: boutons);
  }

  Widget _bouton(IconData icone, String texte, Color couleur, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: couleur.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(icone, color: couleur, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(texte, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: couleur)),
                  ),
                  Icon(Icons.chevron_right, color: couleur.withValues(alpha: .7)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _facture(DetailReservation d) {
    final f = d.facture;
    final appliquee = f?.appliquee ?? false;
    return _carte(
      titre: 'Facture',
      icone: Icons.receipt_long,
      droite: f == null
          ? null
          : PastilleReservation(
              texte: appliquee ? 'Appliquée${f.numero == null ? '' : ' N° ${f.numero}'}' : 'Non appliquée',
              couleur: appliquee ? CouleursCalendrier.paye : CouleursCalendrier.texteDoux,
              icone: appliquee ? Icons.check_circle : Icons.edit_note,
            ),
      enfant: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f != null) ...[
            if (appliquee && f.numero != null) _ligne('Numéro', f.numero!),
            _ligne('Montant H.T', montantFacture(f.ht)),
            _ligne('TVA (${prixSimple(f.taux)} %)', montantFacture(f.tva)),
            _ligne('Montant T.T.C', montantFacture(f.ttc)),
            if (appliquee && f.tvaIncluse)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'TVA comprise dans le total de la réservation',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CouleursCalendrier.paye),
                ),
              )
            else if (appliquee && f.tvaEncaissee > 0.004)
              _ligne('TVA encaissée', montantFacture(f.tvaEncaissee)),
            if (appliquee && (f.appliqueeLe != null || (f.appliqueePar ?? '').isNotEmpty))
              _ligne(
                'Appliquée',
                [
                  if (f.appliqueeLe != null) 'le ${dateHeureFr(f.appliqueeLe)}',
                  if ((f.appliqueePar ?? '').isNotEmpty) 'par ${f.appliqueePar}',
                ].join(' '),
              ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (!appliquee && peut(AppPermission.applyInvoice))
                ElevatedButton.icon(
                  onPressed: () => _appliquerFacture(d),
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('Appliquer la facture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              // Une seule entree : appliquer, ou consulter une fois appliquee.
              if (appliquee && peut(AppPermission.viewInvoice))
                ElevatedButton.icon(
                  onPressed: () => _voirFacture(d),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Facture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              if (appliquee && peut(AppPermission.viewInvoice))
                OutlinedButton.icon(
                  onPressed: () => telechargerFacture(context, d.id),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Télécharger'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contrats(DetailReservation d) {
    Widget bouton(IconData icone, String titre, String url) => OutlinedButton.icon(
          onPressed: () => ouvrirContratDistant(context, url, titre: titre),
          icon: Icon(icone, size: 18),
          label: Text(titre, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryColor,
            side: BorderSide(color: AppColors.primaryColor.withValues(alpha: .5)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
    return _carte(
      titre: 'Contrats',
      icone: Icons.description_outlined,
      enfant: Row(
        children: [
          if (d.contratPublic != null) Expanded(child: bouton(Icons.public, 'Contrat public', d.contratPublic!)),
          if (d.contratPublic != null && d.contratPrive != null) const SizedBox(width: 8),
          if (d.contratPrive != null) Expanded(child: bouton(Icons.lock_outline, 'Contrat privé', d.contratPrive!)),
        ],
      ),
    );
  }

  Widget _historique(DetailReservation d) {
    return _carte(
      titre: 'Historique des modifications',
      icone: Icons.history,
      enfant: d.modifications.isEmpty
          ? Text('Aucune modification.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
          : Column(
              children: [
                for (int i = 0; i < d.modifications.length; i++)
                  _etape(d.modifications[i], dernier: i == d.modifications.length - 1),
              ],
            ),
    );
  }

  /// Une étape de la frise : pastille, trait, puis le résumé.
  Widget _etape(ModificationReservation m, {required bool dernier}) {
    final (IconData icone, Color couleur) = m.estPrix
        ? (Icons.sell_outlined, AppColors.primaryColor)
        : m.estProlongation
            ? (Icons.more_time, const Color(0xFF2E7D32))
            : (Icons.timelapse, const Color(0xFFD97E1A));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: couleur.withValues(alpha: .14),
                  child: Icon(icone, size: 15, color: couleur),
                ),
                if (!dernier)
                  Expanded(child: Container(width: 2, color: CouleursCalendrier.bordure)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: dernier ? 0 : 14, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_titreModification(m),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: couleur)),
                  const SizedBox(height: 2),
                  Text(_resumeModification(m),
                      style: const TextStyle(fontSize: 12.5, height: 1.35, color: CouleursCalendrier.texte)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((m.par ?? '').isNotEmpty) 'par ${m.par}',
                      if (m.date != null) dateHeureFr(m.date),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _titreModification(ModificationReservation m) {
    if (m.estPrix) return m.typeLibelle ?? 'Modification du prix';
    if (m.estProlongation) return '${m.typeLibelle ?? 'Prolongation'} +${m.nuitsDelta.abs()} j';
    if (m.estRaccourcissement) return '${m.typeLibelle ?? 'Raccourcissement'} -${m.nuitsDelta.abs()} j';
    return m.typeLibelle ?? m.type;
  }

  /// « 30 → 300 MAD/nuit · total 90 → 900 MAD · +810 MAD encaissés »
  String _resumeModification(ModificationReservation m) {
    String n(double? v) => v == null ? '?' : prixSimple(v);
    final morceaux = <String>[];
    if (m.estPrix || (m.ancienPrixNuit != null && m.nouveauPrixNuit != null && m.ancienPrixNuit != m.nouveauPrixNuit)) {
      morceaux.add('${n(m.ancienPrixNuit)} → ${n(m.nouveauPrixNuit)} MAD/nuit');
    }
    if (!m.estPrix && (m.ancienCheckout != null || m.nouveauCheckout != null)) {
      morceaux.add('départ ${m.ancienCheckout == null ? '?' : dateCourte(m.ancienCheckout!)}'
          ' → ${m.nouveauCheckout == null ? '?' : dateCourte(m.nouveauCheckout!)}');
    }
    if (m.ancienTotal != null || m.nouveauTotal != null) {
      morceaux.add('total ${n(m.ancienTotal)} → ${n(m.nouveauTotal)} MAD');
    }
    if (m.encaisse > 0.004) morceaux.add('+${prixSimple(m.encaisse)} MAD encaissés');
    if (m.rembourse > 0.004) morceaux.add('${prixSimple(m.rembourse)} MAD remboursés');
    if (m.encaisse <= 0.004 && m.rembourse <= 0.004 && m.ecart.abs() > 0.004) {
      morceaux.add('écart ${m.ecart > 0 ? '+' : '−'}${prixSimple(m.ecart.abs())} MAD');
    }
    return morceaux.isEmpty ? '—' : morceaux.join(' · ');
  }

  Widget _caisse(DetailReservation d) {
    return _carte(
      titre: 'Mouvements de caisse',
      icone: Icons.account_balance_wallet_outlined,
      enfant: d.paiements.isEmpty
          ? Text('Aucun mouvement.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
          : Column(
              children: [
                for (final p in d.paiements)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          p.estSortie ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 18,
                          color: p.estSortie ? CouleursCalendrier.nonPaye : CouleursCalendrier.paye,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.libelle ?? (p.estSortie ? 'Sortie' : 'Entrée'),
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
                              Text(
                                [
                                  if (p.date != null) dateHeureFr(p.date),
                                  if ((p.par ?? '').isNotEmpty) 'par ${p.par}',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${p.estSortie ? '−' : '+'}${montantLisible(p.montant)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: p.estSortie ? CouleursCalendrier.nonPaye : CouleursCalendrier.paye,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _ligne(String libelle, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(libelle, style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texteDoux))),
            Flexible(
              child: Text(valeur,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
            ),
          ],
        ),
      );
}
