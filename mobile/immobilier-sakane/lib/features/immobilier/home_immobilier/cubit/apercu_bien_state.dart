part of 'apercu_bien_cubit.dart';

const Object _inchange = Object();

class ApercuBienState {
  final int bienId;

  final ApercuBien? apercu;

  /// Vrai pendant la première lecture : le squelette s'affiche.
  final bool chargement;

  /// Message de la dernière lecture ratée, s'il y en a un.
  final String? erreur;

  const ApercuBienState({
    required this.bienId,
    this.apercu,
    this.chargement = false,
    this.erreur,
  });

  /// Vrai quand rien n'a jamais pu être lu : la carte du jour laisse alors
  /// place à un message, plutôt qu'à un état faussement vide.
  bool get echecTotal => apercu == null && (erreur ?? '').isNotEmpty;

  ApercuBienState copyWith({
    ApercuBien? apercu,
    bool? chargement,
    Object? erreur = _inchange,
  }) {
    return ApercuBienState(
      bienId: bienId,
      apercu: apercu ?? this.apercu,
      chargement: chargement ?? this.chargement,
      erreur: identical(erreur, _inchange) ? this.erreur : erreur as String?,
    );
  }
}
