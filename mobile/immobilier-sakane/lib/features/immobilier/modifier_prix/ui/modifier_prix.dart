import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/immobilier/detail_reservation/ui/components/outils_reservation.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/repository/repository.dart';

/// « Modifier le prix » d'une réservation : seul le prix par nuit change,
/// les dates restent celles du séjour (prolonger / raccourcir pour elles).
///
/// Le serveur recalcule le total, range l'écart dans la caisse de
/// l'opérateur (hausse) ou rembourse depuis elle le trop-perçu (baisse),
/// régénère les contrats et trace la modification dans l'historique.
///
/// [detail] évite un rechargement quand l'écran l'a déjà. Rend le détail
/// à jour, ou null si rien n'a été enregistré.
Future<DetailReservation?> ouvrirModifierPrix(
  BuildContext context,
  int reservation, {
  DetailReservation? detail,
}) async {
  final resultat = await showModalBottomSheet<DetailReservation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FeuilleModifierPrix(reservation: reservation, detail: detail),
  );
  if (resultat == null || !context.mounted) return resultat;
  afficherMessage(context, 'Prix modifié : ${montantLisible(resultat.prixNuit)} / nuit, total ${montantLisible(resultat.montant)}.');
  await proposerNouveauContrat(context, resultat);
  return resultat;
}

class _FeuilleModifierPrix extends StatefulWidget {
  final int reservation;
  final DetailReservation? detail;

  const _FeuilleModifierPrix({required this.reservation, this.detail});

  @override
  State<_FeuilleModifierPrix> createState() => _FeuilleModifierPrixState();
}

class _FeuilleModifierPrixState extends State<_FeuilleModifierPrix> {
  final _prix = TextEditingController();
  final _encaisse = TextEditingController();

  DetailReservation? _detail;
  String? _erreur;
  bool _enregistrement = false;
  bool _rembourser = true;

  /// Tant que l'agent n'a pas touché au montant encaissé, il suit l'écart.
  bool _encaisseSaisi = false;

  Repository get _depot => Dependencies.get<Repository>();

  @override
  void initState() {
    super.initState();
    if (widget.detail != null) {
      _poser(widget.detail!);
    } else {
      _charger();
    }
  }

  @override
  void dispose() {
    _prix.dispose();
    _encaisse.dispose();
    super.dispose();
  }

  void _poser(DetailReservation d) {
    _detail = d;
    _prix.text = d.prixNuit > 0 ? prixSimple(d.prixNuit) : '';
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final d = await _depot.detailReservation(widget.reservation);
      if (mounted) setState(() => _poser(d));
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreur(ex));
    }
  }

  int get _nuits => _detail?.nombreNuits ?? 0;

  double? get _nouveauPrix => lireMontant(_prix.text);

  double? get _nouveauTotal => _nouveauPrix == null ? null : _nouveauPrix! * _nuits;

  double? get _ecart => _nouveauTotal == null || _detail == null ? null : _nouveauTotal! - _detail!.montant;

  /// Ce qui a été payé au-delà du nouveau total.
  double get _tropPercu {
    final total = _nouveauTotal, d = _detail;
    if (total == null || d == null) return 0;
    final t = d.encaisse - total;
    return t > 0.004 ? t : 0;
  }

  void _prixChange(String _) {
    final e = _ecart;
    if (!_encaisseSaisi) {
      _encaisse.text = e != null && e > 0.004 ? prixSimple(double.parse(e.toStringAsFixed(2))) : '';
    }
    setState(() {});
  }

  String? get _problemeEncaisse {
    final e = _ecart;
    if (e == null || e <= 0.004) return null;
    final m = lireMontant(_encaisse.text.isEmpty ? '0' : _encaisse.text);
    if (m == null || m < 0) return 'Montant invalide';
    if (m > e + 0.004) return "Au plus l'écart : ${montantLisible(e)}";
    return null;
  }

  bool get _valide {
    final p = _nouveauPrix, e = _ecart;
    return p != null && p > 0 && e != null && e.abs() > 0.004 && _problemeEncaisse == null;
  }

  Future<void> _enregistrer() async {
    if (!_valide) return;
    final e = _ecart!;
    final rembourse = e < 0 && _rembourser ? _tropPercu : 0.0;
    if (rembourse > 0) {
      final prete = await garantirCaisseOuverte(
        context,
        motif: 'le remboursement du trop-perçu',
        sortie: rembourse,
      );
      if (!prete || !mounted) return;
    }

    setState(() => _enregistrement = true);
    try {
      final resultat = await _depot.modifierPrixReservation(
        widget.reservation,
        prixNuit: _nouveauPrix!,
        encaisse: e > 0 ? (lireMontant(_encaisse.text.isEmpty ? '0' : _encaisse.text) ?? 0) : null,
        rembourser: e < 0 ? _rembourser : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(resultat);
    } catch (ex) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      afficherMessage(context, messageErreur(ex), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
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
                Row(
                  children: [
                    Icon(Icons.price_change_outlined, color: AppColors.primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Modifier le prix',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17262E)),
                      ),
                    ),
                    Text('#${widget.reservation}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_erreur != null)
                  _blocErreur()
                else if (_detail == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _formulaire(_detail!),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _formulaire(DetailReservation d) {
    final total = _nouveauTotal;
    final ecart = _ecart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CouleursCalendrier.fond,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _ligne('Prix actuel par nuit', montantLisible(d.prixNuit)),
              _ligne('Nuits', pluriel(_nuits, 'nuit')),
              _ligne('Total actuel', montantLisible(d.montant), gras: true),
              _ligne('Déjà encaissé', montantLisible(d.encaisse), couleur: CouleursCalendrier.paye),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _prix,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: _prixChange,
          decoration: InputDecoration(
            labelText: 'Nouveau prix par nuit',
            suffixText: 'MAD',
            prefixIcon: const Icon(Icons.sell_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        _ligne('Nouveau total', total == null ? '—' : montantLisible(total), gras: true),
        _ligne(
          'Différence',
          ecart == null ? '—' : '${ecart > 0 ? '+' : ecart < 0 ? '−' : ''}${montantLisible(ecart.abs())}',
          couleur: ecart == null || ecart.abs() <= 0.004
              ? CouleursCalendrier.texteDoux
              : ecart > 0
                  ? CouleursCalendrier.paye
                  : CouleursCalendrier.partiel,
          gras: true,
        ),
        if (ecart != null && ecart.abs() <= 0.004 && _nouveauPrix != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text("Le prix n'a pas changé.",
                style: TextStyle(fontSize: 12.5, color: CouleursCalendrier.texteDoux)),
          ),
        if (ecart != null && ecart > 0.004) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _encaisse,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() => _encaisseSaisi = true),
            decoration: InputDecoration(
              labelText: 'Montant encaissé maintenant',
              suffixText: 'MAD',
              errorText: _problemeEncaisse,
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ce montant sera ajouté à votre caisse.',
            style: TextStyle(fontSize: 12, color: CouleursCalendrier.texteDoux),
          ),
        ],
        if (ecart != null && ecart < -0.004) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _rembourser,
            activeThumbColor: AppColors.primaryColor,
            onChanged: (v) => setState(() => _rembourser = v),
            title: const Text('Rembourser le trop-perçu depuis ma caisse', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              _tropPercu > 0
                  ? 'Trop-perçu : ${montantLisible(_tropPercu)}'
                  : 'Aucun trop-perçu : rien à rembourser.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'Les contrats seront régénérés avec l\'ancien et le nouveau prix.',
          style: TextStyle(fontSize: 11.5, color: CouleursCalendrier.texteDoux),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _enregistrement || !_valide ? null : _enregistrer,
            icon: _enregistrement
                ? const SizedBox(
                    width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 19),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ligne(String libelle, String valeur, {bool gras = false, Color? couleur}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            Expanded(
              child: Text(libelle, style: const TextStyle(fontSize: 13, color: CouleursCalendrier.texteDoux)),
            ),
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
