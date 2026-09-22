import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/models/owner.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/dependencies/dependencies.dart';
import '../../../../core/utils/logout.dart';
import '../../../../exceptions/network_connectivity_exception.dart';
import '../../../../exceptions/unauthenticated_exception.dart';
import '../../../../repository/repository.dart';

part 'owner_detail_state.dart';

class OwnerDetailCubit extends Cubit<OwnerDetailState> {
  OwnerDetailCubit(int id) : super(OwnerDetailState(id: id));

  /// [silencieux] : rafraîchit sans afficher le chargement plein écran
  /// (pull-to-refresh, après une action).
  Future<void> fetchData({bool silencieux = false}) async {
    try {
      if (!silencieux || state.owner == null) {
        emit(state.copyWith(fetchStatus: AppStatus.loading));
      }
      Repository repository = Dependencies.get<Repository>();
      Owner owner = await repository.fetchOwnerDetails(state.id!);
      emit(state.copyWith(fetchStatus: AppStatus.success, owner: owner));
    } on NetworkConnectivityException catch (_) {
      if (silencieux && state.owner != null) {
        emit(state.copyWith(actionStatus: AppStatus.error, actionError: AppStrings.checkConnectivity));
      } else {
        emit(state.copyWith(fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
      }
    } on UnAuthenticatedException catch (_) {
      logout();
    } catch (ex) {
      if (silencieux && state.owner != null) {
        emit(state.copyWith(actionStatus: AppStatus.error, actionError: _message(ex)));
      } else {
        emit(state.copyWith(fetchStatus: AppStatus.error));
      }
    }
  }

  /// Joint un contrat au propriétaire (optionnellement lié à un appartement).
  Future<void> ajouterContrat(
    File fichier, {
    int? bienId,
    String? titre,
    String? dateDebut,
    String? dateFin,
  }) async {
    if (state.actionStatus == AppStatus.loading) return;
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      final repository = Dependencies.get<Repository>();
      await repository.ajouterContratProprietaire(
        state.id!,
        fichier,
        bienId: bienId,
        titre: (titre ?? '').trim().isEmpty ? null : titre!.trim(),
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      await _rafraichir();
      emit(state.copyWith(actionStatus: AppStatus.success, actionMessage: 'Contrat joint.'));
    } on NetworkConnectivityException catch (_) {
      emit(state.copyWith(actionStatus: AppStatus.error, actionError: AppStrings.checkConnectivity));
    } on UnAuthenticatedException catch (_) {
      logout();
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, actionError: _message(ex)));
    }
  }

  /// Supprime un contrat du propriétaire.
  Future<void> supprimerContrat(int contratId) async {
    if (state.actionStatus == AppStatus.loading) return;
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      final repository = Dependencies.get<Repository>();
      await repository.supprimerContratProprietaire(contratId);
      await _rafraichir();
      emit(state.copyWith(actionStatus: AppStatus.success, actionMessage: 'Contrat supprimé.'));
    } on NetworkConnectivityException catch (_) {
      emit(state.copyWith(actionStatus: AppStatus.error, actionError: AppStrings.checkConnectivity));
    } on UnAuthenticatedException catch (_) {
      logout();
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, actionError: _message(ex)));
    }
  }

  /// Recharge le propriétaire sans toucher au statut d'action en cours.
  Future<void> _rafraichir() async {
    try {
      final owner = await Dependencies.get<Repository>().fetchOwnerDetails(state.id!);
      emit(state.copyWith(fetchStatus: AppStatus.success, owner: owner, actionStatus: AppStatus.loading));
    } catch (_) {
      // L'action a réussi ; un échec du rechargement n'est pas bloquant.
    }
  }

  String _message(Object ex) {
    final texte = ex.toString().replaceFirst('Exception: ', '').trim();
    return texte.isEmpty ? 'Une erreur est survenue.' : texte;
  }
}
