import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/models/journal_nettoyage.dart';
import 'package:immobilier/repository/repository.dart';

part 'journal_nettoyage_state.dart';

/// Charge le journal de nettoyage. La recherche attend une pause de la
/// frappe avant de partir, les autres filtres relancent tout de suite.
class JournalNettoyageCubit extends Cubit<JournalNettoyageState> {
  JournalNettoyageCubit()
      : super(JournalNettoyageState(
          periode: PeriodeActivite.mois,
          du: bornesActivite(PeriodeActivite.mois).du,
          au: bornesActivite(PeriodeActivite.mois).au,
        ));

  Timer? _attente;

  @override
  Future<void> close() {
    _attente?.cancel();
    return super.close();
  }

  Future<void> charger() async {
    emit(state.copyWith(statut: AppStatus.loading, effacerErreur: true));
    try {
      final journal = await Dependencies.get<Repository>().journalNettoyage(
        du: state.du.formattedDateEn,
        au: state.au.formattedDateEn,
        bien: state.bienId,
        agent: state.agentId,
        recherche: state.recherche.trim().isEmpty ? null : state.recherche.trim(),
      );
      // Le bien retenu peut ne plus figurer dans la nouvelle période :
      // le filtre serait alors invisible et bloquerait la liste.
      final bienConnu = state.bienId == null ||
          journal.biens.any((b) => b.id == state.bienId);
      emit(state.copyWith(
        statut: AppStatus.success,
        journal: journal,
        effacerErreur: true,
        effacerBien: !bienConnu,
      ));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          statut: AppStatus.error,
          erreur: 'Pas de connexion. Vérifiez le réseau puis réessayez.'));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(
          statut: AppStatus.error,
          erreur: "Vous n'avez pas le droit de voir le journal de nettoyage."));
    } catch (ex) {
      emit(state.copyWith(
          statut: AppStatus.error,
          erreur: ex is Exception
              ? ex.toString().replaceFirst('Exception: ', '')
              : "Le journal de nettoyage n'a pas pu être chargé."));
    }
  }

  void choisirPeriode(PeriodeActivite periode) {
    if (periode == PeriodeActivite.personnalisee) return;
    final bornes = bornesActivite(periode);
    emit(state.copyWith(periode: periode, du: bornes.du, au: bornes.au));
    charger();
  }

  void choisirDates(DateTime du, DateTime au) {
    final debut = du.isAfter(au) ? au : du;
    final fin = du.isAfter(au) ? du : au;
    emit(state.copyWith(
        periode: PeriodeActivite.personnalisee,
        du: debut.justDate,
        au: fin.justDate));
    charger();
  }

  /// La frappe : on laisse une demi-seconde avant d'interroger le serveur.
  void chercher(String texte) {
    if (texte == state.recherche) return;
    emit(state.copyWith(recherche: texte));
    _attente?.cancel();
    _attente = Timer(const Duration(milliseconds: 450), () {
      if (!isClosed) charger();
    });
  }

  void choisirBien(int? id) {
    if (id == state.bienId) return;
    emit(state.copyWith(bienId: id, effacerBien: id == null));
    charger();
  }

  void choisirAgent(int? id) {
    if (id == state.agentId) return;
    emit(state.copyWith(agentId: id, effacerAgent: id == null));
    charger();
  }
}
