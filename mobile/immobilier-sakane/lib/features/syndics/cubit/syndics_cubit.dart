import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/repository/repository.dart';

class SyndicsState {
  final AppStatus? fetchStatus;
  final List<Syndic>? syndics;
  final String? error;

  const SyndicsState({this.fetchStatus, this.syndics, this.error});

  SyndicsState copyWith({AppStatus? fetchStatus, List<Syndic>? syndics, String? error}) {
    return SyndicsState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      syndics: syndics ?? this.syndics,
      error: error,
    );
  }
}

/// La liste des syndics de l'agence.
class SyndicsCubit extends Cubit<SyndicsState> {
  SyndicsCubit() : super(const SyndicsState());

  Repository get _repository => Dependencies.get<Repository>();

  /// [silencieux] recharge sans remplacer la liste par un indicateur :
  /// au retour d'une fiche, l'utilisateur attend la liste à jour.
  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux || state.syndics == null) {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
    }
    try {
      final syndics = await _repository.fetchSyndics();
      emit(state.copyWith(fetchStatus: AppStatus.success, syndics: syndics));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.error, error: messageErreurSyndic(ex)));
    }
  }
}
