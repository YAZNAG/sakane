import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/repository/repository.dart';

class BailFormState {
  final AppStatus? statutBiens;
  final List<BienLongueDuree>? biens;
  final String? erreurBiens;
  final AppStatus? statutEnvoi;
  final String? erreurEnvoi;
  final Bail? cree;
  final String? avertissement;

  const BailFormState({
    this.statutBiens,
    this.biens,
    this.erreurBiens,
    this.statutEnvoi,
    this.erreurEnvoi,
    this.cree,
    this.avertissement,
  });

  BailFormState copyWith({
    AppStatus? statutBiens,
    List<BienLongueDuree>? biens,
    String? erreurBiens,
    AppStatus? statutEnvoi,
    String? erreurEnvoi,
    Bail? cree,
    String? avertissement,
  }) {
    return BailFormState(
      statutBiens: statutBiens ?? this.statutBiens,
      biens: biens ?? this.biens,
      erreurBiens: erreurBiens ?? this.erreurBiens,
      statutEnvoi: statutEnvoi ?? this.statutEnvoi,
      erreurEnvoi: erreurEnvoi,
      cree: cree ?? this.cree,
      avertissement: avertissement ?? this.avertissement,
    );
  }
}

/// Creation d'un bail : les logements proposes, puis l'envoi.
class BailFormCubit extends Cubit<BailFormState> {
  BailFormCubit() : super(const BailFormState());

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> chargerBiens() async {
    emit(state.copyWith(statutBiens: AppStatus.loading));
    try {
      final biens = await _depot.fetchBiensLongueDuree();
      if (isClosed) return;
      emit(state.copyWith(statutBiens: AppStatus.success, biens: biens));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statutBiens: AppStatus.error, erreurBiens: messageErreurBail(ex)));
    }
  }

  Future<void> creer({
    required int bien,
    required int client,
    required DateTime dateDebut,
    required DateTime dateFin,
    required double loyer,
    double? charges,
    double? depot,
    required bool depotRecu,
    String? compteurEauEntree,
    String? compteurElecEntree,
    String? remarques,
    required bool relancesActives,
    required bool envoyerContrat,
    required List<File> photos,
    required List<Colocataire> colocataires,
    required List<File> cinPhotos,
  }) async {
    if (state.statutEnvoi == AppStatus.loading) return;
    emit(state.copyWith(statutEnvoi: AppStatus.loading));
    try {
      final res = await _depot.creerBail(
        bien: bien,
        client: client,
        dateDebut: dateDebut,
        dateFin: dateFin,
        loyer: loyer,
        charges: charges,
        depot: depot,
        depotRecu: depotRecu,
        compteurEauEntree: compteurEauEntree,
        compteurElecEntree: compteurElecEntree,
        remarques: remarques,
        relancesActives: relancesActives,
        envoyerContrat: envoyerContrat,
        photos: photos,
        colocataires: colocataires,
        cinPhotos: cinPhotos,
      );
      if (isClosed) return;
      emit(state.copyWith(statutEnvoi: AppStatus.success, cree: res.valeur, avertissement: res.avertissement));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statutEnvoi: AppStatus.error, erreurEnvoi: messageErreurBail(ex)));
    }
  }
}
