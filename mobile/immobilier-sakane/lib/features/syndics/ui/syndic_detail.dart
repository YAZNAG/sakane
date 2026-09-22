import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/syndics/cubit/syndic_detail_cubit.dart';
import 'package:immobilier/features/syndics/ui/components/syndic_commun.dart';
import 'package:immobilier/features/syndics/ui/historique_envois.dart';
import 'package:immobilier/models/syndic.dart';
import 'package:immobilier/routes.dart';
import 'package:toastification/toastification.dart';

/// La fiche d'un syndic : coordonnées, biens rattachés et historique des
/// envois du contrat.
class SyndicDetailPage extends StatelessWidget {
  const SyndicDetailPage({super.key});

  static Widget page(int id) => BlocProvider(
        create: (_) => SyndicDetailCubit(id)..charger(),
        child: const SyndicDetailPage(),
      );

  Future<void> _modifier(BuildContext context, Syndic syndic) async {
    final cubit = context.read<SyndicDetailCubit>();
    final resultat = await GoRouter.of(context).push<Syndic>(Routes.syndicForm, extra: syndic);
    if (resultat != null) cubit.charger(silencieux: true);
  }

  Future<void> _supprimer(BuildContext context, Syndic syndic) async {
    final cubit = context.read<SyndicDetailCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Supprimer « ${syndic.nom} » ?',
            style: const TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: const Text(
          "Ses biens n'auront plus de syndic.",
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) cubit.supprimer();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SyndicDetailCubit, SyndicDetailState>(
      listener: (context, state) {
        if (state.deleteStatus == AppStatus.success) {
          showToast('Syndic supprimé', context, second: 2);
          GoRouter.of(context).pop(true);
        } else if (state.deleteStatus == AppStatus.error ||
            (state.fetchStatus == AppStatus.error && state.syndic != null)) {
          showToast('', context,
              description: state.error ?? "L'opération n'a pas abouti",
              type: ToastificationType.error,
              second: 3);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SyndicDetailCubit>();
        final syndic = state.syndic;
        final suppression = state.deleteStatus == AppStatus.loading;

        Widget corps;
        if (syndic == null) {
          corps = state.fetchStatus == AppStatus.error
              ? MyErrorWidget(
                  error: state.error ?? 'Erreur',
                  action: AppStrings.tryAgain,
                  actionCLick: () => cubit.charger(),
                )
              : Center(child: MyLoadingIndicator());
        } else {
          corps = RefreshIndicator(
            onRefresh: () => cubit.charger(silencieux: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
              children: [
                _entete(context, syndic),
                if ((syndic.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _bloc(
                    titre: 'Notes',
                    icone: Icons.sticky_note_2_outlined,
                    enfant: Text(syndic.notes!.trim(),
                        style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87)),
                  ),
                ],
                const SizedBox(height: 12),
                _bloc(
                  titre: 'Biens rattachés (${syndic.biens.isNotEmpty ? syndic.biens.length : syndic.nombreBiens})',
                  icone: Icons.home_work_outlined,
                  enfant: syndic.biens.isEmpty
                      ? Text('Aucun bien rattaché à ce syndic.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
                      : Column(
                          children: syndic.biens
                              .map((b) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                      children: [
                                        Icon(Icons.circle, size: 7, color: AppColors.primaryColor),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(b.titre,
                                              style: const TextStyle(
                                                  fontSize: 13.5, color: Colors.black87)),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _bloc(
                  titre: 'Historique des envois',
                  icone: Icons.history,
                  enfant: syndic.envois.isEmpty
                      ? Text(
                          "Aucun envoi pour le moment. Le contrat public part automatiquement "
                          "par WhatsApp à chaque nouvelle réservation, prolongation ou raccourcissement "
                          "dans l'un de ses biens.",
                          style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey.shade600))
                      : Column(
                          children: [
                            for (var i = 0; i < syndic.envois.length; i++) ...[
                              if (i > 0) Divider(height: 18, color: Colors.grey.shade200),
                              _envoi(syndic.envois[i]),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => HistoriqueEnvoisPage.ouvrir(context, syndic: syndic),
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text("Voir tout l'historique"),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              syndic?.nom ?? 'Syndic',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryColor,
            elevation: 0,
            centerTitle: true,
            actions: [
              if (syndic != null && peutVoirHistoriqueSyndics)
                IconButton(
                  tooltip: 'Historique des envois',
                  icon: const Icon(Icons.history),
                  onPressed: () => HistoriqueEnvoisPage.ouvrir(context, syndic: syndic),
                ),
              if (syndic != null && peutModifierSyndic)
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: suppression ? null : () => _modifier(context, syndic),
                ),
              if (syndic != null && peutSupprimerSyndic) ...[
                IconButton(
                  tooltip: 'Supprimer',
                  icon: suppression
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete_outline),
                  onPressed: suppression ? null : () => _supprimer(context, syndic),
                ),
              ],
            ],
          ),
          body: corps,
        );
      },
    );
  }

  Widget _entete(BuildContext context, Syndic s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.apartment, size: 28, color: AppColors.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.nom,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                    const SizedBox(height: 3),
                    Text(s.telephone,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                  ],
                ),
              ),
              EtiquetteActifSyndic(actif: s.actif),
            ],
          ),
          if (!s.actif) ...[
            const SizedBox(height: 10),
            Text(
              "Syndic inactif : aucun contrat ne lui est envoyé.",
              style: TextStyle(fontSize: 12.5, color: Colors.orange.shade800),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => appelerSyndic(context, s.telephone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Appeler'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    side: BorderSide(color: AppColors.primaryColor.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => whatsappSyndic(context, s.telephone),
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bloc({required String titre, required IconData icone, required Widget enfant}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: AppColors.primaryColor),
              const SizedBox(width: 8),
              Text(titre,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
            ],
          ),
          const SizedBox(height: 10),
          enfant,
        ],
      ),
    );
  }

  Widget _envoi(EnvoiSyndic e) {
    final sejour = sejourSyndic(e);
    final couleur = couleurStatutEnvoi(e.statut);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(iconeStatutEnvoi(e.statut), size: 18, color: couleur),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (e.bien ?? '').isEmpty ? 'Bien' : e.bien!,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                  EtiquetteSyndic(texte: libelleStatutEnvoi(e.statut), couleur: couleur),
                ],
              ),
              if (sejour.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sejour, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              ],
              if ((e.erreur ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(e.erreur!, style: TextStyle(fontSize: 12.5, color: couleur)),
              ],
              if (e.le != null) ...[
                const SizedBox(height: 2),
                Text('Le ${dateHeureExport(e.le)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
