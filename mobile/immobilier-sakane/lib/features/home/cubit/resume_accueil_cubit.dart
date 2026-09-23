import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/resume_accueil.dart';
import 'package:immobilier/repository/repository.dart';

/// L'état du résumé de l'accueil.
///
/// Le résumé est un complément : s'il manque, l'accueil reste utilisable.
/// C'est pourquoi l'erreur n'efface jamais le dernier résumé connu — on
/// préfère un chiffre d'il y a une minute à un écran vide.
class ResumeAccueilState {
  final AppStatus chargement;
  final ResumeAccueil? resume;
  final String? erreur;

  const ResumeAccueilState({
    this.chargement = AppStatus.unknown,
    this.resume,
    this.erreur,
  });

  /// Vrai la première fois seulement : le squelette ne revient pas à
  /// chaque rafraîchissement.
  bool get premierChargement =>
      resume == null && chargement == AppStatus.loading;

  bool get enErreur => chargement == AppStatus.error;

  ResumeAccueilState copyWith({
    AppStatus? chargement,
    ResumeAccueil? resume,
    String? erreur,
  }) {
    return ResumeAccueilState(
      chargement: chargement ?? this.chargement,
      resume: resume ?? this.resume,
      erreur: erreur,
    );
  }
}

class ResumeAccueilCubit extends Cubit<ResumeAccueilState> {
  ResumeAccueilCubit() : super(const ResumeAccueilState());

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(state.copyWith(chargement: AppStatus.loading));
    try {
      final resume = await _depot.resumeAccueil();
      if (isClosed) return;
      emit(ResumeAccueilState(
        chargement: AppStatus.success,
        resume: resume,
      ));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(
        chargement: AppStatus.error,
        erreur: ex.toString().replaceFirst('Exception: ', '').trim(),
      ));
    }
  }
}
