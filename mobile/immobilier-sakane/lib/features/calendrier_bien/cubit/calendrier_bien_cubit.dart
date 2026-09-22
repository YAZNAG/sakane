import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/calendrier_bien.dart';
import 'package:immobilier/repository/repository.dart';

part 'calendrier_bien_state.dart';

class CalendrierBienCubit extends Cubit<CalendrierBienState> {
  /// Le serveur refuse les plages de plus de 800 jours : on decoupe.
  static const int _trancheMax = 700;

  CalendrierBienCubit(int bienId, {String? titre})
      : super(CalendrierBienState(bienId: bienId, titre: titre));

  Repository get _depot => Dependencies.get<Repository>();

  /// Premier chargement : trois mois en arriere, douze en avant.
  Future<void> charger() async {
    final t = aujourdhui();
    final du = DateTime(t.year, t.month - 3, 1);
    final au = DateTime(t.year, t.month + 13, 0);
    emit(state.copyWith(statut: AppStatus.loading, erreur: null));
    try {
      final cal = await _chargerPlage(du, au);
      emit(state.copyWith(statut: AppStatus.success, calendrier: cal, du: du, au: au));
    } catch (ex) {
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreur(ex)));
    }
  }

  /// Recharge la plage deja affichee, sans masquer le calendrier.
  Future<String?> rafraichir() async {
    final du = state.du, au = state.au;
    if (du == null || au == null) {
      await charger();
      return state.statut == AppStatus.error ? state.erreur : null;
    }
    try {
      final cal = await _chargerPlage(du, au);
      emit(state.copyWith(statut: AppStatus.success, calendrier: cal));
      return null;
    } catch (ex) {
      return messageErreur(ex);
    }
  }

  /// Ajoute trois mois d'historique avant la plage chargee.
  Future<String?> chargerMoisPrecedents() async {
    final du = state.du, cal = state.calendrier;
    if (du == null || cal == null || state.chargementAnterieur) return null;
    final nouveauDu = DateTime(du.year, du.month - 3, 1);
    emit(state.copyWith(chargementAnterieur: true));
    try {
      final anciens = await _chargerPlage(nouveauDu, ajouterJours(du, -1));
      emit(state.copyWith(
        chargementAnterieur: false,
        du: nouveauDu,
        calendrier: _fusionner(anciens, state.calendrier ?? cal),
      ));
      return null;
    } catch (ex) {
      emit(state.copyWith(chargementAnterieur: false));
      return messageErreur(ex);
    }
  }

  Future<CalendrierBien> _chargerPlage(DateTime du, DateTime au) async {
    CalendrierBien? res;
    var debut = du;
    while (!debut.isAfter(au)) {
      var fin = ajouterJours(debut, _trancheMax);
      if (fin.isAfter(au)) fin = au;
      final morceau = await _depot.fetchCalendrier(state.bienId, du: debut, au: fin);
      res = res == null ? morceau : _fusionner(res, morceau);
      debut = ajouterJours(fin, 1);
    }
    return res!;
  }

  CalendrierBien _fusionner(CalendrierBien a, CalendrierBien b) {
    final blocages = {for (final x in a.blocages) x.id: x, for (final x in b.blocages) x.id: x};
    final resas = {for (final x in a.reservations) x.id: x, for (final x in b.reservations) x.id: x};
    final baux = {for (final x in a.baux) x.id: x, for (final x in b.baux) x.id: x};
    final airbnb = {for (final x in a.airbnb) x.cle: x, for (final x in b.airbnb) x.cle: x};
    return CalendrierBien(
      bienId: b.bienId,
      titre: b.titre ?? a.titre,
      prixBase: b.prixBase,
      statutJour: b.statutJour ?? a.statutJour,
      du: a.du.isBefore(b.du) ? a.du : b.du,
      au: a.au.isAfter(b.au) ? a.au : b.au,
      prix: {...a.prix, ...b.prix},
      blocages: blocages.values.toList(),
      reservations: resas.values.toList(),
      baux: baux.values.toList(),
      airbnb: airbnb.values.toList(),
    );
  }

  // ── Selection ────────────────────────────────────────────────────

  /// Premier toucher : debut ; second : fin (ou nouveau debut s'il
  /// precede le premier).
  void toucherJour(DateTime jour) {
    final j = CalendrierBien.jour(jour);
    final debut = state.debut;
    if (debut == null || state.fin != null) {
      emit(state.copyWith(debut: j, fin: null));
    } else if (j.isBefore(debut)) {
      emit(state.copyWith(debut: j, fin: null));
    } else {
      emit(state.copyWith(fin: j));
    }
  }

  void annulerSelection() => emit(state.copyWith(debut: null, fin: null));

  // ── Modifications ────────────────────────────────────────────────

  /// Execute une modification puis recharge. Rend le message d'erreur,
  /// ou null si tout s'est bien passe.
  Future<String?> _modifier(Future<void> Function(Repository depot) action,
      {bool viderSelection = true}) async {
    if (state.enCours) return 'Une opération est déjà en cours.';
    emit(state.copyWith(enCours: true));
    try {
      await action(_depot);
    } catch (ex) {
      emit(state.copyWith(enCours: false));
      return messageErreur(ex);
    }
    if (viderSelection) emit(state.copyWith(debut: null, fin: null));
    await rafraichir();
    emit(state.copyWith(enCours: false));
    return null;
  }

  Future<String?> definirPrix(double prix) {
    final du = state.debut!, au = state.finOuDebut!;
    return _modifier((d) => d.definirPrixNuits(state.bienId, du: du, au: au, prix: prix));
  }

  Future<String?> prixHabituel() {
    final du = state.debut!, au = state.finOuDebut!;
    return _modifier((d) => d.effacerPrixNuits(state.bienId, du: du, au: au));
  }

  Future<String?> bloquer(String? motif) {
    final du = state.debut!, au = state.finOuDebut!;
    return _modifier((d) => d.ajouterBlocage(state.bienId,
        du: _iso(du), au: _iso(au), motif: (motif ?? '').trim().isEmpty ? null : motif!.trim()));
  }

  Future<String?> debloquer() {
    final du = state.debut!, au = state.finOuDebut!;
    return _modifier((d) => d.debloquerPeriode(state.bienId, du: du, au: au));
  }

  /// Rend l'ecart a regler (positif : le client doit plus), ou une erreur.
  Future<({double ecart, String? erreur})> modifierReservation(
      int id, DateTime arrivee, DateTime depart, double prixNuit) async {
    double ecart = 0;
    final erreur = await _modifier(
      (d) async => ecart = await d.modifierReservation(id, arrivee: arrivee, depart: depart, prixNuit: prixNuit),
      viderSelection: false,
    );
    return (ecart: ecart, erreur: erreur);
  }

  Future<String?> prolonger(int id, DateTime checkout, double prix) =>
      _modifier((d) => d.extendBooking(checkout, prix, id), viderSelection: false);

  Future<String?> raccourcir(int id, DateTime checkout, double remboursement) =>
      _modifier((d) => d.shrinkBooking(checkout, remboursement, id), viderSelection: false);

  Future<String?> supprimer(int id, {required bool rembourse, double? montant}) => _modifier(
        (d) => d.deleteBooking(id, rembourse: rembourse, montantRembourse: rembourse ? montant : null),
        viderSelection: false,
      );

  static String _iso(DateTime d) {
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${deux(d.month)}-${deux(d.day)}';
  }
}
