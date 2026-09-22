import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/models/envoi_historique_syndic.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/repository/repository.dart';

/// Les periodes proposees en raccourci au-dessus de l'historique.
///
/// [recent] ne fixe aucune borne : le serveur decide (les deux derniers
/// mois). C'est le choix d'ouverture, pour que l'ecran montre toujours
/// quelque chose des le premier affichage.
enum PeriodeEnvois { recent, ceMois, moisDernier, troisMois, personnalisee }

class HistoriqueEnvoisState {
  final AppStatus? fetchStatus;
  final HistoriqueEnvoisSyndic? historique;
  final String? error;

  final PeriodeEnvois periode;
  final DateTimeRange plage;
  final int? syndicId;

  /// envoye, echec ou ignore ; null = tous.
  final String? statut;

  /// Pour le filtre par syndic ; vide tant qu'ils ne sont pas charges.
  final List<Syndic> syndics;

  const HistoriqueEnvoisState({
    this.fetchStatus,
    this.historique,
    this.error,
    required this.periode,
    required this.plage,
    this.syndicId,
    this.statut,
    this.syndics = const [],
  });

  /// Vrai seulement quand le serveur a repondu sans aucun envoi.
  bool get vide => historique != null && historique!.nombreEnvois == 0;

  /// Vrai quand un filtre restreint la liste : l'ecran vide le dit,
  /// plutot que de laisser croire qu'il ne s'est jamais rien passe.
  bool get filtre => syndicId != null || statut != null;

  HistoriqueEnvoisState copyWith({
    AppStatus? fetchStatus,
    HistoriqueEnvoisSyndic? historique,
    String? error,
    PeriodeEnvois? periode,
    DateTimeRange? plage,
    int? Function()? syndicId,
    String? Function()? statut,
    List<Syndic>? syndics,
  }) {
    return HistoriqueEnvoisState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      historique: historique ?? this.historique,
      error: error,
      periode: periode ?? this.periode,
      plage: plage ?? this.plage,
      syndicId: syndicId != null ? syndicId() : this.syndicId,
      statut: statut != null ? statut() : this.statut,
      syndics: syndics ?? this.syndics,
    );
  }
}

/// Les dates d'une periode raccourcie, par rapport a aujourd'hui.
DateTimeRange plagePeriodeEnvois(PeriodeEnvois periode, {DateTime? maintenant}) {
  final n = maintenant ?? DateTime.now();
  final aujourdHui = DateTime(n.year, n.month, n.day);
  switch (periode) {
    case PeriodeEnvois.moisDernier:
      return DateTimeRange(
        start: DateTime(n.year, n.month - 1, 1),
        end: DateTime(n.year, n.month, 0),
      );
    case PeriodeEnvois.troisMois:
      return DateTimeRange(start: DateTime(n.year, n.month - 2, 1), end: aujourdHui);
    // Le serveur retient les deux derniers mois quand aucune borne ne
    // lui est donnee : on affiche la meme chose en attendant sa reponse.
    case PeriodeEnvois.recent:
      return DateTimeRange(start: DateTime(n.year, n.month - 1, 1), end: aujourdHui);
    case PeriodeEnvois.ceMois:
    case PeriodeEnvois.personnalisee:
      return DateTimeRange(start: DateTime(n.year, n.month, 1), end: aujourdHui);
  }
}

String dateApiEnvois(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// L'historique des envois du contrat aux syndics, filtre par periode,
/// syndic et statut.
class HistoriqueEnvoisCubit extends Cubit<HistoriqueEnvoisState> {
  HistoriqueEnvoisCubit({int? syndicId})
      : super(HistoriqueEnvoisState(
          periode: PeriodeEnvois.recent,
          plage: plagePeriodeEnvois(PeriodeEnvois.recent),
          syndicId: syndicId,
        ));

  Repository get _repository => Dependencies.get<Repository>();

  Future<void> demarrer() async {
    await Future.wait([charger(), _chargerSyndics()]);
  }

  Future<void> _chargerSyndics() async {
    try {
      final syndics = await _repository.fetchSyndics();
      if (isClosed) return;
      emit(state.copyWith(syndics: syndics));
    } catch (_) {
      // Le filtre par syndic reste simplement indisponible
    }
  }

  Future<void> charger({bool silencieux = false}) async {
    if (!silencieux || state.historique == null) {
      emit(state.copyWith(fetchStatus: AppStatus.loading));
    }
    // Sans bornes, le serveur rend sa periode par defaut : l'ecran
    // s'ouvre donc sur des envois recents, jamais sur du vide.
    final libre = state.periode == PeriodeEnvois.recent;
    try {
      final historique = await _repository.fetchEnvoisSyndics(
        du: libre ? null : dateApiEnvois(state.plage.start),
        au: libre ? null : dateApiEnvois(state.plage.end),
        syndic: state.syndicId,
        statut: state.statut,
      );
      if (isClosed) return;
      emit(state.copyWith(
        fetchStatus: AppStatus.success,
        historique: historique,
        // La periode reellement retenue par le serveur, pour que
        // l'en-tete et l'export parlent des memes dates.
        plage: libre ? _plageServeur(historique) : null,
      ));
    } catch (ex) {
      if (isClosed) return;
      emit(state.copyWith(fetchStatus: AppStatus.error, error: messageErreurSyndic(ex)));
    }
  }

  DateTimeRange? _plageServeur(HistoriqueEnvoisSyndic h) {
    final debut = h.debut;
    final fin = h.fin;
    if (debut == null || fin == null || fin.isBefore(debut)) return null;
    return DateTimeRange(start: debut, end: fin);
  }

  void choisirPeriode(PeriodeEnvois periode, {DateTimeRange? plage}) {
    emit(state.copyWith(
      periode: periode,
      plage: plage ?? plagePeriodeEnvois(periode),
    ));
    charger();
  }

  void choisirSyndic(int? id) {
    if (id == state.syndicId) return;
    emit(state.copyWith(syndicId: () => id));
    charger();
  }

  void choisirStatut(String? statut) {
    if (statut == state.statut) return;
    emit(state.copyWith(statut: () => statut));
    charger();
  }

  /// Retire syndic et statut en un seul rechargement. [garderSyndic]
  /// vaut pour l'historique ouvert depuis la fiche d'un syndic.
  void reinitialiserFiltres({bool garderSyndic = false}) {
    emit(state.copyWith(
      statut: () => null,
      syndicId: garderSyndic ? null : () => null,
    ));
    charger();
  }

  /// Le fichier PDF ou Excel de la periode et des filtres affiches.
  Future<String> exporter(String format) => _repository.exporterEnvoisSyndics(
        du: dateApiEnvois(state.plage.start),
        au: dateApiEnvois(state.plage.end),
        syndic: state.syndicId,
        statut: state.statut,
        format: format,
      );
}
