import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/repository/repository.dart';

/// Filtre de la liste : actif, termine, tous, impayes ou finissants (60 jours).
class BauxState {
  final AppStatus? statutTableau;
  final TableauBaux? tableau;
  final String? erreurTableau;

  final AppStatus? statutListe;
  final List<Bail>? baux;
  final String? erreurListe;
  final String filtre;
  final String recherche;

  final AppStatus? statutBiens;
  final List<BienLongueDuree>? biens;
  final String? erreurBiens;

  const BauxState({
    this.statutTableau,
    this.tableau,
    this.erreurTableau,
    this.statutListe,
    this.baux,
    this.erreurListe,
    this.filtre = 'actif',
    this.recherche = '',
    this.statutBiens,
    this.biens,
    this.erreurBiens,
  });

  BauxState copyWith({
    AppStatus? statutTableau,
    TableauBaux? tableau,
    String? erreurTableau,
    AppStatus? statutListe,
    List<Bail>? baux,
    String? erreurListe,
    String? filtre,
    String? recherche,
    AppStatus? statutBiens,
    List<BienLongueDuree>? biens,
    String? erreurBiens,
  }) {
    return BauxState(
      statutTableau: statutTableau ?? this.statutTableau,
      tableau: tableau ?? this.tableau,
      erreurTableau: erreurTableau ?? this.erreurTableau,
      statutListe: statutListe ?? this.statutListe,
      baux: baux ?? this.baux,
      erreurListe: erreurListe ?? this.erreurListe,
      filtre: filtre ?? this.filtre,
      recherche: recherche ?? this.recherche,
      statutBiens: statutBiens ?? this.statutBiens,
      biens: biens ?? this.biens,
      erreurBiens: erreurBiens ?? this.erreurBiens,
    );
  }
}

class BauxCubit extends Cubit<BauxState> {
  BauxCubit({String filtre = 'actif'}) : super(BauxState(filtre: filtre));

  Repository get _depot => Dependencies.get<Repository>();

  /// Numero de la derniere recherche : une reponse lente ne remplace pas une plus recente.
  int _requete = 0;

  Future<void> toutCharger() => Future.wait([chargerTableau(), chargerBaux(), chargerBiens()]);

  Future<void> chargerTableau({bool silencieux = false}) async {
    if (!silencieux || state.tableau == null) {
      emit(state.copyWith(statutTableau: AppStatus.loading));
    }
    try {
      final tableau = await _depot.fetchTableauBaux();
      if (isClosed) return;
      emit(state.copyWith(statutTableau: AppStatus.success, tableau: tableau));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statutTableau: AppStatus.error, erreurTableau: messageErreurBail(ex)));
    }
  }

  Future<void> chargerBaux({bool silencieux = false}) async {
    final numero = ++_requete;
    if (!silencieux || state.baux == null) {
      emit(state.copyWith(statutListe: AppStatus.loading));
    }
    try {
      final impayes = state.filtre == 'impayes';
      final finissants = state.filtre == 'finissants';
      var baux = await _depot.fetchBaux(
        statut: impayes ? 'tous' : (finissants ? 'actif' : state.filtre),
        recherche: state.recherche,
        impayes: impayes,
      );
      // Les baux actifs qui se terminent dans les 60 jours, le plus proche d'abord.
      if (finissants) {
        baux = baux.where((b) => b.joursRestants != null && b.joursRestants! <= 60).toList()
          ..sort((a, b) => a.joursRestants!.compareTo(b.joursRestants!));
      }
      if (isClosed || numero != _requete) return;
      emit(state.copyWith(statutListe: AppStatus.success, baux: baux));
    } catch (ex) {
      if (isClosed || numero != _requete) return;
      emit(state.copyWith(statutListe: AppStatus.error, erreurListe: messageErreurBail(ex)));
    }
  }

  Future<void> chargerBiens({bool silencieux = false}) async {
    if (!silencieux || state.biens == null) {
      emit(state.copyWith(statutBiens: AppStatus.loading));
    }
    try {
      final biens = await _depot.fetchBiensLongueDuree();
      if (isClosed) return;
      emit(state.copyWith(statutBiens: AppStatus.success, biens: biens));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statutBiens: AppStatus.error, erreurBiens: messageErreurBail(ex)));
    }
  }

  void changerFiltre(String filtre) {
    if (filtre == state.filtre) return;
    emit(state.copyWith(filtre: filtre));
    chargerBaux(silencieux: true);
  }

  void rechercher(String texte) {
    if (texte.trim() == state.recherche.trim()) return;
    emit(state.copyWith(recherche: texte));
    chargerBaux(silencieux: true);
  }

  /// Apres une creation ou une modification : tout suit, sans indicateur.
  Future<void> actualiser() =>
      Future.wait([chargerTableau(silencieux: true), chargerBaux(silencieux: true), chargerBiens(silencieux: true)]);
}
