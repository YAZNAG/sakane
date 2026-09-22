import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/manager.dart';

export 'package:immobilier/core/constants/enums/permissions.dart';

/// Raccourcis pour tester les droits de l'utilisateur connecté.
///
/// L'administrateur a tous les droits ; pour les autres, ce sont les droits
/// effectifs renvoyés par le serveur (rôle + accordés − retirés). Le serveur
/// reste juge : il répond 403 si un droit manque.
Manager? get _connecte {
  try {
    return Dependencies.get<Manager>();
  } catch (_) {
    return null;
  }
}

/// Vrai si l'utilisateur connecté a ce droit.
bool peut(AppPermission droit) => _connecte?.can(droit) ?? false;

/// Vrai si l'utilisateur connecté a au moins un de ces droits.
bool peutUn(Iterable<AppPermission> droits) => _connecte?.canAny(droits) ?? false;

/// Vrai si l'utilisateur connecté est administrateur.
bool get estAdministrateur => _connecte?.isAdmin ?? false;
