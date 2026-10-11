import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/models/groupe_whatsapp.dart';
import 'package:immobilier/repository/repository.dart';

part 'groupes_whatsapp_state.dart';

/// Les groupes WhatsApp de l'agence : ceux qui sont enregistrés, et ceux que
/// le numéro de l'agence voit sans qu'ils le soient encore.
class GroupesWhatsappCubit extends Cubit<GroupesWhatsappState> {
  GroupesWhatsappCubit() : super(const GroupesWhatsappState());

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux) {
      emit(state.copyWith(fetchStatus: AppStatus.loading, effacerErreur: true));
    }
    try {
      final donnees = await _depot.groupesWhatsapp();
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.success, donnees: donnees));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.error, error: _message(ex)));
    }
  }

  /// Enregistre un groupe choisi dans la liste, ou désigné par son lien.
  Future<bool> ajouter({String? jid, String? nom, String? lien}) =>
      _agir(() => _depot.ajouterGroupeWhatsapp(jid: jid, nom: nom, lien: lien));

  Future<bool> renommer(int id, String nom) =>
      _agir(() => _depot.modifierGroupeWhatsapp(id, nom: nom));

  Future<bool> activer(int id, bool actif) =>
      _agir(() => _depot.modifierGroupeWhatsapp(id, actif: actif));

  /// Le groupe est-il toujours joignable, et combien de membres a-t-il ?
  Future<bool> verifier(int id) =>
      _agir(() => _depot.verifierGroupeWhatsapp(id));

  Future<bool> supprimer(int id) =>
      _agir(() => _depot.supprimerGroupeWhatsapp(id));

  Future<bool> _agir(Future<void> Function() action) async {
    emit(state.copyWith(actionStatus: AppStatus.loading, effacerErreur: true));
    try {
      await action();
      if (isClosed) return true;
      emit(state.copyWith(actionStatus: AppStatus.success));
      await charger(silencieux: true);
      return true;
    } catch (ex) {
      if (isClosed) return false;
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
      return false;
    }
  }

  String _message(Object ex) =>
      ex.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
