import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/models/reception_whatsapp.dart';
import 'package:immobilier/repository/repository.dart';

/// Message lisible d'une erreur remontee par le depot.
String messageErreurReception(Object ex) {
  if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
  final texte = ex.toString().replaceFirst('Exception: ', '').trim();
  return texte.isEmpty ? "L'opération n'a pas abouti." : texte;
}

class ReceptionWhatsappState {
  final AppStatus? statut;
  final ReceptionWhatsapp? reglages;
  final String? error;

  /// Nombre d'enregistrements en cours.
  final int enCours;

  /// Date du dernier enregistrement reussi, pour le retour visuel.
  final DateTime? enregistreLe;

  const ReceptionWhatsappState({
    this.statut,
    this.reglages,
    this.error,
    this.enCours = 0,
    this.enregistreLe,
  });

  ReceptionWhatsappState copyWith({
    AppStatus? statut,
    ReceptionWhatsapp? reglages,
    String? error,
    int? enCours,
    DateTime? enregistreLe,
  }) {
    return ReceptionWhatsappState(
      statut: statut ?? this.statut,
      reglages: reglages ?? this.reglages,
      error: error,
      enCours: enCours ?? this.enCours,
      enregistreLe: enregistreLe ?? this.enregistreLe,
    );
  }
}

/// Reglages de reception d'un utilisateur ([managerId] null : moi).
/// Chaque bascule est enregistree tout de suite, affichee avant la reponse.
class ReceptionWhatsappCubit extends Cubit<ReceptionWhatsappState> {
  final int? managerId;

  ReceptionWhatsappCubit({this.managerId})
    : super(const ReceptionWhatsappState());

  Repository get _repository => Dependencies.get<Repository>();

  /// Derniers reglages confirmes par le serveur : on y revient en cas d'echec.
  ReceptionWhatsapp? _confirme;
  int _sequence = 0;

  Future<void> charger() async {
    emit(state.copyWith(statut: AppStatus.loading));
    try {
      final reglages = await _repository.lireReceptionWhatsapp(
        managerId: managerId,
      );
      _confirme = reglages;
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.success, reglages: reglages));
    } on UnAuthenticatedException {
      logout();
    } catch (ex) {
      if (isClosed) return;
      emit(
        state.copyWith(
          statut: AppStatus.error,
          error: messageErreurReception(ex),
        ),
      );
    }
  }

  /// Renvoie le message d'erreur, ou null si c'est enregistre.
  Future<String?> basculerTout(bool actif) {
    final actuel = state.reglages;
    if (actuel == null) return Future.value(null);
    return _enregistrer(actuel.copyWith(actif: actif));
  }

  Future<String?> basculerType(String code, bool actif) {
    final actuel = state.reglages;
    if (actuel == null) return Future.value(null);
    return _enregistrer(
      actuel.copyWith(
        types: actuel.types
            .map((t) => t.code == code ? t.copyWith(actif: actif) : t)
            .toList(),
      ),
    );
  }

  /// Bascule d'un coup tous les types d'un groupe.
  Future<String?> basculerGroupe(String groupe, bool actif) {
    final actuel = state.reglages;
    if (actuel == null) return Future.value(null);
    return _enregistrer(
      actuel.copyWith(
        types: actuel.types
            .map((t) => t.groupe == groupe ? t.copyWith(actif: actif) : t)
            .toList(),
      ),
    );
  }

  Future<String?> _enregistrer(ReceptionWhatsapp voulu) async {
    final numero = ++_sequence;
    emit(state.copyWith(reglages: voulu, enCours: state.enCours + 1));
    try {
      final reponse = await _repository.enregistrerReceptionWhatsapp(
        managerId: managerId,
        actif: voulu.actif,
        typesCoupes: voulu.typesCoupes,
      );
      _confirme = reponse;
      if (isClosed) return null;
      // Une bascule plus recente est partie entre-temps : on garde l'affichage.
      final dernier = numero == _sequence;
      emit(
        state.copyWith(
          reglages: dernier ? reponse : null,
          enCours: state.enCours - 1,
          enregistreLe: DateTime.now(),
        ),
      );
      return null;
    } on UnAuthenticatedException {
      logout();
      return null;
    } catch (ex) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          reglages: numero == _sequence ? _confirme : null,
          enCours: state.enCours - 1,
        ),
      );
      return messageErreurReception(ex);
    }
  }
}

class ReceptionsWhatsappState {
  final AppStatus? statut;
  final List<ReceptionWhatsapp>? liste;
  final String? error;

  const ReceptionsWhatsappState({this.statut, this.liste, this.error});

  ReceptionsWhatsappState copyWith({
    AppStatus? statut,
    List<ReceptionWhatsapp>? liste,
    String? error,
  }) {
    return ReceptionsWhatsappState(
      statut: statut ?? this.statut,
      liste: liste ?? this.liste,
      error: error,
    );
  }
}

/// Vue d'ensemble des reglages de tous les utilisateurs (admin).
class ReceptionsWhatsappCubit extends Cubit<ReceptionsWhatsappState> {
  ReceptionsWhatsappCubit() : super(const ReceptionsWhatsappState());

  Repository get _repository => Dependencies.get<Repository>();

  /// [silencieux] : au retour d'une fiche, on recharge sans indicateur.
  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux || state.liste == null) {
      emit(state.copyWith(statut: AppStatus.loading));
    }
    try {
      final liste = await _repository.receptionWhatsappUtilisateurs();
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.success, liste: liste));
    } on UnAuthenticatedException {
      logout();
    } catch (ex) {
      if (isClosed) return;
      if (silencieux && state.liste != null) return;
      emit(
        state.copyWith(
          statut: AppStatus.error,
          error: messageErreurReception(ex),
        ),
      );
    }
  }
}
