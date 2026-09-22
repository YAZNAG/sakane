import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';
import 'package:immobilier/repository/repository.dart';

class AirbnbBiensState {
  final AppStatus? statut;
  final String? erreur;
  final List<BienAirbnb>? biens;

  const AirbnbBiensState({this.statut, this.erreur, this.biens});
}

/// Vue d'ensemble : tous les biens et leur liaison Airbnb.
class AirbnbBiensCubit extends Cubit<AirbnbBiensState> {
  AirbnbBiensCubit() : super(const AirbnbBiensState());

  Future<void> charger() async {
    // Au rafraichissement, la liste deja affichee reste visible.
    emit(AirbnbBiensState(statut: AppStatus.loading, biens: state.biens));
    try {
      final biens = await Dependencies.get<Repository>().fetchBiensAirbnb();
      // Relies d'abord (erreurs en tete), puis par titre.
      int rang(BienAirbnb b) => !b.relie ? 2 : (b.enErreur ? 0 : 1);
      biens.sort((a, b) {
        final r = rang(a).compareTo(rang(b));
        return r != 0 ? r : a.titre.toLowerCase().compareTo(b.titre.toLowerCase());
      });
      if (isClosed) return;
      emit(AirbnbBiensState(statut: AppStatus.success, biens: biens));
    } catch (ex) {
      if (isClosed) return;
      emit(AirbnbBiensState(statut: AppStatus.error, erreur: messageErreur(ex), biens: state.biens));
    }
  }
}
