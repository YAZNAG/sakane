part of 'login_bloc.dart';


@immutable
abstract class LoginEvent {}

/// Connexion classique : un identifiant (e-mail ou telephone) et un mot
/// de passe.
class LoginSubmitted extends LoginEvent {
	final Manager manager;
	LoginSubmitted(this.manager);
}

/// Connexion par le jeton range dans le coffre de l'appareil, apres que
/// l'empreinte ou le visage a ete reconnu. Aucun mot de passe n'est en jeu :
/// le jeton est simplement presente au serveur, qui l'accepte ou le refuse.
class ConnexionParJeton extends LoginEvent {
	final CompteMemorise compte;
	final String jeton;
	ConnexionParJeton(this.compte, this.jeton);
}
