import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/core/utils/show_dialogue_question.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/gestion_immobilier/home/cubit/gestion_immobilier_cubit.dart';
import 'package:immobilier/models/manager.dart';
import 'package:immobilier/models/realestate.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// Départs du jour, avec confirmation du départ.
///
/// Cette liste appartient à la location courte durée : c'est là que les
/// départs se produisent, et là qu'on vient les surveiller. Elle porte
/// son propre chargement pour rester utilisable depuis n'importe quel
/// écran.
class DepartsDuJour extends StatelessWidget {
  const DepartsDuJour({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Dependencies.get<Manager>();
    if (!manager.can(AppPermission.viewTodayCheckouts)) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) => GestionImmobilierCubit()..fetchData(),
      child: const _Contenu(),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GestionImmobilierCubit, GestionImmobilierState>(
      listener: (context, state) {
        if (state.actionStatus == AppStatus.success) {
          showToast("Départ confirmé", context, second: 2);
        } else if (state.actionStatus == AppStatus.error) {
          showToast("", context,
              description: "L'opération n'a pas abouti",
              type: ToastificationType.error,
              second: 3);
        }
      },
      builder: (context, state) {
        final departs = state.immobilierOverview?.realestates ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note, color: Colors.grey.shade700, size: 22),
                const SizedBox(width: 8),
                Text(
                  "Départs du jour",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (departs.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${departs.length}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (state.fetchDataStatus == AppStatus.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (departs.isEmpty)
              _aucunDepart()
            else
              ...departs.map((r) => _carte(context, r)),
          ],
        );
      },
    );
  }

  Widget _aucunDepart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 34, color: Colors.green.shade400),
          const SizedBox(height: 8),
          Text(
            "Aucun départ prévu aujourd'hui",
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _carte(BuildContext context, Realestate realestate) {
    final booking = realestate.booking;
    final client = booking?.client;
    final image = realestate.media?.isNotEmpty == true
        ? realestate.media!.first.url
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => GoRouter.of(context).push(
                  Routes.homeImmobilier
                      .replaceFirst(":id", realestate.id.toString()),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: image != null
                      ? Image.network(image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _vignette())
                      : _vignette(),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      realestate.title ?? "Appartement",
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            client?.fullName ?? "Client inconnu",
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.logout,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          booking?.checkout?.formattedDateFr ?? '-',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (Dependencies.get<Manager>().can(AppPermission.confirmCheckout)) ...[
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmer(context, realestate),
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Confirmer le départ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _vignette() => Container(
        width: 56,
        height: 56,
        color: Colors.grey.shade200,
        child: Icon(Icons.home_work_outlined,
            size: 24, color: Colors.grey.shade500),
      );

  void _confirmer(BuildContext context, Realestate realestate) async {
    final cubit = context.read<GestionImmobilierCubit>();
    final ok = await showDialogueQuestion(
      context,
      "Confirmer le départ du client de « ${realestate.title} » ?",
      "Confirmer",
      "Annuler",
    );
    if (ok == true) cubit.confirmDepart(realestate);
  }
}
