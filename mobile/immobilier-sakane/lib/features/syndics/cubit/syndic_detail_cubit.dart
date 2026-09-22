import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/repository/repository.dart';

class SyndicDetailState {
  final AppStatus? fetchStatus;

  /// Statut de la suppression : il déclenche un message, il ne se
  /// conserve pas d'un état à l'autre.
  final AppStatus? deleteStatus;
  final Syndic? syndic;
  final String? error;

  const SyndicDetailState({this.fetchStatus, this.deleteStatus, this.syndic, this.error});

  SyndicDetailState copyWith({
    AppStatus? fetchStatus,
    AppStatus? deleteStatus,
    Syndic? syndic,
    String? error,
  }) {
    return SyndicDetailState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      deleteStatus: deleteStatus,
      syndic: syndic ?? this.syndic,
      error: error,
    );
  }
}

/// La fiche d'un syndic, historique des envois compris.
class SyndicDetailCubit extends Cubit<SyndicDetailState> {
  final int id;

  SyndicDetailCubit(this.id) : super(const SyndicDetailState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux || state.syndic == null) {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
    }
    try {
      final syndic = await _repository.fetchSyndic(id);
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.success, syndic: syndic));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.error, error: messageErreurSyndic(ex)));
    }
  }

  Future<void> supprimer() async {
    emit(state.copyWith(deleteStatus: AppStatus.loading));
    try {
      await _repository.supprimerSyndic(id);
      if (isClosed) return;
      emit(state.copyWith(deleteStatus: AppStatus.success));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(deleteStatus: AppStatus.error, error: messageErreurSyndic(ex)));
    }
  }
}
