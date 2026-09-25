part of 'login_bloc.dart';


class LoginState {
	AppStatus? loginStatus;
	String? error;
	bool? isOffline;
	Manager? manager;

	/// Le compte tel qu'il vient d'etre memorise : l'ecran en a besoin pour
	/// proposer le deverrouillage rapide au bon compte.
	CompteMemorise? compte;

	/// Vrai quand la connexion s'est faite par le jeton du coffre : dans ce
	/// cas il n'y a rien a proposer, le raccourci existe deja.
	bool? parJeton;

	/// Vrai quand le serveur a refuse le jeton memorise : session expiree,
	/// mot de passe change, ou compte supprime cote serveur. L'ecran doit
	/// alors effacer ce jeton et redemander le mot de passe.
	bool? jetonInvalide;

	LoginState({
		this.loginStatus,
		this.error,
		this.isOffline,
		this.manager,
		this.compte,
		this.parJeton,
		this.jetonInvalide,
	});

	LoginState copyWith({
		AppStatus? loginStatus,
		String? error,
		bool? isOffline,
		Manager? manager,
		CompteMemorise? compte,
		bool? parJeton,
		bool? jetonInvalide,
	}) {
		return LoginState(
			loginStatus: loginStatus ?? this.loginStatus,
			error: error ,
			isOffline: isOffline ,
			manager: manager ?? this.manager,
			compte: compte ?? this.compte,
			// Ces deux indications ne valent que pour l'emission en cours :
			// elles ne doivent pas survivre a l'essai suivant.
			parJeton: parJeton ,
			jetonInvalide: jetonInvalide ,
		);
	}

}
