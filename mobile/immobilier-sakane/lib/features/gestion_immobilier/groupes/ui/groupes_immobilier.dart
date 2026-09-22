import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/bandeau_synchro.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/groupes_cubit.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/components/carte_groupe.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/cubit/etat_bien.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/dossiers_du_type.dart';
import 'package:immobilier/features/gestion_immobilier/groupes/ui/etats_du_type.dart';

/// Un groupe de biens : un type de transaction et son habillage.
class TypeBien {
  final String code;
  final String titre;
  final String sousTitre;
  final String action;
  final IconData icone;
  final List<Color> degrade;

  const TypeBien({
    required this.code,
    required this.titre,
    required this.sousTitre,
    required this.action,
    required this.icone,
    required this.degrade,
  });
}

/// Les trois familles de biens, dans l'ordre d'affichage.
const List<TypeBien> typesDeBiens = [
  TypeBien(
    code: 'rent-short',
    titre: 'Location courte durée',
    sousTitre: 'Locations saisonnières et vacances',
    action: 'Voir les locations',
    icone: Icons.beach_access,
    degrade: [Color(0xFF96E63C), Color(0xFF11B5A0)],
  ),
  TypeBien(
    code: 'rent-long',
    titre: 'Location longue durée',
    sousTitre: 'Locations en résidences principales',
    action: 'Voir les locations',
    icone: Icons.apartment,
    degrade: [Color(0xFF6A11CB), Color(0xFFEC4899)],
  ),
  TypeBien(
    code: 'selle',
    titre: 'Vente de bien',
    sousTitre: 'Biens à vendre',
    action: 'Voir les biens',
    icone: Icons.sell,
    degrade: [Color(0xFFF2404E), Color(0xFFFCA13A)],
  ),
];

TypeBien get typeVente => typesDeBiens.firstWhere((t) => t.code == 'selle');

/// La page d'un type. La vente ouvre directement ses dossiers : les
/// statuts y figurent en tete, comme compteurs.
Widget pageDuType(TypeBien type) =>
    type.code == 'selle' ? DossiersDuTypePage(type: type, etat: EtatBien.tous) : EtatsDuTypePage(type: type);

/// Entree directe du module Vente (route), avec sa propre liste de biens.
Widget pageDossiersVente() => BlocProvider(
      create: (_) => GroupesCubit()..charger(),
      child: DossiersDuTypePage(type: typeVente, etat: EtatBien.tous),
    );

/// Premier niveau de navigation : les biens regroupés par type.
class GroupesImmobilierPage extends StatelessWidget {
  const GroupesImmobilierPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => GroupesCubit()..charger(),
        child: const GroupesImmobilierPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Gestion Immobilier'),
        centerTitle: true,
      ),
      body: BlocBuilder<GroupesCubit, GroupesState>(
        builder: (context, state) {
          if (state.fetchStatus == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }
          if (state.fetchStatus == AppStatus.error) {
            return MyErrorWidget(
              error: state.error ?? "Erreur",
              action: AppStrings.tryAgain,
              actionCLick: () => context.read<GroupesCubit>().charger(),
            );
          }

          return Column(
            children: [
              const BandeauSynchro(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => context.read<GroupesCubit>().charger(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                    children: typesDeBiens
                        .map((t) => CarteGroupe(
                              nombre: state.compterType(t.code),
                              titre: t.titre,
                              sousTitre: t.sousTitre,
                              libelleAction: t.action,
                              icone: t.icone,
                              degrade: t.degrade,
                              onTap: () => _ouvrir(context, t),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _ouvrir(BuildContext context, TypeBien type) {
    final cubit = context.read<GroupesCubit>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: pageDuType(type),
      ),
    ));
  }
}
