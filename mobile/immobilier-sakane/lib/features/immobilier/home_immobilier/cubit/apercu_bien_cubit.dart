import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/apercu_bien.dart';
import 'package:immobilier/repository/repository.dart';

part 'apercu_bien_state.dart';

/// L'aperçu d'un bien pour sa page de gestion : référence, état du jour,
/// séjour en cours, liaison Airbnb.
///
/// Il complète la fiche complète du bien (chargée par [HomeImmobilierCubit])
/// plutôt qu'il ne la remplace : si cette lecture-ci échoue, la page reste
/// entière, seuls les repères du jour manquent.
class ApercuBienCubit extends Cubit<ApercuBienState> {
  ApercuBienCubit(int bienId) : super(ApercuBienState(bienId: bienId));

  Repository get _depot => Dependencies.get<Repository>();

  /// Premier chargement : le squelette est visible pendant la lecture.
  Future<void> charger() async {
    emit(state.copyWith(chargement: true, erreur: null));
    try {
      final apercu = await _depot.apercuBien(state.bienId);
      emit(state.copyWith(chargement: false, apercu: apercu, erreur: null));
    } catch (ex) {
      emit(state.copyWith(chargement: false, erreur: messageErreur(ex)));
    }
  }

  /// Relecture sans masquer ce qui est déjà affiché (tirer-pour-rafraîchir,
  /// retour d'un écran qui a pu changer l'état du bien).
  Future<String?> rafraichir() async {
    if (state.apercu == null) {
      await charger();
      return state.erreur;
    }
    try {
      final apercu = await _depot.apercuBien(state.bienId);
      emit(state.copyWith(apercu: apercu, erreur: null));
      return null;
    } catch (ex) {
      return messageErreur(ex);
    }
  }
}
