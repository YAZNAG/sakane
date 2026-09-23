import 'package:bloc/bloc.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/apercu_famille.dart';
import 'package:immobilier/repository/repository.dart';

part 'apercu_famille_state.dart';

/// L'aperçu d'une famille de biens : les quatre compteurs, les arrivées
/// et les départs du jour.
///
/// Le comptage et le tri sont au serveur : cet état ne fait que porter
/// sa réponse. L'écran reste utilisable si elle manque — les compteurs
/// se replient alors sur la liste des biens déjà chargée.
class ApercuFamilleCubit extends Cubit<ApercuFamilleState> {
  ApercuFamilleCubit(String code) : super(ApercuFamilleState(code: code));

  Repository get _depot => Dependencies.get<Repository>();

  /// Premier chargement : le squelette est visible pendant la lecture.
  Future<void> charger() async {
    emit(state.copyWith(chargement: true, erreur: null));
    try {
      final apercu = await _depot.apercuFamille(state.code);
      emit(state.copyWith(chargement: false, apercu: apercu, erreur: null));
    } catch (ex) {
      emit(state.copyWith(chargement: false, erreur: messageErreur(ex)));
    }
  }

  /// Relecture sans masquer ce qui est déjà affiché (tirer-pour-rafraîchir).
  Future<String?> rafraichir() async {
    if (state.apercu == null) {
      await charger();
      return state.erreur;
    }
    try {
      final apercu = await _depot.apercuFamille(state.code);
      emit(state.copyWith(apercu: apercu, erreur: null));
      return null;
    } catch (ex) {
      return messageErreur(ex);
    }
  }

  /// Confirme l'arrivée du client dans un bien, puis relit l'aperçu.
  Future<String?> confirmerArrivee(int bienId) =>
      _agir((d) => d.confirmCheckin(bienId));

  /// Confirme le départ du client d'un bien, puis relit l'aperçu.
  Future<String?> confirmerDepart(int bienId) =>
      _agir((d) => d.confirmDepart(bienId));

  Future<String?> _agir(Future<void> Function(Repository depot) action) async {
    if (state.enCours) return 'Une opération est déjà en cours.';
    emit(state.copyWith(enCours: true));
    try {
      await action(_depot);
    } catch (ex) {
      emit(state.copyWith(enCours: false));
      return messageErreur(ex);
    }
    await rafraichir();
    emit(state.copyWith(enCours: false));
    return null;
  }
}
