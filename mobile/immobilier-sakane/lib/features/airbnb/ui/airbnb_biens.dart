import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/airbnb/cubit/airbnb_biens_cubit.dart';
import 'package:immobilier/features/airbnb/cubit/reservations_airbnb_cubit.dart';
import 'package:immobilier/features/airbnb/ui/components/carte_reservation_airbnb.dart';
import 'package:immobilier/features/airbnb/ui/components/outils_airbnb.dart';
import 'package:immobilier/features/calendrier_bien/ui/components/outils_calendrier.dart';
import 'package:immobilier/models/airbnb.dart';

/// Vue d'ensemble : la liaison Airbnb de chaque bien, et les
/// reservations Airbnb a transformer en contrats.
class AirbnbBiensPage extends StatelessWidget {
  const AirbnbBiensPage({super.key});

  static Widget page() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AirbnbBiensCubit()..charger()),
        BlocProvider(create: (_) => ReservationsAirbnbCubit()..charger()),
      ],
      child: const AirbnbBiensPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: CouleursCalendrier.fond,
        appBar: AppBar(
          title: const Text('Airbnb', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primaryColor,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Biens'),
              Tab(text: 'Réservations Airbnb'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ongletBiens(),
            const _OngletReservationsAirbnb(),
          ],
        ),
      ),
    );
  }

  Widget _ongletBiens() {
    return BlocBuilder<AirbnbBiensCubit, AirbnbBiensState>(
        builder: (context, state) {
          final biens = state.biens;
          if (biens == null) {
            if (state.statut == AppStatus.error) {
              return Center(
                child: MyErrorWidget(
                  error: state.erreur ?? "La liste n'a pas pu être chargée.",
                  action: 'Réessayer',
                  actionCLick: () => context.read<AirbnbBiensCubit>().charger(),
                ),
              );
            }
            return Center(child: MyLoadingIndicator());
          }
          final relies = biens.where((b) => b.relie).length;
          final erreurs = biens.where((b) => b.relie && b.enErreur).length;
          return RefreshIndicator(
            onRefresh: () => context.read<AirbnbBiensCubit>().charger(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: biens.length + 1,
              separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 14 : 8),
              itemBuilder: (context, i) {
                if (i == 0) return _resume(relies, biens.length, erreurs);
                return _ligne(context, biens[i - 1]);
              },
            ),
          );
        },
    );
  }

  Widget _resume(int relies, int total, int erreurs) {
    return Row(
      children: [
        const FaIcon(FontAwesomeIcons.airbnb, color: CouleursAirbnb.rose, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$relies bien${relies > 1 ? 's' : ''} relié${relies > 1 ? 's' : ''} sur $total'
            '${erreurs > 0 ? ' • ${pluriel(erreurs, 'erreur')}' : ''}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CouleursCalendrier.texte),
          ),
        ),
      ],
    );
  }

  Widget _ligne(BuildContext context, BienAirbnb b) {
    final String etat;
    final Color couleur;
    final IconData icone;
    if (!b.relie) {
      etat = 'Non relié';
      couleur = CouleursCalendrier.texteDoux;
      icone = Icons.link_off;
    } else if (b.enErreur) {
      etat = b.erreur ?? 'La dernière synchronisation a échoué.';
      couleur = CouleursCalendrier.erreur;
      icone = Icons.cancel;
    } else if (b.derniereSyncA != null) {
      etat = 'Synchronisé ${ilYA(b.derniereSyncA!)}';
      couleur = CouleursAirbnb.succes;
      icone = Icons.check_circle;
    } else {
      etat = 'Relié, en attente de synchronisation';
      couleur = CouleursCalendrier.texteDoux;
      icone = Icons.schedule;
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await GoRouter.of(context).push(cheminAirbnbBien(b.bienId, titre: b.titre));
          if (context.mounted) {
            context.read<AirbnbBiensCubit>().charger();
            // Un contrat a pu etre cree depuis la page du bien.
            context.read<ReservationsAirbnbCubit>().charger();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CouleursCalendrier.bordure),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (b.relie ? CouleursAirbnb.rose : CouleursCalendrier.texteDoux).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(FontAwesomeIcons.airbnb,
                    size: 20, color: b.relie ? CouleursAirbnb.rose : CouleursCalendrier.rayures),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.titre.isEmpty ? 'Bien #${b.bienId}' : b.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: CouleursCalendrier.texte)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(icone, size: 14, color: couleur),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(etat,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: couleur)),
                        ),
                      ],
                    ),
                    if (b.relie || b.derniereLectureAirbnbA != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          b.derniereLectureAirbnbA != null
                              ? 'Lu par Airbnb ${ilYA(b.derniereLectureAirbnbA!)}'
                              : 'Pas encore lu par Airbnb',
                          style: const TextStyle(fontSize: 12, color: CouleursCalendrier.texteDoux),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF98A6AE)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les reservations Airbnb de tous les biens : « Ajouter un contrat »
/// ou « Voir la réservation ».
class _OngletReservationsAirbnb extends StatelessWidget {
  const _OngletReservationsAirbnb();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReservationsAirbnbCubit, ReservationsAirbnbState>(
      builder: (context, state) {
        final sejours = state.sejours;
        final cubit = context.read<ReservationsAirbnbCubit>();
        if (sejours == null) {
          if (state.statut == AppStatus.error) {
            return Center(
              child: MyErrorWidget(
                error: state.erreur ?? "Les réservations Airbnb n'ont pas pu être chargées.",
                action: 'Réessayer',
                actionCLick: () => cubit.charger(),
              ),
            );
          }
          return Center(child: MyLoadingIndicator());
        }
        return RefreshIndicator(
          onRefresh: () => cubit.charger(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            itemCount: sejours.isEmpty ? 2 : sejours.length + 1,
            separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 14 : 10),
            itemBuilder: (context, i) {
              if (i == 0) return _resume(sejours.length, state.sansContrat);
              if (sejours.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Text(
                    'Aucune réservation Airbnb à venir ni sur les 30 derniers jours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: CouleursCalendrier.texteDoux),
                  ),
                );
              }
              return CarteReservationAirbnb(
                sejour: sejours[i - 1],
                onChange: () => cubit.charger(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _resume(int total, int sansContrat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const FaIcon(FontAwesomeIcons.airbnb, color: CouleursAirbnb.rose, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${pluriel(total, 'réservation')}'
                '${sansContrat > 0 ? ' • $sansContrat sans contrat' : ''}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CouleursCalendrier.texte),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'À venir et des 30 derniers jours. Créez le contrat de chaque séjour : '
          'les dates sont bloquées et le montant Airbnb n’entre pas dans la caisse.',
          style: TextStyle(fontSize: 12, color: CouleursCalendrier.texteDoux),
        ),
      ],
    );
  }
}
