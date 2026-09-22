import 'dart:async';

import 'package:flutter/material.dart';

/// Tient un écran à jour sans que l'utilisateur ait à le quitter.
///
/// Trois déclencheurs, complémentaires :
///  - le retour de l'application au premier plan ;
///  - un rafraîchissement périodique, tant que l'écran est affiché ;
///  - un signal émis après toute écriture, pour que les autres écrans
///    ouverts reflètent immédiatement le changement.
///
/// L'écran reste utilisable pendant le rechargement : la liste se met à
/// jour en place, sans indicateur de chargement imposé.
mixin RafraichissementAuto<T extends StatefulWidget> on State<T> {
  Timer? _minuteur;
  StreamSubscription<String>? _abonnement;
  _ObservateurCycle? _observateur;
  DateTime _dernier = DateTime.fromMillisecondsSinceEpoch(0);

  /// Recharge les données de l'écran.
  void rafraichir();

  /// Intervalle entre deux rafraîchissements automatiques.
  Duration get intervalleRafraichissement => const Duration(seconds: 45);

  /// Délai minimal entre deux rechargements : plusieurs signaux
  /// rapprochés ne doivent pas multiplier les appels au serveur.
  Duration get delaiMinimal => const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _observateur = _ObservateurCycle(_demander);
    WidgetsBinding.instance.addObserver(_observateur!);
    _minuteur = Timer.periodic(intervalleRafraichissement, (_) => _demander());
    _abonnement = SignalDonnees.flux.listen((_) => _demander());
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _abonnement?.cancel();
    if (_observateur != null) {
      WidgetsBinding.instance.removeObserver(_observateur!);
    }
    super.dispose();
  }

  void _demander() {
    if (!mounted) return;
    final maintenant = DateTime.now();
    if (maintenant.difference(_dernier) < delaiMinimal) return;
    _dernier = maintenant;
    rafraichir();
  }
}

/// Prévient au retour de l'application au premier plan.
class _ObservateurCycle extends WidgetsBindingObserver {
  final VoidCallback surReprise;

  _ObservateurCycle(this.surReprise);

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) surReprise();
  }
}

/// Signale qu'une donnée a changé, pour que les écrans déjà ouverts se
/// remettent à jour sans attendre leur prochain cycle.
class SignalDonnees {
  static final StreamController<String> _controleur =
      StreamController<String>.broadcast();

  static Stream<String> get flux => _controleur.stream;

  /// À appeler après toute écriture réussie.
  /// [sujet] sert à la lisibilité : « réservation », « charge »...
  static void modifie(String sujet) {
    if (!_controleur.isClosed) _controleur.add(sujet);
  }
}
