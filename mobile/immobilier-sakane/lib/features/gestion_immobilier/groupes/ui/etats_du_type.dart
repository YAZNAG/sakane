import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/carte_groupe.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/dossiers_du_type.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/groupes_immobilier.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/departs_du_jour.dart';
import 'package:immobilier/features/ventes/ui/components/ventes_commun.dart';
import 'package:immobilier/models/bail.dart';
import 'package:immobilier/models/vente.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:immobilier/routes.dart';

/// Une carte d'etat propre a la longue duree ou a la vente : elle ouvre
/// le module correspondant, deja filtre.
class _CarteEtat {
  final String titre;
  final String sousTitre;
  final IconData icone;
  final List<Color> degrade;
  final int? nombre;
  final String? unite;
  final String route;

  const _CarteEtat({
    required this.titre,
    required this.sousTitre,
    required this.icone,
    required this.degrade,
    required this.nombre,
    required this.route,
    this.unite,
  });
}

/// Deuxième niveau : les états, à l'intérieur d'un type de biens.
///
/// Réservés / disponibles / nettoyage ne valent que pour la location
/// courte durée. La longue durée et la vente ont leurs propres états,
/// comptés par leur tableau de bord.
class EtatsDuTypePage extends StatefulWidget {
  final TypeBien type;

  const EtatsDuTypePage({super.key, required this.type});

  @override
  State<EtatsDuTypePage> createState() => _EtatsDuTypePageState();
}

class _EtatsDuTypePageState extends State<EtatsDuTypePage> {
  TableauBaux? _baux;
  TableauVentes? _ventes;

  TypeBien get type => widget.type;

  @override
  void initState() {
    super.initState();
    _chargerCompteurs();
  }

  /// Les compteurs sont un plus : sans reponse, les cartes restent utilisables.
  Future<void> _chargerCompteurs() async {
    if (!peutVoirBaux) return;
    final depot = Dependencies.get<Repository>();
    try {
      if (type.code == 'rent-long') {
        final t = await depot.fetchTableauBaux();
        if (mounted) setState(() => _baux = t);
      } else if (type.code == 'selle') {
        final t = await depot.fetchTableauVentes();
        if (mounted) setState(() => _ventes = t);
      }
    } catch (_) {}
  }

  Future<void> _actualiser() => Future.wait([
        context.read<GroupesCubit>().charger(),
        _chargerCompteurs(),
      ]);

  List<_CarteEtat> get _cartesLongueDuree {
    final t = _baux;
    return [
      _CarteEtat(
        titre: 'Loués',
        sousTitre: 'Un bail en cours',
        icone: Icons.key_rounded,
        degrade: const [Color(0xFF6D4AB0), Color(0xFFB06AB3)],
        nombre: t == null ? null : t.biens - t.biensLibres,
        route: '${Routes.baux}?onglet=logements&filtre=loues',
      ),
      _CarteEtat(
        titre: 'Libres',
        sousTitre: 'Aucun bail : prêts à être loués',
        icone: Icons.lock_open_rounded,
        degrade: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        nombre: t?.biensLibres,
        route: '${Routes.baux}?onglet=logements&filtre=libres',
      ),
      _CarteEtat(
        titre: 'Loyers impayés',
        sousTitre: t == null || t.impayesTotal <= 0 ? 'Locataires en retard' : 'Reste dû : ${prixSimple(t.impayesTotal)} MAD',
        icone: Icons.money_off_csred_outlined,
        degrade: const [Color(0xFFE53935), Color(0xFFFF7043)],
        nombre: t?.impayesLocataires,
        unite: (t?.impayesLocataires ?? 0) > 1 ? 'LOCATAIRES' : 'LOCATAIRE',
        route: '${Routes.baux}?onglet=baux&filtre=impayes',
      ),
      _CarteEtat(
        titre: 'Baux qui se terminent',
        sousTitre: 'Dans les 60 prochains jours',
        icone: Icons.hourglass_bottom_rounded,
        degrade: const [Color(0xFFEF6C00), Color(0xFFFFB300)],
        nombre: t?.finissants.length,
        unite: (t?.finissants.length ?? 0) > 1 ? 'BAUX' : 'BAIL',
        route: '${Routes.baux}?onglet=baux&filtre=finissants',
      ),
    ];
  }

  List<_CarteEtat> get _cartesVente {
    final t = _ventes;
    return [
      _CarteEtat(
        titre: 'À vendre',
        sousTitre: 'En vente, sans compromis',
        icone: Icons.sell_outlined,
        degrade: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        nombre: t?.aVendre,
        route: cheminVentes(filtre: 'a_vendre'),
      ),
      _CarteEtat(
        titre: 'Sous compromis',
        sousTitre: 'Compromis de vente signé',
        icone: Icons.handshake_outlined,
        degrade: const [Color(0xFF1565C0), Color(0xFF42A5F5)],
        nombre: t?.compromis,
        route: cheminVentes(filtre: 'compromis'),
      ),
      _CarteEtat(
        titre: 'Vendus',
        sousTitre: 'Ventes conclues',
        icone: Icons.verified_outlined,
        degrade: const [Color(0xFF6D4AB0), Color(0xFFB06AB3)],
        nombre: t?.vendus,
        route: cheminVentes(filtre: 'vendu'),
      ),
      _CarteEtat(
        titre: 'Sans mandat',
        sousTitre: 'Aucun mandat de vente actif',
        icone: Icons.assignment_late_outlined,
        degrade: const [Color(0xFFEF6C00), Color(0xFFFFB300)],
        nombre: t?.sansMandat,
        route: cheminVentes(filtre: 'sans_mandat'),
      ),
      _CarteEtat(
        titre: 'Visites',
        sousTitre: 'Les visites récentes',
        icone: Icons.directions_walk,
        degrade: const [Color(0xFFE53935), Color(0xFFFF7043)],
        nombre: t?.visitesCeMois,
        unite: 'CE MOIS',
        route: Routes.visitesVentes,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(title: Text(type.titre), centerTitle: true),
      body: BlocBuilder<GroupesCubit, GroupesState>(
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final courteDuree = type.code != 'rent-long' && type.code != 'selle';
          final cartes = type.code == 'rent-long'
              ? _cartesLongueDuree
              : type.code == 'selle'
                  ? _cartesVente
                  : const <_CarteEtat>[];

          return RefreshIndicator(
            onRefresh: _actualiser,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: [
                if (courteDuree)
                  ...EtatBien.values.map((etat) => CarteGroupe(
                        nombre: state.compterEtat(type.code, etat),
                        titre: etat.titre,
                        sousTitre: etat.sousTitre,
                        libelleAction: 'Voir les dossiers',
                        icone: etat.icone,
                        degrade: etat.degrade,
                        onTap: () => _ouvrir(context, etat),
                      ))
                else ...[
                  // « Tous les biens » garde les dossiers : c'est la qu'on range.
                  CarteGroupe(
                    nombre: state.compterEtat(type.code, EtatBien.tous),
                    titre: EtatBien.tous.titre,
                    sousTitre: EtatBien.tous.sousTitre,
                    libelleAction: 'Voir les dossiers',
                    icone: EtatBien.tous.icone,
                    degrade: EtatBien.tous.degrade,
                    onTap: () => _ouvrir(context, EtatBien.tous),
                  ),
                  ...cartes.map((c) => CarteGroupe(
                        nombre: c.nombre,
                        unite: c.unite,
                        titre: c.titre,
                        sousTitre: c.sousTitre,
                        libelleAction: 'Voir la liste',
                        icone: c.icone,
                        degrade: c.degrade,
                        onTap: () => _ouvrirModule(c.route),
                      )),
                ],
                // Les departs du jour appartiennent a la courte duree.
                if (type.code == 'rent-short') ...[
                  const SizedBox(height: 10),
                  const DepartsDuJour(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _ouvrirModule(String route) async {
    await GoRouter.of(context).push(route);
    if (mounted) _chargerCompteurs();
  }

  /// Chaque etat passe par les dossiers : c'est la structure de rangement
  /// de cette application, elle vaut aussi pour les etats operationnels.
  void _ouvrir(BuildContext context, EtatBien etat) {
    final cubit = context.read<GroupesCubit>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: DossiersDuTypePage(type: type, etat: etat),
      ),
    ));
  }
}
