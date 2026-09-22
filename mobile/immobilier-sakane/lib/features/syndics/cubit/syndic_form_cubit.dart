import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/repository/repository.dart';

class SyndicFormState {
  final AppStatus? biensStatus;
  final List<BienDuSyndic>? biens;

  /// Statut de l'enregistrement : il déclenche un message ou la sortie de
  /// l'écran, il ne se conserve pas.
  final AppStatus? saveStatus;
  final Syndic? enregistre;
  final String? error;

  const SyndicFormState({
    this.biensStatus,
    this.biens,
    this.saveStatus,
    this.enregistre,
    this.error,
  });

  SyndicFormState copyWith({
    AppStatus? biensStatus,
    List<BienDuSyndic>? biens,
    AppStatus? saveStatus,
    Syndic? enregistre,
    String? error,
  }) {
    return SyndicFormState(
      biensStatus: biensStatus ?? this.biensStatus,
      biens: biens ?? this.biens,
      saveStatus: saveStatus,
      enregistre: enregistre ?? this.enregistre,
      error: error,
    );
  }
}

/// Création ou modification d'un syndic et choix de ses biens.
class SyndicFormCubit extends Cubit<SyndicFormState> {
  SyndicFormCubit() : super(const SyndicFormState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> chargerBiens() async {
    emit(state.copyWith(biensStatus: AppStatus.loading));
    try {
      final biens = await _repository.fetchBiensPourSyndic();
      if (isClosed) return;
      emit(state.copyWith(biensStatus: AppStatus.success, biens: biens));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(biensStatus: AppStatus.error, error: messageErreurSyndic(ex)));
    }
  }

  Future<void> enregistrer({
    int? id,
    required String nom,
    required String telephone,
    required bool actif,
    String? notes,
    required List<int> biens,
  }) async {
    emit(state.copyWith(saveStatus: AppStatus.loading));
    try {
      final syndic = await _repository.enregistrerSyndic(
        id: id,
        nom: nom,
        telephone: telephone,
        actif: actif,
        notes: notes,
        biens: biens,
      );
      if (isClosed) return;
      emit(state.copyWith(saveStatus: AppStatus.success, enregistre: syndic));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(saveStatus: AppStatus.error, error: messageErreurSyndic(ex)));
    }
  }
}
