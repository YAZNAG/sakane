import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/rafraichissement_auto.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart'
    show peutVoirBaux;
import 'package:immobilier/features/biens_desactives/outils_desactivation.dart'
    show peutVoirBiensDesactives;
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/features/gestion_immobilier/home/cubit/categories_immobilier_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/home/ui/components/barre_basse_immobilier.dart';
import 'package:immobilier/features/gestion_immobilier/home/ui/components/carte_categorie.dart';
import 'package:immobilier/features/home/ui/components/accueil_commun.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart'
    show peutVoirVentes;
import 'package:immobilier/models/categories_immobilier.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/routes.dart';

/// L'habillage d'une famille de biens, connu de l'application.
///
/// Le serveur nomme son icône et sa teinte ; ces valeurs-ci servent de
/// repli, et font que l'écran s'affiche complet même sans réponse.
class _Famille {
  final String code;
  final String titre;
  final String detail;
  final IconData icone;
  final Color teinte;

  const _Famille({
    required this.code,
    required this.titre,
    required this.detail,
    required this.icone,
    required this.teinte,
  });
}

/// Les trois familles, dans l'ordre de la maquette.
const List<_Famille> _familles = [
  _Famille(
    code: 'rent-short',
    titre: 'Location vacances',
    detail: 'Courte durée · nuitées, Airbnb',
    icone: Icons.vpn_key_outlined,
    teinte: Color(0xFF1F7A5E),
  ),
  _Famille(
    code: 'rent-long',
    titre: 'Location longue durée',
    detail: 'Baux, loyers, échéances',
    icone: Icons.description_outlined,
    teinte: Color(0xFF6D4AB0),
  ),
  _Famille(
    code: 'selle',
    titre: 'Vente de biens',
    detail: 'Mandats, visites, signature',
    icone: Icons.sell_outlined,
    teinte: Color(0xFFE8710A),
  ),
];

/// Les droits qui ouvrent la location vacances : la liste des biens ou
/// l'un de ses états.
const List<AppPermission> _droitsBiens = [
  AppPermission.viewProperties,
  AppPermission.viewAvailableProperties,
  AppPermission.viewReservedProperties,
  AppPermission.viewCleaningProperties,
];

/// Le nom d'icône rendu par le serveur, traduit en dessin.
IconData _iconeNommee(String nom, IconData defaut) {
  switch (nom) {
    case 'key':
    case 'cle':
      return Icons.vpn_key_outlined;
    case 'document':
    case 'contrat':
    case 'contract':
    case 'description':
      return Icons.description_outlined;
    case 'tag':
    case 'label':
    case 'etiquette':
    case 'sell':
      return Icons.sell_outlined;
    default:
      return defaut;
  }
}

/// Le nom de teinte rendu par le serveur, traduit en couleur.
Color _teinteNommee(String nom, Color defaut) {
  switch (nom) {
    case 'vert':
    case 'green':
      return const Color(0xFF1F7A5E);
    case 'violet':
    case 'purple':
      return const Color(0xFF6D4AB0);
    case 'orange':
      return const Color(0xFFE8710A);
    case 'bleu':
    case 'blue':
      return const Color(0xFF3B6FD4);
    case 'rouge':
    case 'red':
      return const Color(0xFFE03E3E);
    default:
      return defaut;
  }
}

/// La teinte d'une pastille. Les impayés sont rouges quoi qu'il arrive :
/// c'est le seul état qui appelle une action.
Color _teintePastille(EtatCategorie etat, Color defaut) {
  if (etat.code == 'impayes') return rougeAccueil;
  return _teinteNommee(etat.ton, defaut);
}

/// Le premier niveau de la gestion des biens : trois catégories, et le
/// choix qu'il faut faire avant d'entrer.
///
/// Les compteurs viennent du serveur (`/dashboard/immobilier/categories`) ;
/// l'intérieur de chaque catégorie reste le parcours existant.
class GestionImmobilierHome extends StatefulWidget {
  const GestionImmobilierHome({super.key});

  static Widget page() {
    return BlocProvider<CategoriesImmobilierCubit>(
      create: (_) => CategoriesImmobilierCubit()..charger(),
      child: const GestionImmobilierHome(),
    );
  }

  @override
  State<GestionImmobilierHome> createState() => _GestionImmobilierHomeState();
}

class _GestionImmobilierHomeState extends State<GestionImmobilierHome>
    with RafraichissementAuto<GestionImmobilierHome> {
  @override
  void rafraichir() {
    if (!mounted) return;
    context.read<CategoriesImmobilierCubit>().charger();
  }

  /// Les familles que l'utilisateur a le droit de voir. Sans droit sur
  /// une famille, sa carte n'existe pas.
  List<_Famille> get _famillesVisibles =>
      _familles.where((f) => _voitFamille(f.code)).toList();

  bool _voitFamille(String code) {
    switch (code) {
      case 'rent-long':
        return peutVoirBaux;
      case 'selle':
        return peutVoirVentes;
      default:
        return _droitsBiens.any(_peut);
    }
  }

  /// Un utilisateur pas encore chargé n'a simplement pas le droit.
  bool _peut(AppPermission droit) {
    try {
      return Dependencies.get<Manager>().can(droit);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondAccueil,
      appBar: AppBar(
        backgroundColor: fondAccueil,
        surfaceTintColor: Colors.transparent,
        foregroundColor: texteAccueil,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back, color: texteAccueil),
          onPressed: _retour,
        ),
        title: const Text(
          'Immobilier',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: texteAccueil,
          ),
        ),
        actions: [
          // Raccourci vers le module Airbnb, garde a la demande du client.
          if (_peut(AppPermission.viewAirbnb))
            IconButton(
              tooltip: 'Airbnb',
              icon: const Icon(Icons.house_rounded, color: rougeAccueil),
              onPressed: () => _naviguer(Routes.airbnbBiens),
            ),
          if (_peut(AppPermission.viewProperties))
            IconButton(
              tooltip: 'Rechercher un bien',
              icon: const Icon(Icons.search_rounded, color: texteAccueil),
              onPressed: _rechercherUnBien,
            ),
        ],
      ),
      body: BlocBuilder<CategoriesImmobilierCubit, CategoriesImmobilierState>(
        builder: (context, etat) => RefreshIndicator(
          onRefresh: () => context.read<CategoriesImmobilierCubit>().charger(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: _corps(etat),
          ),
        ),
      ),
      bottomNavigationBar: const BarreBasseImmobilier(),
    );
  }

  List<Widget> _corps(CategoriesImmobilierState etat) {
    final donnees = etat.donnees;
    final familles = _famillesVisibles;

    return [
      const Text(
        'Quelle catégorie ?',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: texteAccueil,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        _sousTitre(donnees),
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: texteDouxAccueil,
        ),
      ),
      const SizedBox(height: 16),

      // Les compteurs manquent : le reste de l'écran fonctionne, les
      // catégories s'ouvrent. Seuls les nombres attendent.
      if (etat.statut == AppStatus.error) ...[
        CarteErreurResume(
          message: etat.erreur,
          onReessayer: () =>
              context.read<CategoriesImmobilierCubit>().charger(),
        ),
        const SizedBox(height: 12),
      ],

      if (etat.premiereLecture)
        for (var i = 0; i < (familles.isEmpty ? 3 : familles.length); i++)
          const SqueletteCarteCategorie()
      else ...[
        for (final famille in familles)
          _carte(famille, donnees?.parCode(famille.code)),
        if (familles.isEmpty) _aucunAcces(),
      ],

      if (!etat.premiereLecture && familles.isNotEmpty) ...[
        const SizedBox(height: 4),
        _boutons(donnees),
      ],
    ];
  }

  String _sousTitre(CategoriesImmobilier? donnees) {
    if (donnees == null) return 'Choisissez une catégorie avant d\'entrer.';
    final total = donnees.total;
    final mot = total == 1 ? 'bien' : 'biens';
    return '$total $mot au total · choisissez avant d\'entrer';
  }

  Widget _carte(_Famille famille, CategorieImmobilier? categorie) {
    final teinte = categorie == null
        ? famille.teinte
        : _teinteNommee(categorie.couleur, famille.teinte);

    return CarteCategorie(
      titre: categorie?.libelle.isNotEmpty == true
          ? categorie!.libelle
          : famille.titre,
      detail: categorie?.detail.isNotEmpty == true
          ? categorie!.detail
          : famille.detail,
      icone: categorie == null
          ? famille.icone
          : _iconeNommee(categorie.icone, famille.icone),
      teinte: teinte,
      nombre: categorie?.total,
      pastilles: _pastilles(famille.code, categorie, teinte),
      onOuvrir: () => _ouvrirCategorie(famille.code),
    );
  }

  /// Les états d'une famille. Un état vide ne s'affiche pas : la carte
  /// ne montre que ce qui existe. Une famille sans aucun bien le dit.
  List<EtatPastille> _pastilles(
    String code,
    CategorieImmobilier? categorie,
    Color teinte,
  ) {
    if (categorie == null) return const [];

    final pleins = categorie.etats.where((e) => e.nombre > 0).toList();
    if (pleins.isEmpty) {
      return const [
        EtatPastille(libelle: 'Aucun bien', teinte: texteDouxAccueil),
      ];
    }

    return pleins.map((e) {
      final route = _routePastille(code, e.code);
      return EtatPastille(
        libelle: e.libelle.isEmpty ? e.code : e.libelle,
        nombre: e.nombre,
        teinte: _teintePastille(e, teinte),
        onTap: route == null ? null : () => _naviguer(route),
      );
    }).toList();
  }

  /// La liste filtrée qu'ouvre une pastille, dans le module de sa
  /// famille. Nulle : l'état n'a pas d'écran à lui.
  String? _routePastille(String famille, String etat) {
    switch (famille) {
      case 'rent-short':
        if (const ['available', 'reserved', 'cleaning'].contains(etat)) {
          return '${Routes.immobilierByStatus.replaceFirst(':status', etat)}'
              '?type=rent-short';
        }
        return '${Routes.immobilier}?type=rent-short';

      case 'rent-long':
        // Les loyers impayés se lisent sur les baux ; loués et libres
        // décrivent les logements.
        switch (etat) {
          case 'impayes':
            return '${Routes.baux}?onglet=baux&filtre=impayes';
          case 'loues':
            return '${Routes.baux}?onglet=logements&filtre=loues';
          case 'libres':
            return '${Routes.baux}?onglet=logements&filtre=libres';
          default:
            return '${Routes.baux}?onglet=baux&filtre=tous';
        }

      case 'selle':
        const filtres = {
          'a_vendre': 'a_vendre',
          'sous_compromis': 'compromis',
          'compromis': 'compromis',
          'sans_mandat': 'sans_mandat',
          'vendu': 'vendu',
        };
        return '${Routes.ventes}?filtre=${filtres[etat] ?? 'tous'}';
    }
    return null;
  }

  Widget _boutons(CategoriesImmobilier? donnees) {
    final total = donnees?.total;
    final desactives = donnees?.desactives ?? 0;

    final tousLesBiens = _peut(AppPermission.viewProperties);
    // Un compte à zéro n'appelle aucun écran : le bouton disparaît.
    final voirDesactives = peutVoirBiensDesactives() && desactives > 0;

    if (!tousLesBiens && !voirDesactives) return const SizedBox.shrink();

    return Row(
      children: [
        if (tousLesBiens)
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => _naviguer(Routes.immobilier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  total == null ? 'Tous les biens' : 'Tous les biens · $total',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (tousLesBiens && voirDesactives) const SizedBox(width: 10),
        if (voirDesactives)
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => _naviguer(Routes.biensDesactives),
                style: OutlinedButton.styleFrom(
                  foregroundColor: texteAccueil,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: bordureAccueil),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Désactivés · $desactives',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Aucun droit sur aucune famille : l'écran le dit plutôt que de
  /// rester vide.
  Widget _aucunAcces() {
    return const CarteAccueil(
      padding: EdgeInsets.fromLTRB(16, 22, 16, 22),
      child: Column(
        children: [
          Icon(Icons.lock_outline, size: 34, color: texteDouxAccueil),
          SizedBox(height: 12),
          Text(
            "Aucune catégorie de biens ne vous est ouverte.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: texteDouxAccueil),
          ),
        ],
      ),
    );
  }

  /// Le parcours existant de la famille : ses états pour la location, ses
  /// dossiers pour la vente.
  void _ouvrirCategorie(String code) async {
    final type = typesDeBiens.firstWhere(
      (t) => t.code == code,
      orElse: () => typesDeBiens.first,
    );
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => GroupesCubit()..charger(),
        child: pageDuType(type),
      ),
    ));
    rafraichir();
  }

  /// La liste des biens, le champ de recherche déjà ouvert.
  void _rechercherUnBien() => _naviguer('${Routes.immobilier}?recherche=1');

  void _naviguer(String route) async {
    await GoRouter.of(context).push(route);
    rafraichir();
  }

  void _retour() {
    final navigateur = Navigator.of(context);
    if (navigateur.canPop()) {
      navigateur.pop();
    } else {
      GoRouter.of(context).go(Routes.home);
    }
  }
}
