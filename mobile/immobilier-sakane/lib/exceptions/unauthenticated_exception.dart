/// Le serveur a refuse la session ou les identifiants.
///
/// Le message est celui du serveur quand il en donne un : « identifiant
/// inconnu », « mot de passe incorrect », « compte desactive ». Il est plus
/// juste que n'importe quel texte ecrit dans l'application.
class UnAuthenticatedException implements Exception{
  final String? message;

  UnAuthenticatedException([this.message]);

  @override
  String toString() {
    return message ?? 'UnAuthenticated Exception';
  }
}
