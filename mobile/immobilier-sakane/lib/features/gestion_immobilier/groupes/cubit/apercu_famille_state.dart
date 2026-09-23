part of 'apercu_famille_cubit.dart';

const Object _inchange = Object();

class ApercuFamilleState {
  /// `rent-short`, `rent-long` ou `selle`.
  final String code;

  final ApercuFamille? apercu;

  /// Vrai pendant la première lecture : le squelette s'affiche.
  final bool chargement;

  /// Message d'erreur de la dernière lecture, s'il y en a un.
  final String? erreur;

  /// Vrai pendant une confirmation d'arrivée ou de départ.
  final bool enCours;

  const ApercuFamilleState({
    required this.code,
    this.apercu,
    this.chargement = false,
    this.erreur,
    this.enCours = false,
  });

  /// Vrai quand rien n'a encore pu être lu : l'écran montre alors la
  /// carte d'erreur plutôt qu'une liste vide trompeuse.
  bool get echecTotal => apercu == null && (erreur ?? '').isNotEmpty;

  ApercuFamilleState copyWith({
    ApercuFamille? apercu,
    bool? chargement,
    Object? erreur = _inchange,
    bool? enCours,
  }) {
    return ApercuFamilleState(
      code: code,
      apercu: apercu ?? this.apercu,
      chargement: chargement ?? this.chargement,
      erreur: identical(erreur, _inchange) ? this.erreur : erreur as String?,
      enCours: enCours ?? this.enCours,
    );
  }
}
