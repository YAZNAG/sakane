import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/charge_fixe.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';

part 'charges_fixes_state.dart';

/// Les charges fixes d'une période : ce qu'elles coûtent, par famille, et
/// les échéances qui les ramènent chaque mois.
class ChargesFixesCubit extends Cubit<ChargesFixesState> {
  ChargesFixesCubit() : super(ChargesFixesState.initial()) {
    charger();
    _chargerBiens();
  }

  Repository get _depot => Dependencies.get<Repository>();

  String _jour(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Les appartements proposés au rattachement d'une charge. Leur absence
  /// n'empêche pas de saisir : une charge fixe est souvent celle de l'agence.
  Future<void> _chargerBiens() async {
    try {
      final biens = await _depot.getRealestates();
      biens.sort((a, b) =>
          (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
      if (!isClosed) emit(state.copyWith(biens: biens));
    } catch (_) {
      // Sans la liste, le formulaire propose simplement « Agence ».
    }
  }

  Future<void> charger() async {
    emit(state.copyWith(
        fetchStatus: AppStatus.loading, error: null, effacerErreur: true));
    try {
      final donnees = await _depot.chargesFixes(
        du: _jour(state.du),
        au: _jour(state.au),
        categorie: state.famille,
      );
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.success, donnees: donnees));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: _message(ex)));
    }
  }

  void changerPeriode(PeriodeActivite periode) {
    final bornes = bornesActivite(periode);
    emit(state.copyWith(
        periode: periode, du: bornes.du, au: bornes.au));
    charger();
  }

  void changerDates(DateTime du, DateTime au) {
    final ordonne = du.isAfter(au);
    emit(state.copyWith(
      periode: PeriodeActivite.personnalisee,
      du: ordonne ? au : du,
      au: ordonne ? du : au,
    ));
    charger();
  }

  /// Le filtre par famille : le même code deux fois l'enlève.
  void filtrerFamille(String? code) {
    emit(state.copyWith(
        famille: state.famille == code ? null : code, effacerFamille: state.famille == code));
    charger();
  }

  /// Saisit une charge fixe, avec sa répétition mensuelle s'il y a lieu.
  Future<bool> ajouter(SaisieChargeFixe saisie, {File? document}) =>
      _agir(() => _depot.ajouterChargeFixe(saisie, document: document));

  Future<bool> modifier(int id, SaisieChargeFixe saisie) =>
      _agir(() => _depot.modifierChargeFixe(id, saisie));

  Future<bool> modifierEcheance(int id,
          {String? nom, double? montant, int? jour, String? categorie, String? categorieLibelle}) =>
      _agir(() => _depot.modifierRecurrenceCharge(id,
          nom: nom,
          montant: montant,
          jour: jour,
          categorie: categorie,
          categorieLibelle: categorieLibelle));

  Future<bool> arreterEcheance(int id) =>
      _agir(() => _depot.arreterRecurrenceCharge(id));

  Future<bool> annuler(int id, {double? montant, String? motif}) =>
      _agir(() => _depot.annulerCharge(id, montant: montant, motif: motif));

  /// Valide une charge en attente : elle est alors réglée, et sort de la
  /// caisse de celui qui valide.
  Future<bool> valider(Charge charge) =>
      _agir(() => _depot.validateCharge(charge));

  /// Une action, son état, son message d'erreur, puis la liste rechargée.
  Future<bool> _agir(Future<void> Function() action) async {
    emit(state.copyWith(
        actionStatus: AppStatus.loading, effacerErreur: true, error: null));
    try {
      await action();
      if (isClosed) return true;
      emit(state.copyWith(actionStatus: AppStatus.success));
      await charger();
      return true;
    } catch (ex) {
      if (isClosed) return false;
      emit(state.copyWith(
          actionStatus: AppStatus.error, error: _message(ex)));
      return false;
    }
  }

  /// Le message du serveur, sans le « Exception: » que Dart ajoute.
  String _message(Object ex) =>
      ex.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
