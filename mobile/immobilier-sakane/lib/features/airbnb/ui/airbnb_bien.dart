import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/airbnb/cubit/airbnb_bien_cubit.dart';
import 'package:immobilier/features/airbnb/ui/components/carte_reservation_airbnb.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:share_plus/share_plus.dart';

/// Liaison d'un bien avec son annonce Airbnb, dans les deux sens.
class AirbnbBienPage extends StatefulWidget {
  final int bienId;
  final String? titre;

  const AirbnbBienPage({super.key, required this.bienId, this.titre});

  static Widget page(int bienId, {String? titre}) {
    return BlocProvider(
      create: (_) => AirbnbBienCubit(bienId)..charger(),
      child: AirbnbBienPage(bienId: bienId, titre: titre),
    );
  }

  @override
  State<AirbnbBienPage> createState() => _AirbnbBienPageState();
}

class _AirbnbBienPageState extends State<AirbnbBienPage> {
  final _url = TextEditingController();
  final bool _peutModifier = peutGererAirbnb();
  final bool _peutSynchroniser = peutSynchroniserAirbnb();
  String? _urlAffichee;

  AirbnbBienCubit get _cubit => context.read<AirbnbBienCubit>();

  @override
  void initState() {
    super.initState();
    _url.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// Le champ suit le lien enregistre sur le serveur.
  void _suivreLien(LienAirbnb? lien) {
    final url = lien?.urlImport ?? '';
    if (lien == null || url == _urlAffichee) return;
    _urlAffichee = url;
    _url.text = url;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AirbnbBienCubit, AirbnbBienState>(
      listenWhen: (a, b) => a.lien != b.lien,
      listener: (_, state) => _suivreLien(state.lien),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: CouleursCalendrier.fond,
          appBar: AppBar(
            title: const Text('Airbnb', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            elevation: 0,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            bottom: state.enCours != null
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3, color: Colors.white, backgroundColor: Colors.transparent),
                  )
                : null,
          ),
          body: _corps(state),
        );
      },
    );
  }

  Widget _corps(AirbnbBienState state) {
    final lien = state.lien;
    if (lien == null) {
      if (state.statut == AppStatus.error) {
        return Center(
          child: MyErrorWidget(
            error: state.erreur ?? "La liaison Airbnb n'a pas pu être chargée.",
            action: 'Réessayer',
            actionCLick: () => _cubit.charger(),
          ),
        );
      }
      return Center(child: MyLoadingIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => _cubit.charger(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _entete(lien),
          const SizedBox(height: 14),
          _etapeImport(state, lien),
          const SizedBox(height: 14),
          _etapeExport(state, lien),
          const SizedBox(height: 14),
          _sejours(lien),
          if (_peutModifier && lien.relie) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: state.enCours != null ? null : _delier,
              icon: _icone(state, ActionAirbnb.delier, Icons.link_off),
              label: const Text('Délier d’Airbnb'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CouleursCalendrier.erreur,
                side: BorderSide(color: CouleursCalendrier.erreur.withValues(alpha: .45)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── En-tete ──────────────────────────────────────────────────────

  Widget _entete(LienAirbnb lien) {
    final titre = (widget.titre ?? '').trim();
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CouleursAirbnb.rose.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const FaIcon(FontAwesomeIcons.airbnb, color: CouleursAirbnb.rose, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre.isEmpty ? 'Bien #${widget.bienId}' : titre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
              const SizedBox(height: 2),
              const Text('Calendriers synchronisés dans les deux sens',
                  style: TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Etape 1 : Airbnb -> application ──────────────────────────────

  Widget _etapeImport(AirbnbBienState state, LienAirbnb lien) {
    final occupe = state.enCours != null;
    return _carte(
      numero: 1,
      titre: 'Airbnb → application',
      children: [
        const Text(
          'Les réservations et les dates bloquées sur Airbnb rendent le bien indisponible ici. '
          'Mise à jour automatique toutes les 15 minutes.',
          style: TextStyle(fontSize: 13, height: 1.4, color: CouleursCalendrier.texteDoux),
        ),
        const SizedBox(height: 12),
        if (_peutModifier)
          TextField(
            controller: _url,
            enabled: !occupe,
            keyboardType: TextInputType.url,
            autocorrect: false,
            maxLines: 1,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Lien du calendrier Airbnb',
              hintText: 'https://www.airbnb.fr/calendar/ical/…',
              isDense: true,
              prefixIcon: const Icon(Icons.link, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Coller',
                icon: const Icon(Icons.content_paste, size: 20),
                onPressed: occupe ? null : _coller,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )
        else
          _lienTexte(lien.relie ? lien.urlImport! : 'Aucun lien enregistré'),
        const SizedBox(height: 10),
        _etatImport(lien),
        if (_peutModifier || _peutSynchroniser) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (_peutModifier)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: occupe || _url.text.trim().isEmpty || _url.text.trim() == (lien.urlImport ?? '')
                      ? null
                      : _enregistrer,
                  icon: _icone(state, ActionAirbnb.enregistrer, Icons.save_outlined, blanc: true),
                  label: const Text('Enregistrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CouleursAirbnb.rose,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_peutModifier && _peutSynchroniser) const SizedBox(width: 8),
              if (_peutSynchroniser)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: occupe || !lien.relie ? null : _synchroniser,
                  icon: _icone(state, ActionAirbnb.synchroniser, Icons.sync),
                  label: const FittedBox(child: Text('Synchroniser maintenant')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CouleursCalendrier.texte,
                    side: const BorderSide(color: CouleursCalendrier.bordure),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        _aide('Où trouver ce lien ?', const [
          'Sur Airbnb, ouvrez « Annonces » et choisissez l’annonce de ce bien.',
          'Ouvrez « Disponibilité », puis « Synchronisation des calendriers » (ou « Connecter des calendriers »).',
          'Touchez « Exporter le calendrier ».',
          'Touchez « Copier le lien », puis collez-le ici.',
        ], note: 'Fonctionne aussi avec le lien de calendrier d’une annonce Booking.com.'),
      ],
    );
  }

  Widget _etatImport(LienAirbnb lien) {
    if (!lien.relie) {
      return _etat(Icons.link_off, 'Pas encore relié', CouleursCalendrier.texteDoux);
    }
    if (lien.enErreur) {
      final quand = lien.derniereSyncA == null ? '' : ' (${ilYA(lien.derniereSyncA!)})';
      return _etat(Icons.cancel, '${lien.erreur ?? 'La dernière synchronisation a échoué.'}$quand',
          CouleursCalendrier.erreur);
    }
    if (lien.derniereSyncA != null) {
      final texte = ilYA(lien.derniereSyncA!);
      return _etat(Icons.check_circle, 'Synchronisé $texte', CouleursAirbnb.succes);
    }
    return _etat(Icons.schedule, 'Relié, en attente de la première synchronisation', CouleursCalendrier.texteDoux);
  }

  // ── Etape 2 : application -> Airbnb ──────────────────────────────

  Widget _etapeExport(AirbnbBienState state, LienAirbnb lien) {
    final aLien = lien.lienExport.isNotEmpty;
    return _carte(
      numero: 2,
      titre: 'Application → Airbnb',
      children: [
        const Text(
          'Les réservations, dates bloquées et baux de longue durée saisis ici sont envoyés à Airbnb '
          '(sans le nom des clients).',
          style: TextStyle(fontSize: 13, height: 1.4, color: CouleursCalendrier.texteDoux),
        ),
        const SizedBox(height: 12),
        _lienTexte(aLien ? lien.lienExport : 'Lien indisponible'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: aLien ? () => _copier(lien.lienExport) : null,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier le lien'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CouleursCalendrier.texte,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: aLien ? () => _partager(lien.lienExport) : null,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Partager'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CouleursCalendrier.texte,
                  side: const BorderSide(color: CouleursCalendrier.bordure),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        lien.derniereLectureAirbnbA != null
            ? _etat(Icons.check_circle, 'Airbnb a lu ce calendrier ${ilYA(lien.derniereLectureAirbnbA!)}',
                CouleursAirbnb.succes)
            : _etat(Icons.schedule, 'Airbnb ne l’a pas encore lu', CouleursCalendrier.texteDoux),
        const SizedBox(height: 4),
        _aide('Comment l’ajouter sur Airbnb ?', const [
          'Copiez le lien ci-dessus.',
          'Sur Airbnb, retournez dans « Disponibilité » > « Synchronisation des calendriers » de l’annonce.',
          'Touchez « Importer un calendrier » et collez le lien.',
          'Nommez le calendrier « $nomApplicationAirbnb », puis validez.',
        ], note: 'Airbnb relit ce lien de lui-même, en général toutes les quelques heures.'),
        if (_peutModifier)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: state.enCours != null ? null : _nouveauLien,
              icon: _icone(state, ActionAirbnb.nouveauLien, Icons.autorenew),
              label: const Text('Générer un nouveau lien'),
              style: TextButton.styleFrom(foregroundColor: CouleursCalendrier.texteDoux),
            ),
          ),
      ],
    );
  }

  // ── Sejours a venir ──────────────────────────────────────────────

  Widget _sejours(LienAirbnb lien) {
    final sejours = lien.sejoursAVenir;
    return _carte(
      titre: 'Séjours Airbnb à venir',
      icone: FontAwesomeIcons.airbnb,
      children: [
        if (sejours.isEmpty)
          Text(
            lien.relie ? 'Aucun séjour à venir sur Airbnb.' : 'Reliez le bien pour voir ses séjours Airbnb.',
            style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texteDoux),
          )
        else
          for (int i = 0; i < sejours.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: CouleursCalendrier.bordure),
            // Une reservation peut devenir un contrat ; un blocage non.
            if (sejours[i].estReservation)
              CarteReservationAirbnb(
                sejour: sejours[i],
                bienId: widget.bienId,
                afficherBien: false,
                aPlat: true,
                onChange: () {
                  if (mounted) _cubit.charger();
                },
              )
            else
              _sejour(sejours[i]),
          ],
      ],
    );
  }

  Widget _sejour(SejourAirbnb s) {
    final lien = s.lien ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(color: CouleursAirbnb.sejour(s), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dateCourte(s.du)} → ${dateMoyenne(s.au)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CouleursCalendrier.texte)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(pluriel(s.nuits, 'nuit'),
                        style: const TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux)),
                    PastilleAirbnb(sejour: s),
                  ],
                ),
              ],
            ),
          ),
          if (lien.isNotEmpty)
            IconButton(
              tooltip: 'Ouvrir sur Airbnb',
              onPressed: () => ouvrirSurAirbnb(context, lien),
              icon: const Icon(Icons.open_in_new, color: CouleursAirbnb.rose, size: 20),
            ),
        ],
      ),
    );
  }

  // ── Elements communs ─────────────────────────────────────────────

  Widget _carte({int? numero, required String titre, IconData? icone, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CouleursCalendrier.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: CouleursAirbnb.rose, shape: BoxShape.circle),
                child: numero != null
                    ? Text('$numero',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))
                    : FaIcon(icone, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(titre,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: CouleursCalendrier.texte)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _lienTexte(String texte) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: CouleursCalendrier.fond,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CouleursCalendrier.bordure),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18, color: CouleursCalendrier.texteDoux),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texte)),
          ),
        ],
      ),
    );
  }

  Widget _etat(IconData icone, String texte, Color couleur) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 17, color: couleur),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texte, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: couleur)),
        ),
      ],
    );
  }

  Widget _aide(String titre, List<String> etapes, {String? note}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        dense: true,
        leading: const Icon(Icons.help_outline, size: 20, color: CouleursCalendrier.texteDoux),
        title: Text(titre,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: CouleursCalendrier.texte)),
        children: [
          for (int i = 0; i < etapes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CouleursAirbnb.rose)),
                  ),
                  Expanded(
                    child: Text(etapes[i],
                        style: const TextStyle(fontSize: 13, height: 1.35, color: CouleursCalendrier.texte)),
                  ),
                ],
              ),
            ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note,
                  style: const TextStyle(
                      fontSize: 12.5, fontStyle: FontStyle.italic, color: CouleursCalendrier.texteDoux)),
            ),
        ],
      ),
    );
  }

  Widget _icone(AirbnbBienState state, ActionAirbnb action, IconData icone, {bool blanc = false}) {
    if (state.enCours == action) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: blanc ? Colors.white : null),
      );
    }
    return Icon(icone, size: 18);
  }

  // ── Actions ──────────────────────────────────────────────────────

  Future<void> _coller() async {
    final donnees = await Clipboard.getData(Clipboard.kTextPlain);
    final texte = (donnees?.text ?? '').trim();
    if (!mounted) return;
    if (texte.isEmpty) {
      afficherMessage(context, 'Le presse-papiers est vide : copiez d’abord le lien sur Airbnb.', erreur: true);
      return;
    }
    _url.text = texte;
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    final url = _url.text.trim();
    if (!url.toLowerCase().startsWith('https://')) {
      afficherMessage(context, 'Le lien doit commencer par https://', erreur: true);
      return;
    }
    final erreur = await _cubit.enregistrer(url);
    if (!mounted) return;
    final lien = _cubit.state.lien;
    if (erreur == null && lien != null && lien.enErreur) {
      afficherMessage(context, 'Lien enregistré, mais la lecture a échoué : ${lien.erreur ?? 'erreur inconnue'}',
          erreur: true);
      return;
    }
    afficherMessage(context, erreur ?? 'Lien enregistré, calendrier Airbnb importé.', erreur: erreur != null);
  }

  Future<void> _synchroniser() async {
    final erreur = await _cubit.synchroniser();
    if (!mounted) return;
    final lien = _cubit.state.lien;
    if (erreur == null && lien != null && lien.enErreur) {
      afficherMessage(context, lien.erreur ?? 'La synchronisation a échoué.', erreur: true);
      return;
    }
    afficherMessage(context, erreur ?? 'Calendrier Airbnb synchronisé.', erreur: erreur != null);
  }

  Future<void> _nouveauLien() async {
    final ok = await confirmer(
      context,
      titre: 'Générer un nouveau lien ?',
      message: 'L’ancien lien cessera aussitôt de fonctionner. Il faudra remplacer, sur Airbnb, '
          'le calendrier importé « $nomApplicationAirbnb » par le nouveau lien.',
      action: 'Générer',
      couleur: CouleursAirbnb.rose,
    );
    if (!ok || !mounted) return;
    final erreur = await _cubit.nouveauLien();
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Nouveau lien généré : pensez à le remplacer sur Airbnb.',
        erreur: erreur != null);
  }

  Future<void> _delier() async {
    final ok = await confirmer(
      context,
      titre: 'Délier d’Airbnb ?',
      message: 'Les séjours Airbnb ne bloqueront plus ce bien dans l’application. '
          'Pensez aussi à retirer le calendrier « $nomApplicationAirbnb » sur Airbnb.',
      action: 'Délier',
      couleur: CouleursCalendrier.erreur,
    );
    if (!ok || !mounted) return;
    final erreur = await _cubit.delier();
    if (!mounted) return;
    afficherMessage(context, erreur ?? 'Le bien n’est plus relié à Airbnb.', erreur: erreur != null);
  }

  Future<void> _copier(String lien) async {
    await Clipboard.setData(ClipboardData(text: lien));
    if (!mounted) return;
    afficherMessage(context, 'Lien copié : collez-le dans « Importer un calendrier » sur Airbnb.');
  }

  Future<void> _partager(String lien) async {
    try {
      await SharePlus.instance.share(ShareParams(text: lien, subject: 'Calendrier $nomApplicationAirbnb'));
    } catch (_) {
      if (mounted) afficherMessage(context, 'Le partage a échoué.', erreur: true);
    }
  }
}
