part of 'login_bloc.dart';


class LoginState {
	AppStatus? loginStatus;
	String? error;
	bool? isOffline;
	Manager? manager;

	LoginState({
		this.loginStatus,
		this.error,
		this.isOffline,
		this.manager,
	});

	LoginState copyWith({
		AppStatus? loginStatus,
		String? error,
		bool? isOffline,
		Manager? manager,
	}) {
		return LoginState(
			loginStatus: loginStatus ?? this.loginStatus,
			error: error ,
			isOffline: isOffline ,
			manager: manager ?? this.manager,
		);
	}

}
