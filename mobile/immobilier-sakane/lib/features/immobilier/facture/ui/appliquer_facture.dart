import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/components/outils_reservation.dart';
import 'package:immobilier/features/immobilier/facture/ui/facture.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/repository/repository.dart';

/// « Appliquer la facture » : le total de la réservation est le montant
/// H.T, la TVA s'y ajoute. Appliquer est définitif : la TVA entre dans
/// la caisse de l'utilisateur connecté et dans les statistiques, et la
/// facture ne peut plus que se voir ou se télécharger.
///
/// Rend le résumé si la facture vient d'être appliquée, sinon null.
Future<ResumeFacture?> ouvrirAppliquerFacture(BuildContext context, int reservation) async {
  ResumeFacture? appliquee;
  final action = await showModalBottomSheet<_Action>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FeuilleAppliquerFacture(reservation: reservation, onAppliquee: (r) => appliquee = r),
  );
  if (!context.mounted) return appliquee;

  final r = appliquee;
  if (r != null) {
    afficherMessage(
      context,
      'Facture${r.numero == null ? '' : ' N° ${r.numero}'} appliquée'
      '${r.tvaEncaissee > 0.004 ? ' : ${montantFacture(r.tvaEncaissee)} de TVA ajoutés à votre caisse' : ''}.',
    );
  }
  // Le document, demandé depuis la feuille.
  if (action == _Action.voir) {
    await ouvrirFacture(context, reservation);
  } else if (action == _Action.telecharger) {
    await telechargerFacture(context, reservation);
  }
  return r;
}

enum _Action { voir, telecharger }

class _FeuilleAppliquerFacture extends StatefulWidget {
  final int reservation;

  /// Prévient l'appelant dès que la facture est appliquée, même si la
  /// feuille est ensuite refermée d'un geste.
  final ValueChanged<ResumeFacture> onAppliquee;

  const _FeuilleAppliquerFacture({required this.reservation, required this.onAppliquee});

  @override
  State<_FeuilleAppliquerFacture> createState() => _FeuilleAppliquerFactureState();
}

class _FeuilleAppliquerFactureState extends State<_FeuilleAppliquerFacture> {
  final _cle = GlobalKey<FormState>();
  final _taux = TextEditingController();
  final _nom = TextEditingController();
  final _ice = TextEditingController();
  final _adresse = TextEditingController();

  ResumeFacture? _resume;
  String? _erreur;

  /// Message du serveur après un refus (déjà appliquée, par exemple).
  String? _avertissement;
  bool _chargement = true;
  bool _enregistrement = false;

  Repository get _depot => Dependencies.get<Repository>();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _taux.dispose();
    _nom.dispose();
    _ice.dispose();
    _adresse.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final r = await _depot.resumeFacture(widget.reservation);
      if (!mounted) return;
      setState(() {
        _resume = r;
        _taux.text = prixSimple(r.taux);
        _nom.text = r.clientNom;
        _ice.text = r.clientIce ?? '';
        _adresse.text = r.clientAdresse ?? '';
        _chargement = false;
      });
    } catch (ex) {
      if (!mounted) return;
      setState(() {
        _erreur = messageErreur(ex);
        _chargement = false;
      });
    }
  }

  double? get _tauxSaisi => lireMontant(_taux.text);

  bool get _tauxValide {
    final t = _tauxSaisi;
    return t != null && t >= 0 && t <= 30;
  }

  double _tvaCalculee(ResumeFacture r) => _tauxValide ? r.ht * _tauxSaisi! / 100 : 0;

  void _fermer({_Action? action}) => Navigator.of(context).pop(action);

  Future<void> _appliquer() async {
    final r = _resume;
    if (r == null || r.appliquee || !(_cle.currentState?.validate() ?? false)) return;

    final tva = _tvaCalculee(r);
    final ok = await confirmer(
      context,
      titre: 'Appliquer la facture ?',
      message:
          'Une facture appliquée ne peut plus être modifiée.\n\n'
          'Montant T.T.C : ${montantFacture(r.ht + tva)}'
          '${tva > 0.004 ? '\nTVA ajoutée à votre caisse : ${montantFacture(tva)}' : ''}',
      action: 'Appliquer',
      couleur: AppColors.primaryColor,
    );
    if (!ok || !mounted) return;

    // Meme verification que pour toute operation de caisse.
    final prete = await garantirCaisseOuverte(context, motif: "l'application de cette facture");
    if (!prete || !mounted) return;

    setState(() {
      _enregistrement = true;
      _avertissement = null;
    });
    try {
      final resultat = await _depot.appliquerFacture(
        widget.reservation,
        tva: _tauxSaisi,
        clientNom: _nom.text.trim(),
        clientIce: _ice.text.trim(),
        clientAdresse: _adresse.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _resume = resultat;
      });
      widget.onAppliquee(resultat);
    } catch (ex) {
      if (!mounted) return;
      setState(() {
        _enregistrement = false;
        _avertissement = messageErreur(ex);
      });
      // Elle a peut-etre ete appliquee entre-temps : on relit l'etat.
      await _recharger();
    }
  }

  /// Relit le résumé sans effacer l'écran.
  Future<void> _recharger() async {
    try {
      final r = await _depot.resumeFacture(widget.reservation);
      if (!mounted) return;
      setState(() => _resume = r);
    } catch (_) {}
  }

  InputDecoration _decoration(String libelle, IconData icone, {String? aide, String? suffixe}) {
    return InputDecoration(
      labelText: libelle,
      helperText: aide,
      suffixText: suffixe,
      prefixIcon: Icon(icone, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PoigneeFeuille(),
                const SizedBox(height: 14),
                _entete(),
                const SizedBox(height: 16),
                if (_avertissement != null) _blocAvertissement(),
                if (_chargement)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_erreur != null)
                  _blocErreur()
                else if (_resume!.appliquee)
                  _etatApplique(_resume!)
                else
                  _formulaire(_resume!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entete() {
    final r = _resume;
    return Row(
      children: [
        Icon(Icons.request_quote_outlined, color: AppColors.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            r != null && r.appliquee ? 'Facture' : 'Appliquer la facture',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
          ),
        ),
        if (r != null)
          PastilleReservation(
            texte: r.appliquee ? 'Appliquée' : 'Non appliquée',
            couleur: r.appliquee ? CouleursCalendrier.paye : CouleursCalendrier.texteDoux,
            icone: r.appliquee ? Icons.check_circle : Icons.edit_note,
          ),
      ],
    );
  }

  Widget _blocAvertissement() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E0),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF3C77A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 19, color: Color(0xFF9A6100)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_avertissement!, style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF7A4D00))),
        ),
      ],
    ),
  );

  Widget _blocErreur() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(Icons.error_outline, color: CouleursCalendrier.erreur, size: 36),
        const SizedBox(height: 8),
        Text(_erreur!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _charger,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Réessayer'),
        ),
      ],
    ),
  );

  /// Facture déjà appliquée : on ne peut plus que la voir ou la télécharger.
  Widget _etatApplique(ResumeFacture r) {
    final details = [
      if (r.numero != null) 'N° ${r.numero}',
      if (r.appliqueeLe != null) 'le ${dateHeureFr(r.appliqueeLe)}',
      if ((r.appliqueePar ?? '').isNotEmpty) 'par ${r.appliqueePar}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CouleursCalendrier.paye.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CouleursCalendrier.paye.withValues(alpha: .35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, color: CouleursCalendrier.paye, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Facture appliquée${details.isEmpty ? '' : ' — ${details.join(', ')}'}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F6B3F),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: CouleursCalendrier.fond, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              _ligne('Montant H.T', montantFacture(r.ht)),
              _ligne('TVA (${prixSimple(r.taux)} %)', montantFacture(r.tva)),
              _ligne('Montant T.T.C', montantFacture(r.ttc), gras: true),
              const Divider(height: 18, color: CouleursCalendrier.bordure),
              // Appliquee a la creation : la TVA etait deja dans le
              // total, rien de plus n'est entre en caisse.
              if (r.tvaIncluse)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TVA comprise dans le total de la réservation',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CouleursCalendrier.paye),
                  ),
                )
              else
                _ligne('TVA encaissée', montantFacture(r.tvaEncaissee), couleur: CouleursCalendrier.paye),
            ],
          ),
        ),
        if (r.clientNom.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Facturée à ${r.clientNom}${(r.clientIce ?? '').isNotEmpty ? ' — ICE ${r.clientIce}' : ''}',
            style: const TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _fermer(action: _Action.voir),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Voir'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _fermer(action: _Action.telecharger),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Télécharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _formulaire(ResumeFacture r) {
    final tva = _tvaCalculee(r);
    final ttc = r.ht + tva;

    return Form(
      key: _cle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: CouleursCalendrier.fond, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _ligne('Montant H.T (total de la réservation)', montantFacture(r.ht)),
                _ligne(
                  'TVA${_tauxValide ? ' (${prixSimple(_tauxSaisi!)} %)' : ''}',
                  _tauxValide ? montantFacture(tva) : '—',
                ),
                _ligne('Montant T.T.C', _tauxValide ? montantFacture(ttc) : '—', gras: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Nom du client ou de la société', Icons.person_outline),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Indiquez à qui la facture est adressée' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ice,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'ICE du client (facultatif)',
              Icons.badge_outlined,
              aide: 'Pour facturer une société',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _adresse,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
            decoration: _decoration('Adresse (facultatif)', Icons.location_on_outlined),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _taux,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Taux de TVA (%)', Icons.percent, suffixe: '%', aide: '20 % par défaut'),
            validator: (v) {
              final t = lireMontant(v ?? '');
              if (t == null) return 'Indiquez le taux (20 par défaut)';
              if (t < 0 || t > 30) return 'Le taux doit être compris entre 0 et 30 %';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 17, color: CouleursCalendrier.texteDoux),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'La TVA (${_tauxValide ? montantFacture(tva) : '—'}) sera ajoutée à votre caisse '
                  'et aux statistiques. Le contrat garde son montant.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: CouleursCalendrier.texteDoux,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enregistrement ? null : _appliquer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 19),
              label: const Text('Appliquer la facture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // L'apercu reste consultable avant d'appliquer.
          Center(
            child: TextButton.icon(
              onPressed: _enregistrement ? null : () => _fermer(action: _Action.voir),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text("Voir l'aperçu"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String libelle, String valeur, {bool gras = false, Color? couleur}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      children: [
        Expanded(
          child: Text(libelle, style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texteDoux)),
        ),
        const SizedBox(width: 8),
        Text(
          valeur,
          style: TextStyle(
            fontSize: gras ? 15 : 13,
            fontWeight: gras ? FontWeight.w800 : FontWeight.w600,
            color: couleur ?? CouleursCalendrier.texte,
          ),
        ),
      ],
    ),
  );
}
