import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';

/// Liste des biens en vente. Filtre : tous, a_vendre, compromis, vendu, sans_mandat.
class VentesState {
  final AppStatus? statut;
  final List<BienVente>? biens;
  final String? erreur;
  final String filtre;
  final String recherche;

  const VentesState({
    this.statut,
    this.biens,
    this.erreur,
    this.filtre = 'tous',
    this.recherche = '',
  });

  VentesState copyWith({
    AppStatus? statut,
    List<BienVente>? biens,
    String? erreur,
    String? filtre,
    String? recherche,
  }) {
    return VentesState(
      statut: statut ?? this.statut,
      biens: biens ?? this.biens,
      erreur: erreur ?? this.erreur,
      filtre: filtre ?? this.filtre,
      recherche: recherche ?? this.recherche,
    );
  }
}

class VentesCubit extends Cubit<VentesState> {
  /// Dossier facultatif : id, ou « aucun » pour les biens sans dossier.
  final String? dossier;

  VentesCubit({String filtre = 'tous', this.dossier}) : super(VentesState(filtre: filtre));

  static const Map<String, String> filtres = {
    'tous': 'Tous',
    'a_vendre': 'À vendre',
    'compromis': 'Sous compromis',
    'vendu': 'Vendus',
    'sans_mandat': 'Sans mandat',
  };

  Repository get _depot => Dependencies.get<Repository>();

  /// Une reponse lente ne remplace pas une plus recente.
  int _requete = 0;

  Future<void> charger({bool silencieux = false}) async {
    final numero = ++_requete;
    if (!silencieux || state.biens == null) {
      emit(state.copyWith(statut: AppStatus.loading));
    }
    try {
      final biens = await _depot.fetchBiensVente(filtre: state.filtre, recherche: state.recherche, dossier: dossier);
      if (isClosed || numero != _requete) return;
      emit(state.copyWith(statut: AppStatus.success, biens: biens));
    } catch (ex) {
      if (isClosed || numero != _requete) return;
      emit(state.copyWith(statut: AppStatus.error, erreur: messageErreurBail(ex)));
    }
  }

  void changerFiltre(String filtre) {
    if (filtre == state.filtre) return;
    emit(state.copyWith(filtre: filtre));
    charger(silencieux: true);
  }

  void rechercher(String texte) {
    if (texte.trim() == state.recherche.trim()) return;
    emit(state.copyWith(recherche: texte));
    charger(silencieux: true);
  }
}
