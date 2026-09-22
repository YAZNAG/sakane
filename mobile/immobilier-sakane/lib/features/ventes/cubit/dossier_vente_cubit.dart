import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

/// Issue d'une action : une erreur, ou un avertissement du serveur.
class ResultatVente {
  final String? erreur;
  final String? avertissement;

  /// La visite creee, le cas echeant.
  final VisiteVente? visite;

  const ResultatVente({this.erreur, this.avertissement, this.visite});

  bool get reussi => erreur == null;
}

class DossierVenteState {
  final AppStatus? statut;
  final DossierVente? dossier;
  final String? erreur;

  /// Vrai pendant une action (statut, suppression…).
  final bool enCours;

  const DossierVenteState({this.statut, this.dossier, this.erreur, this.enCours = false});

  DossierVenteState copyWith({AppStatus? statut, DossierVente? dossier, String? erreur, bool? enCours}) {
    return DossierVenteState(
      statut: statut ?? this.statut,
      dossier: dossier ?? this.dossier,
      erreur: erreur ?? this.erreur,
      enCours: enCours ?? this.enCours,
    );
  }
}

class DossierVenteCubit extends Cubit<DossierVenteState> {
  final int id;

  DossierVenteCubit(this.id) : super(const DossierVenteState());

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux || state.dossier == null) {
      emit(state.copyWith(statut: AppStatus.loading));
    }
    try {
      final dossier = await _depot.fetchDossierVente(id);
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.success, dossier: dossier));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreurBail(ex)));
    }
  }

  /// Execute une action, puis recharge le dossier sans indicateur.
  Future<ResultatVente> _agir(Future<String?> Function() action) async {
    emit(state.copyWith(enCours: true));
    try {
      final avertissement = await action();
      await charger(silencieux: true);
      if (!isClosed) emit(state.copyWith(enCours: false));
      return ResultatVente(avertissement: avertissement);
    } catch (ex) {
      if (!isClosed) emit(state.copyWith(enCours: false));
      return ResultatVente(erreur: messageErreurBail(ex));
    }
  }

  Future<ResultatVente> changerStatut(String statut) => _agir(() async {
        await _depot.changerStatutVente(id, statut);
        return null;
      });

  Future<ResultatVente> creerMandat(Map<String, dynamic> champs) => _agir(() async {
        await _depot.creerMandatVente(id, champs);
        return null;
      });

  Future<ResultatVente> supprimerMandat(int mandat) => _agir(() async {
        await _depot.supprimerMandatVente(mandat);
        return null;
      });

  Future<ResultatVente> envoyerMandat(int mandat) => _agir(() => _depot.envoyerMandatVente(mandat));

  /// Rend la visite creee (non signee) dans [ResultatVente.visite].
  Future<ResultatVente> creerVisite(Map<String, dynamic> champs) async {
    VisiteVente? visite;
    final res = await _agir(() async {
      visite = await _depot.creerVisiteVente(id, champs);
      return null;
    });
    return ResultatVente(erreur: res.erreur, avertissement: res.avertissement, visite: visite);
  }

  Future<ResultatVente> supprimerVisite(int visite) => _agir(() async {
        await _depot.supprimerVisiteVente(visite);
        return null;
      });

  Future<ResultatVente> envoyerRecu(int visite) => _agir(() => _depot.envoyerRecuVisite(visite));
}
