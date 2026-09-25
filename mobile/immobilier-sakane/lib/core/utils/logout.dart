import 'package:flutter/material.dart';

import '../../routes.dart';
import '../dependencies/dependencies.dart';
import '../offline/cache_lecture.dart';
import '../offline/synchronisation.dart';
import '../services/service_biometrie.dart';
import '../services/shared_pref_service.dart';


void logout(){
  SharedPrefService sharedPrefService=Dependencies.get<SharedPrefService>();
  sharedPrefService.removeRecord(SharedPrefService.token);
  // Le compte reste dans la liste des comptes memorises : on revient vite
  // dessus, sans retaper son adresse. Son jeton de deverrouillage, lui,
  // disparait : une session fermee ne doit pas se rouvrir d'un doigt.
  final identifiant =
      sharedPrefService.getValue<String>(SharedPrefService.username, "");
  if (identifiant.trim().isNotEmpty) {
    ServiceBiometrie.instance.oublierJeton(identifiant);
  }
  // Les donnees consultees ne restent pas visibles pour le compte suivant.
  // Les actions en attente, elles, sont conservees : elles partiront a la
  // prochaine connexion du meme compte.
  CacheLecture.vider();
  final router=Routes.router;
  while(router.canPop()){
    router.pop();
  }
  router.replace(Routes.login);
}

/// Deconnexion demandee par l'utilisateur : prevenir s'il reste des
/// actions qui ne sont pas encore arrivees sur le serveur.
Future<void> demanderDeconnexion() async {
  final attente = Synchronisation.instance.nombreEnAttente;
  final contexte = Routes.router.routerDelegate.navigatorKey.currentContext;

  if (attente > 0 && contexte != null) {
    final confirme = await showDialog<bool>(
      context: contexte,
      builder: (ctx) => AlertDialog(
        title: const Text("Actions non envoyées"),
        content: Text(
          "$attente action${attente > 1 ? 's' : ''} n'${attente > 1 ? 'ont' : 'a'} pas encore été "
          "envoyée${attente > 1 ? 's' : ''} au serveur.\n\n"
          "Elle${attente > 1 ? 's' : ''} partir${attente > 1 ? 'ont' : 'a'} automatiquement quand vous vous "
          "reconnecterez avec ce compte, avec du réseau.\n\nSe déconnecter quand même ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Se déconnecter"),
          ),
        ],
      ),
    );
    if (confirme != true) return;
  }

  logout();
}
