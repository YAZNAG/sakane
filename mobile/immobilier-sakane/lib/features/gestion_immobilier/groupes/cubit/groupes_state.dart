part of 'groupes_cubit.dart';

/// Un dossier et le nombre de biens qu'il contient dans la vue courante.
class GroupeDossier {
  final int? id;
  final String nom;
  final int nombre;

  GroupeDossier({this.id, required this.nom, required this.nombre});
}

class GroupesState {
  final AppStatus? fetchStatus;
  final AppStatus? actionStatus;
  final List<Realestate>? biens;
  final List<Dossier>? dossiers;
  final String? message;
  final String? error;

  /// Après un déplacement : nombre de biens dont la catégorie (famille)
  /// a changé. Comme [message], il ne se conserve pas.
  final int? categorieChangee;

  GroupesState({
    this.fetchStatus,
    this.actionStatus,
    this.biens,
    this.dossiers,
    this.message,
    this.error,
    this.categorieChangee,
  });

  /// Nombre de biens pour un code de type de transaction.
  int compterType(String code) => _duType(code).length;

  /// Nombre de biens d'un type dans un état donné.
  int compterEtat(String code, EtatBien etat) =>
      _duTypeEtEtat(code, etat).length;

  /// Biens d'un type, d'un état et d'un dossier.
  List<Realestate> biensDuDossier(String code, EtatBien etat, int? dossierId) {
    return _duTypeEtEtat(code, etat)
        .where((b) => b.dossier?.id == dossierId)
        .toList();
  }

  /// Dossiers présents dans une vue, du plus fourni au moins fourni.
  ///
  /// Les biens sans dossier sont regroupés à part plutôt que masqués :
  /// ils resteraient sinon introuvables par cette navigation, et c'est
  /// justement là qu'il faut aller les ranger.
  List<GroupeDossier> dossiersDuType(String code, EtatBien etat) {
    final concernes = _duTypeEtEtat(code, etat);

    final parId = <int, GroupeDossier>{};
    var sansDossier = 0;

    for (final b in concernes) {
      final d = b.dossier;
      if (d?.id == null) {
        sansDossier++;
        continue;
      }
      final actuel = parId[d!.id!];
      parId[d.id!] = GroupeDossier(
        id: d.id,
        nom: d.nom ?? 'Sans nom',
        nombre: (actuel?.nombre ?? 0) + 1,
      );
    }

    final liste = parId.values.toList()
      ..sort((a, b) {
        final parNombre = b.nombre.compareTo(a.nombre);
        return parNombre != 0 ? parNombre : a.nom.compareTo(b.nom);
      });

    // Les dossiers vides de cette famille restent visibles : un dossier
    // que l'on vient de créer doit apparaître, même sans bien encore.
    // Ceux d'une autre famille n'ont rien à faire ici.
    for (final d in dossiers ?? <Dossier>[]) {
      if (d.id != null && d.typeCode == code && !parId.containsKey(d.id)) {
        liste.add(GroupeDossier(id: d.id, nom: d.nom ?? 'Sans nom', nombre: 0));
      }
    }

    if (sansDossier > 0) {
      liste.add(GroupeDossier(id: null, nom: 'Sans dossier', nombre: sansDossier));
    }

    return liste;
  }

  List<Realestate> _duType(String code) =>
      (biens ?? []).where((b) => b.typeTransaction?.value == code).toList();

  List<Realestate> _duTypeEtEtat(String code, EtatBien etat) {
    final duType = _duType(code);
    switch (etat) {
      case EtatBien.tous:
        return duType;
      case EtatBien.reserves:
        return duType.where((b) => b.booking != null).toList();
      case EtatBien.disponibles:
        // Sans réservation et sans nettoyage en attente.
        return duType
            .where((b) =>
                b.booking == null && !b.aNettoyer && !b.enNettoyage)
            .toList();
      case EtatBien.nettoyage:
        return duType
            .where((b) => b.booking == null && (b.aNettoyer || b.enNettoyage))
            .toList();
    }
  }

  GroupesState copyWith({
    AppStatus? fetchStatus,
    AppStatus? actionStatus,
    List<Realestate>? biens,
    List<Dossier>? dossiers,
    String? message,
    String? error,
    int? categorieChangee,
  }) {
    return GroupesState(
      fetchStatus: fetchStatus ?? this.fetchStatus,
      // Un statut d'action declenche un message : il ne se conserve pas.
      actionStatus: actionStatus,
      biens: biens ?? this.biens,
      dossiers: dossiers ?? this.dossiers,
      message: message,
      error: error,
      categorieChangee: categorieChangee,
    );
  }
}
