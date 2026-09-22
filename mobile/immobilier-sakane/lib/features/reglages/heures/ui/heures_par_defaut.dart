import 'package:flutter/material.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/detail_reservation.dart';
import 'package:immobilier/repository/repository.dart';

/// « Heures par défaut » : l'heure d'arrivée et de départ proposées
/// à chaque nouvelle réservation et portées au contrat.
///
/// Seul un administrateur peut les changer ; le serveur reste juge (403).
class HeuresParDefautPage extends StatefulWidget {
  const HeuresParDefautPage({super.key});

  @override
  State<HeuresParDefautPage> createState() => _HeuresParDefautPageState();
}

class _HeuresParDefautPageState extends State<HeuresParDefautPage> {
  HeuresParDefaut? _heures;
  String? _erreur;
  bool _enregistrement = false;

  Repository get _depot => Dependencies.get<Repository>();

  /// Droit « Modifier les heures par défaut ».
  bool get _admin => peut(AppPermission.setDefaultHours);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _erreur = null;
      _heures = null;
    });
    try {
      final h = await _depot.heuresParDefaut();
      if (mounted) setState(() => _heures = h);
    } catch (ex) {
      if (mounted) setState(() => _erreur = messageErreur(ex));
    }
  }

  static TimeOfDay _lire(String h, TimeOfDay defaut) {
    final p = h.split(':');
    if (p.length < 2) return defaut;
    final heure = int.tryParse(p[0]), minute = int.tryParse(p[1]);
    if (heure == null || minute == null) return defaut;
    return TimeOfDay(hour: heure, minute: minute);
  }

  static String _format(TimeOfDay h) =>
      '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

  Future<void> _choisir({required bool arrivee}) async {
    final h = _heures;
    if (h == null || _enregistrement) return;
    final actuelle = arrivee
        ? _lire(h.arrivee, const TimeOfDay(hour: 14, minute: 0))
        : _lire(h.depart, const TimeOfDay(hour: 12, minute: 0));
    final choisie = await showTimePicker(
      context: context,
      initialTime: actuelle,
      helpText: arrivee ? "Heure d'arrivée par défaut" : 'Heure de départ par défaut',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (choisie == null || !mounted || choisie == actuelle) return;

    setState(() => _enregistrement = true);
    try {
      final nouvelles = await _depot.enregistrerHeuresParDefaut(
        arrivee: arrivee ? _format(choisie) : null,
        depart: arrivee ? null : _format(choisie),
      );
      if (!mounted) return;
      setState(() {
        _heures = nouvelles;
        _enregistrement = false;
      });
      afficherMessage(context, arrivee ? "Heure d'arrivée enregistrée." : 'Heure de départ enregistrée.');
    } catch (ex) {
      if (!mounted) return;
      setState(() => _enregistrement = false);
      afficherMessage(context, messageErreur(ex), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Heures par défaut', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (_erreur != null) {
      return MyErrorWidget(error: _erreur!, action: AppStrings.tryAgain, actionCLick: _charger);
    }
    final h = _heures;
    if (h == null) return Center(child: MyLoadingIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Ces heures sont proposées à chaque nouvelle réservation et figurent au contrat "
          "lorsque l'agent n'en saisit pas d'autres.",
          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        _tuile("Heure d'arrivée", h.arrivee, Icons.login, () => _choisir(arrivee: true)),
        const SizedBox(height: 10),
        _tuile('Heure de départ', h.depart, Icons.logout, () => _choisir(arrivee: false)),
        if (_enregistrement) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        if (!_admin) ...[
          const SizedBox(height: 16),
          Text(
            'Seul un administrateur peut modifier ces heures.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _tuile(String libelle, String valeur, IconData icone, VoidCallback onTap) {
    final actif = _admin && !_enregistrement;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: actif ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CouleursCalendrier.bordure),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryColor.withValues(alpha: .1),
                child: Icon(icone, color: AppColors.primaryColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(libelle,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: CouleursCalendrier.texte)),
              ),
              Text(valeur,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor)),
              if (actif) ...[
                const SizedBox(width: 6),
                const Icon(Icons.edit, size: 18, color: CouleursCalendrier.texteDoux),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
