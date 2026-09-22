part of 'calendrier_bien_cubit.dart';

const Object _inchange = Object();

class CalendrierBienState {
  final int bienId;
  final String? titre;
  final AppStatus? statut;
  final String? erreur;
  final CalendrierBien? calendrier;

  /// Plage chargee (premier et dernier jour).
  final DateTime? du;
  final DateTime? au;

  /// Selection de nuits, bornes comprises.
  final DateTime? debut;
  final DateTime? fin;

  final bool enCours;
  final bool chargementAnterieur;

  const CalendrierBienState({
    required this.bienId,
    this.titre,
    this.statut,
    this.erreur,
    this.calendrier,
    this.du,
    this.au,
    this.debut,
    this.fin,
    this.enCours = false,
    this.chargementAnterieur = false,
  });

  DateTime? get finOuDebut => fin ?? debut;

  bool get aSelection => debut != null;

  /// Nuits selectionnees, dans l'ordre.
  List<DateTime> get nuitsSelectionnees {
    final d = debut, f = finOuDebut;
    if (d == null || f == null) return const [];
    return [for (var j = d; !j.isAfter(f); j = DateTime(j.year, j.month, j.day + 1)) j];
  }

  bool estSelectionne(DateTime jour) {
    final d = debut, f = finOuDebut;
    if (d == null || f == null) return false;
    return !jour.isBefore(d) && !jour.isAfter(f);
  }

  CalendrierBienState copyWith({
    AppStatus? statut,
    Object? erreur = _inchange,
    CalendrierBien? calendrier,
    DateTime? du,
    DateTime? au,
    Object? debut = _inchange,
    Object? fin = _inchange,
    bool? enCours,
    bool? chargementAnterieur,
  }) {
    return CalendrierBienState(
      bienId: bienId,
      titre: titre,
      statut: statut ?? this.statut,
      erreur: identical(erreur, _inchange) ? this.erreur : erreur as String?,
      calendrier: calendrier ?? this.calendrier,
      du: du ?? this.du,
      au: au ?? this.au,
      debut: identical(debut, _inchange) ? this.debut : debut as DateTime?,
      fin: identical(fin, _inchange) ? this.fin : fin as DateTime?,
      enCours: enCours ?? this.enCours,
      chargementAnterieur: chargementAnterieur ?? this.chargementAnterieur,
    );
  }
}
