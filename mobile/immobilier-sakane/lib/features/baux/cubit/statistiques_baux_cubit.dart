import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/statistiques_baux.dart';
import 'package:immobilier/repository/repository.dart';

/// L'etat de l'ecran des chiffres : la periode demandee et ce qu'elle donne.
class StatistiquesBauxState {
  final AppStatus? statut;
  final StatistiquesBaux? chiffres;
  final String? erreur;
  final DateTime du;
  final DateTime au;

  const StatistiquesBauxState({
    this.statut,
    this.chiffres,
    this.erreur,
    required this.du,
    required this.au,
  });

  StatistiquesBauxState copyWith({
    AppStatus? statut,
    StatistiquesBaux? chiffres,
    String? erreur,
    DateTime? du,
    DateTime? au,
  }) {
    return StatistiquesBauxState(
      statut: statut ?? this.statut,
      chiffres: chiffres ?? this.chiffres,
      // Une erreur ne se traine pas d'un chargement au suivant.
      erreur: erreur,
      du: du ?? this.du,
      au: au ?? this.au,
    );
  }
}

class StatistiquesBauxCubit extends Cubit<StatistiquesBauxState> {
  StatistiquesBauxCubit({DateTime? du, DateTime? au})
      : super(StatistiquesBauxState(
          du: du ?? DateTime(DateTime.now().year, 1, 1),
          au: au ?? DateTime(DateTime.now().year, 12, 31),
        ));

  Repository get _depot => Dependencies.get<Repository>();

  Future<void> charger() async {
    emit(state.copyWith(statut: AppStatus.loading, erreur: null));
    try {
      final chiffres = await _depot.statistiquesBaux(
        du: _jour(state.du),
        au: _jour(state.au),
      );
      emit(state.copyWith(statut: AppStatus.success, chiffres: chiffres));
    } catch (ex) {
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreurBail(ex)));
    }
  }

  /// Change la periode puis recharge.
  Future<void> periode(DateTime du, DateTime au) async {
    emit(state.copyWith(du: du, au: au));
    await charger();
  }

  static String _jour(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
