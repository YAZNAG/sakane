import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/logout.dart';
import 'package:immobilier/exceptions/network_connectivity_exception.dart';
import 'package:immobilier/exceptions/unauthenticated_exception.dart';
import 'package:immobilier/models/categories_immobilier.dart';
import 'package:immobilier/repository/repository.dart';

/// Les compteurs des trois familles de biens.
///
/// L'écran reste utilisable sans eux : l'erreur est portée par l'état,
/// les cartes s'affichent quand même, et seuls les nombres manquent.
class CategoriesImmobilierState {
  final AppStatus? statut;
  final CategoriesImmobilier? donnees;
  final String? erreur;

  const CategoriesImmobilierState({this.statut, this.donnees, this.erreur});

  /// Vrai tant qu'aucune réponse n'est arrivée : l'écran montre alors
  /// son squelette plutôt que des zéros.
  bool get premiereLecture => donnees == null && statut != AppStatus.error;

  CategoriesImmobilierState copyWith({
    AppStatus? statut,
    CategoriesImmobilier? donnees,
    String? erreur,
  }) {
    return CategoriesImmobilierState(
      statut: statut ?? this.statut,
      donnees: donnees ?? this.donnees,
      erreur: erreur,
    );
  }
}

class CategoriesImmobilierCubit extends Cubit<CategoriesImmobilierState> {
  CategoriesImmobilierCubit() : super(const CategoriesImmobilierState());

  Repository get _depot => Dependencies.get<Repository>();

  /// Une réponse lente ne remplace pas une plus récente.
  int _requete = 0;

  Future<void> charger() async {
    final numero = ++_requete;
    emit(state.copyWith(statut: AppStatus.loading));
    try {
      final donnees = await _depot.categoriesImmobilier();
      if (isClosed || numero != _requete) return;
      emit(CategoriesImmobilierState(
        statut: AppStatus.success,
        donnees: donnees,
      ));
    } on UnAuthenticatedException {
      logout();
    } catch (ex) {
      if (isClosed || numero != _requete) return;
      // Les chiffres déjà lus sont conservés : ils valent mieux que rien
      // le temps que la connexion revienne.
      emit(CategoriesImmobilierState(
        statut: AppStatus.error,
        donnees: state.donnees,
        erreur: _message(ex),
      ));
    }
  }

  String _message(Object ex) {
    if (ex is NetworkConnectivityException) return AppStrings.checkConnectivity;
    final texte = ex.toString();
    if (texte.startsWith('Exception: ') && texte.length > 11) {
      return texte.substring(11);
    }
    return "Les compteurs n'ont pas pu être lus.";
  }
}
