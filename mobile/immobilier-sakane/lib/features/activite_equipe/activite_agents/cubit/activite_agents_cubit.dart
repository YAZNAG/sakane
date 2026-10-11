import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/models/activite_agents.dart';
import 'package:immobilier/repository/repository.dart';

part 'activite_agents_state.dart';

/// Charge l'activité des agents pour la période et le regroupement
/// choisis. Chaque changement de filtre relance la lecture.
class ActiviteAgentsCubit extends Cubit<ActiviteAgentsState> {
  ActiviteAgentsCubit()
      : super(ActiviteAgentsState(
          periode: PeriodeActivite.mois,
          du: bornesActivite(PeriodeActivite.mois).du,
          au: bornesActivite(PeriodeActivite.mois).au,
        ));

  Future<void> charger() async {
    emit(state.copyWith(statut: AppStatus.loading, effacerErreur: true));
    try {
      final activite = await Dependencies.get<Repository>().activiteAgents(
        du: state.du.formattedDateEn,
        au: state.au.formattedDateEn,
        groupe: state.groupe.code,
      );
      emit(state.copyWith(
          statut: AppStatus.success, activite: activite, effacerErreur: true));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          statut: AppStatus.error,
          erreur: 'Pas de connexion. Vérifiez le réseau puis réessayez.'));
    } on UnAuthenticatedException {
      logout();
    } on UnAuthorizedException {
      emit(state.copyWith(
          statut: AppStatus.error,
          erreur: "Vous n'avez pas le droit de voir l'activité des agents."));
    } catch (ex) {
      emit(state.copyWith(
          statut: AppStatus.error,
          erreur: ex is Exception
              ? ex.toString().replaceFirst('Exception: ', '')
              : "L'activité des agents n'a pas pu être chargée."));
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

  void choisirGroupe(GroupeActivite groupe) {
    if (groupe == state.groupe) return;
    emit(state.copyWith(groupe: groupe));
    charger();
  }

  /// Déplie ou replie le détail par tranche d'un agent.
  void basculerAgent(int id) {
    final ouverts = Set<int>.from(state.agentsOuverts);
    if (!ouverts.remove(id)) ouverts.add(id);
    emit(state.copyWith(agentsOuverts: ouverts));
  }
}
