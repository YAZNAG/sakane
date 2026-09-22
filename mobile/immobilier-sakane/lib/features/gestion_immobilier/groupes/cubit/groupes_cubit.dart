import 'package:bloc/bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/exceptions/unauthorized_exception.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/models/dossier.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/exceptions/validation_exception.dart';

part 'groupes_state.dart';

/// Regroupe les biens par type de transaction, puis par état, puis par
/// dossier.
///
/// Le comptage se fait sur la liste déjà chargée : un seul appel au
/// serveur alimente les trois niveaux, et l'écran reste consultable
/// hors connexion grâce au cache de lecture.
class GroupesCubit extends Cubit<GroupesState> {
  GroupesCubit() : super(GroupesState());

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> charger() async {
    try {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
      final resultats = await Future.wait([
        _repository.getRealestates(),
        _repository.fetchDossiers(),
      ]);
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        biens: resultats[0] as List<Realestate>,
        dossiers: resultats[1] as List<Dossier>,
      ));
    } on NetworkConnectivityException {
      emit(state.copyWith(
          fetchStatus: AppStatus.error, error: AppStrings.checkConnectivity));
    } on UnAuthenticatedException {
      logout();
    } catch (_) {
      emit(state.copyWith(
          fetchStatus: AppStatus.error,
          error: "Impossible de charger les biens"));
    }
  }

  /// [typeCode] rattache le dossier a sa famille : il n'apparaitra pas
  /// dans les deux autres.
  Future<void> creerDossier(String nom,
      {String? description, String? typeCode}) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      await _repository.creerDossier(nom,
          description: description, type: typeCode);
      await _rechargerSilencieusement();
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: "Dossier « $nom » créé",
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
    }
  }

  /// [dossierId] à null retire les biens de tout dossier.
  ///
  /// Un dossier d'une autre famille fait changer la catégorie des biens
  /// (le serveur l'applique) : l'état porte alors [GroupesState.categorieChangee]
  /// et le rechargement les fait passer d'une famille à l'autre.
  Future<void> deplacerVersDossier(List<int> biens, int? dossierId) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));

      // Familles avant le déplacement, pour savoir combien changent.
      String? familleCible;
      for (final d in state.dossiers ?? <Dossier>[]) {
        if (dossierId != null && d.id == dossierId) familleCible = d.typeCode;
      }
      final avant = <int, String?>{
        for (final b in state.biens ?? <Realestate>[])
          if (b.id != null && biens.contains(b.id)) b.id!: b.typeTransaction?.value,
      };

      await _repository.affecterAuDossier(biens, dossierId);
      await _rechargerSilencieusement();

      final categorieChangee = familleCible == null
          ? 0
          : avant.values.where((famille) => famille != familleCible).length;

      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: dossierId == null
            ? "Bien retiré du dossier"
            : "Bien déplacé",
        categorieChangee: categorieChangee,
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
    }
  }

  Future<void> renommerDossier(int id, String nom, {String? description}) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      await _repository.renommerDossier(id, nom, description: description);
      await _rechargerSilencieusement();
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: "Dossier renommé « $nom »",
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
    }
  }

  /// Remplace la liste des agents autorises sur un dossier.
  Future<void> affecterAgents(int dossierId, List<int> agents) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      await _repository.affecterAgentsDossier(dossierId, agents);
      await _rechargerSilencieusement();
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: agents.isEmpty
            ? "Dossier ouvert à tous les agents"
            : "${agents.length} agent(s) autorisé(s)",
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
    }
  }

  Future<void> supprimerDossier(int id, String nom) async {
    try {
      emit(state.copyWith(actionStatus: AppStatus.loading));
      await _repository.supprimerDossier(id);
      await _rechargerSilencieusement();
      emit(state.copyWith(
        actionStatus: AppStatus.success,
        message: "Dossier « $nom » supprimé",
      ));
    } catch (ex) {
      emit(state.copyWith(actionStatus: AppStatus.error, error: _message(ex)));
    }
  }

  /// Recharge sans faire clignoter l'écran : l'utilisateur vient d'agir,
  /// il attend le résultat, pas un indicateur de chargement.
  Future<void> _rechargerSilencieusement() async {
    final resultats = await Future.wait([
      _repository.getRealestates(),
      _repository.fetchDossiers(),
    ]);
    emit(state.copyWith(
      biens: resultats[0] as List<Realestate>,
      dossiers: resultats[1] as List<Dossier>,
    ));
  }

  String _message(Object ex) {
    if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
    if (ex is ValidatorException) {
      final premiere = ex.errors?.values.firstOrNull;
      if (premiere is List && premiere.isNotEmpty) return premiere.first.toString();
    }
    if (ex is UnAuthorizedException) {
      return "Seuls les administrateurs peuvent gérer les dossiers.";
    }
    // Message du serveur remonté par le dépôt : Exception("…").
    final texte = ex.toString();
    if (texte.startsWith('Exception: ') && texte.length > 11) {
      return texte.substring(11);
    }
    return "L'opération n'a pas abouti";
  }
}

extension _PremierOuNul<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
