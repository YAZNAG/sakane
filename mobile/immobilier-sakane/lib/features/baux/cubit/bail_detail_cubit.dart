import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/repository/repository.dart';

class BailDetailState {
  final AppStatus? statut;
  final Bail? bail;
  final String? erreur;
  final bool enCours;

  /// Vrai des qu'une ecriture a abouti : la liste appelante se recharge.
  final bool modifie;

  const BailDetailState({this.statut, this.bail, this.erreur, this.enCours = false, this.modifie = false});

  BailDetailState copyWith({AppStatus? statut, Bail? bail, String? erreur, bool? enCours, bool? modifie}) {
    return BailDetailState(
      statut: statut ?? this.statut,
      bail: bail ?? this.bail,
      erreur: erreur,
      enCours: enCours ?? this.enCours,
      modifie: modifie ?? this.modifie,
    );
  }
}

/// Resultat d'une operation : message d'erreur et avertissement du serveur.
typedef ResultatBail = ({String? erreur, String? avertissement});

class BailDetailCubit extends Cubit<BailDetailState> {
  final int id;

  BailDetailCubit(this.id, {Bail? initial}) : super(BailDetailState(bail: initial));

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux || state.bail?.loyers == null) {
      emit(state.copyWith(statut: AppStatus.loading));
    }
    try {
      final bail = await _depot.fetchBail(id);
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.success, bail: bail));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreurBail(ex)));
    }
  }

  /// Execute une ecriture puis recharge la fiche si elle ne l'a pas rendue.
  Future<ResultatBail> _operation(Future<Object?> Function(Repository depot) action) async {
    if (state.enCours) return (erreur: 'Une opération est déjà en cours.', avertissement: null);
    emit(state.copyWith(enCours: true));
    Object? resultat;
    try {
      resultat = await action(_depot);
    } catch (ex) {
      if (!isClosed) emit(state.copyWith(enCours: false));
      return (erreur: messageErreurBail(ex), avertissement: null);
    }
    if (isClosed) return (erreur: null, avertissement: null);

    String? avertissement;
    Bail? bail;
    if (resultat is AvecAvertissement<Bail>) {
      bail = resultat.valeur;
      avertissement = resultat.avertissement;
    } else if (resultat is Bail) {
      bail = resultat;
    } else if (resultat is PaiementEnregistre) {
      avertissement = resultat.avertissement;
    }

    if (bail != null && bail.loyers != null) {
      emit(state.copyWith(bail: bail, enCours: false, modifie: true, statut: AppStatus.success));
    } else {
      try {
        final frais = await _depot.fetchBail(id);
        if (isClosed) return (erreur: null, avertissement: avertissement);
        emit(state.copyWith(bail: frais, enCours: false, modifie: true, statut: AppStatus.success));
      } catch (_) {
        if (!isClosed) emit(state.copyWith(enCours: false, modifie: true));
      }
    }
    return (erreur: null, avertissement: avertissement);
  }

  Future<ResultatBail> modifier({
    String? remarques,
    bool? relancesActives,
    double? loyer,
    double? charges,
    bool depotRecu = false,
    List<Colocataire>? colocataires,
    List<File> cinPhotos = const [],
  }) =>
      _operation((d) => d.modifierBail(
            id,
            remarques: remarques,
            relancesActives: relancesActives,
            loyer: loyer,
            charges: charges,
            depotRecu: depotRecu,
            colocataires: colocataires,
            cinPhotos: cinPhotos,
          ));

  Future<ResultatBail> prolonger({required int mois, double? loyer, bool envoyerContrat = false}) =>
      _operation((d) => d.prolongerBail(id, mois: mois, loyer: loyer, envoyerContrat: envoyerContrat));

  Future<ResultatBail> terminer({
    required DateTime dateSortie,
    String? motif,
    double? depotRendu,
    String? compteurEauSortie,
    String? compteurElecSortie,
  }) =>
      _operation((d) => d.terminerBail(
            id,
            dateSortie: dateSortie,
            motif: motif,
            depotRendu: depotRendu,
            compteurEauSortie: compteurEauSortie,
            compteurElecSortie: compteurElecSortie,
          ));

  /// Rend l'erreur, ou null une fois le bail supprime.
  Future<String?> supprimer() async {
    if (state.enCours) return 'Une opération est déjà en cours.';
    emit(state.copyWith(enCours: true));
    try {
      await _depot.supprimerBail(id);
      if (!isClosed) emit(state.copyWith(enCours: false, modifie: true));
      return null;
    } catch (ex) {
      if (!isClosed) emit(state.copyWith(enCours: false));
      return messageErreurBail(ex);
    }
  }

  Future<ResultatBail> envoyerContrat() => _operation((d) => d.envoyerContratBail(id));

  Future<ResultatBail> modifierMontant(int loyerId, double montant) =>
      _operation((d) => d.modifierMontantLoyer(loyerId, montant));

  Future<ResultatBail> encaisser(
    int loyerId, {
    required double montant,
    required DateTime payeLe,
    required String mode,
    String? reference,
    String? remarque,
    required bool envoyerQuittance,
  }) =>
      _operation((d) => d.encaisserLoyer(
            loyerId,
            montant: montant,
            payeLe: payeLe,
            mode: mode,
            reference: reference,
            remarque: remarque,
            envoyerQuittance: envoyerQuittance,
          ));

  Future<ResultatBail> annulerPaiement(int paiementId, String? motif) =>
      _operation((d) => d.annulerPaiementLoyer(paiementId, motif: motif));

  Future<ResultatBail> envoyerQuittance(int paiementId) => _operation((d) => d.envoyerQuittance(paiementId));

  Loyer? loyer(int loyerId) {
    for (final l in state.bail?.loyers ?? const <Loyer>[]) {
      if (l.id == loyerId) return l;
    }
    return null;
  }
}
