import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/constants/enums/permissions.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/icones_serveur.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/features/activite_equipe/commun/activite_ui.dart';
import 'package:immobilier/features/charges_new/fixes/cubit/charges_fixes_cubit.dart';
import 'package:immobilier/features/charges_new/fixes/ui/components/formulaire_charge_fixe.dart';
import 'package:immobilier/models/charge.dart';
import 'package:immobilier/models/charge_fixe.dart';
import 'package:immobilier/models/manager.dart';
import 'package:toastification/toastification.dart';

/// Les charges fixes de l'agence : ce qui revient chaque mois, rangé par
/// famille — salaires, abonnements, loyers, taxes — avec ce que chaque
/// famille coûte sur la période, et les échéances qui les ramènent.
class ChargesFixesPage extends StatelessWidget {
  const ChargesFixesPage({super.key});

  static Widget page() => BlocProvider<ChargesFixesCubit>(
        create: (_) => ChargesFixesCubit(),
        child: const ChargesFixesPage(),
      );

  Manager get _manager => Dependencies.get<Manager>();

  @override
  Widget build(BuildContext context) {
    final peutAjouter = _manager.can(AppPermission.createFixedCharge);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Charges fixes',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      floatingActionButton: !peutAjouter
          ? null
          : Builder(
              builder: (ctx) => FloatingActionButton.extended(
                onPressed: () => _ajouter(ctx),
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Charge fixe',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
      body: BlocConsumer<ChargesFixesCubit, ChargesFixesState>(
        listenWhen: (avant, apres) =>
            avant.actionStatus != apres.actionStatus &&
            apres.actionStatus == AppStatus.error,
        listener: (context, state) {
          showToast('', context,
              description: state.error ?? 'Action impossible',
              type: ToastificationType.error,
              second: 4);
        },
        builder: (context, state) {
          if (state.enAttente) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: SqueletteActivite(totaux: 4, lignes: 4),
            );
          }

          if (state.fetchStatus == AppStatus.error && state.donnees == null) {
            return ErreurActivite(
              message: state.error ?? 'Les charges fixes sont introuvables.',
              onReessayer: () => context.read<ChargesFixesCubit>().charger(),
            );
          }

          final donnees = state.donnees;
          if (donnees == null) return const SizedBox();

          return RefreshIndicator(
            onRefresh: () => context.read<ChargesFixesCubit>().charger(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 92),
              children: [
                _filtres(context, state),
                const SizedBox(height: 12),
                _totaux(donnees),
                const SizedBox(height: 14),
                if (donnees.catalogue.isNotEmpty) ...[
                  _puceFamilles(context, state, donnees),
                  const SizedBox(height: 12),
                ],
                if (state.vide)
                  const VideActivite(
                    titre: 'Aucune charge fixe sur cette période',
                    detail:
                        'Salaires, abonnements, loyers, taxes : ajoutez-les ici pour les suivre par famille, et les répéter chaque mois.',
                    icone: Icons.receipt_long_outlined,
                  )
                else ...[
                  ...donnees.familles
                      .map((f) => _famille(context, state, donnees, f)),
                  if (donnees.recurrences.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _echeances(context, donnees),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── L'en-tête ─────────────────────────────────────────────────────

  Widget _filtres(BuildContext context, ChargesFixesState state) {
    final cubit = context.read<ChargesFixesCubit>();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: carteActivite,
      child: FiltrePeriodeActivite(
        periode: state.periode,
        du: state.du,
        au: state.au,
        onPeriode: cubit.changerPeriode,
        onDates: cubit.changerDates,
      ),
    );
  }

  Widget _totaux(ChargesFixes d) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.85,
      children: [
        CarteTotalActivite(
          libelle: 'Total de la période',
          valeur: montantActivite(d.total),
          detail: '${d.nombre} ${pluriel(d.nombre, 'charge')}',
          icone: Icons.receipt_long_outlined,
          teinte: AppColors.primaryColor,
        ),
        CarteTotalActivite(
          libelle: 'Réglées',
          valeur: montantActivite(d.payees),
          icone: Icons.check_circle_outline,
          teinte: couleurVertActivite,
        ),
        CarteTotalActivite(
          libelle: 'En attente de règlement',
          valeur: montantActivite(d.attente),
          icone: Icons.schedule,
          teinte: couleurOrangeActivite,
        ),
        CarteTotalActivite(
          libelle: 'Prévu chaque mois',
          valeur: montantActivite(d.totalRecurrent),
          detail:
              '${d.recurrences.length} ${pluriel(d.recurrences.length, 'échéance')}',
          icone: Icons.event_repeat_outlined,
          teinte: const Color(0xFF7B4FD6),
        ),
      ],
    );
  }

  /// Les familles présentes, en puces : de quoi n'en regarder qu'une.
  Widget _puceFamilles(
      BuildContext context, ChargesFixesState state, ChargesFixes d) {
    final cubit = context.read<ChargesFixesCubit>();
    final presentes = <String>{
      ...d.familles.map((f) => f.code),
      ...d.recurrences.map((r) => r.categorie),
      if (state.famille != null) state.famille!,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PuceActivite(
            libelle: 'Toutes',
            choisie: state.famille == null,
            onTap: () {
              if (state.famille != null) cubit.filtrerFamille(state.famille);
            },
          ),
          for (final famille in d.catalogue.where((c) => presentes.contains(c.code)))
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: PuceActivite(
                libelle: famille.libelle,
                icone: iconeServeur(famille.icone),
                choisie: state.famille == famille.code,
                onTap: () => cubit.filtrerFamille(famille.code),
              ),
            ),
        ],
      ),
    );
  }

  // ── Une famille et ses charges ────────────────────────────────────

  Widget _famille(BuildContext context, ChargesFixesState state,
      ChargesFixes d, FamilleCharges famille) {
    final teinte = couleurServeur(famille.couleur, defaut: AppColors.primaryColor);
    final attente = famille.attente > 0
        ? ' · ${montantActivite(famille.attente)} en attente'
        : '';

    return SectionRepliableActivite(
      titre: famille.libelle,
      sousTitre:
          '${famille.nombre} ${pluriel(famille.nombre, 'charge')} · ${montantActivite(famille.total)}$attente',
      icone: iconeServeur(famille.icone),
      ouverteAuDepart: d.familles.length == 1,
      enfants: [
        for (final charge in famille.charges)
          _ligneCharge(context, state, d, charge, teinte),
        if (_manager.can(AppPermission.createFixedCharge))
          Builder(
            builder: (ctx) => InkWell(
              onTap: () => _ajouter(ctx, famille: famille.code),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: couleurBordureActivite)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: teinte),
                    const SizedBox(width: 6),
                    Text(
                      'Ajouter dans « ${famille.libelle} »',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: teinte),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _ligneCharge(BuildContext context, ChargesFixesState state,
      ChargesFixes d, Charge charge, Color teinte) {
    final enAttente = charge.status == 'pending';
    final bien = charge.realEstate?.title;
    final detail = [
      if ((bien ?? '').isNotEmpty) bien! else 'Agence',
      if (charge.createdAt != null) dateCourteActivite(charge.createdAt),
      if ((charge.creePar ?? '').isNotEmpty) charge.creePar!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: couleurBordureActivite)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 38,
            decoration: BoxDecoration(
              color: teinte.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge.nom ?? 'Charge',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: couleurTexteActivite),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: couleurGrisActivite,
                      fontFeatures: chiffresActivite),
                ),
                if ((charge.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    charge.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF8A969D)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                montantActivite(charge.amount),
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: couleurTexteActivite,
                    fontFeatures: chiffresActivite),
              ),
              const SizedBox(height: 3),
              PastilleActivite(
                texte: enAttente ? 'En attente' : 'Réglée',
                teinte: enAttente ? couleurOrangeActivite : couleurVertActivite,
                icone: enAttente ? Icons.schedule : Icons.check,
              ),
            ],
          ),
          _menuCharge(context, state, d, charge, enAttente),
        ],
      ),
    );
  }

  Widget _menuCharge(BuildContext context, ChargesFixesState state,
      ChargesFixes d, Charge charge, bool enAttente) {
    final peutModifier = _manager.can(AppPermission.updateFixedCharge);
    final peutValider =
        enAttente && _manager.can(AppPermission.validateCharge);
    final peutAnnuler =
        !charge.estAnnulee && _manager.can(AppPermission.cancelCharge);

    if (!peutModifier && !peutValider && !peutAnnuler) {
      return const SizedBox(width: 8);
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 19, color: couleurGrisActivite),
      padding: EdgeInsets.zero,
      onSelected: (choix) async {
        final cubit = context.read<ChargesFixesCubit>();
        switch (choix) {
          case 'modifier':
            final resultat = await FeuilleChargeFixe.ouvrir(
              context,
              catalogue: d.catalogue,
              biens: state.biens ?? const [],
              charge: charge,
            );
            if (resultat == null || charge.id == null) return;
            final ok = await cubit.modifier(charge.id!, resultat.saisie);
            if (ok && context.mounted) {
              showToast('Charge modifiée', context, second: 2);
            }
            break;
          case 'valider':
            final confirme = await _confirmer(
              context,
              titre: 'Régler cette charge ?',
              texte:
                  '${montantActivite(charge.amount)} sortiront de votre caisse.',
              action: 'Régler',
            );
            if (confirme != true) return;
            final ok = await cubit.valider(charge);
            if (ok && context.mounted) {
              showToast('Charge réglée', context, second: 2);
            }
            break;
          case 'annuler':
            final motif = await _demanderMotif(context, charge);
            if (motif == null || charge.id == null) return;
            final ok = await cubit.annuler(charge.id!,
                montant: motif['montant'] as double?,
                motif: motif['motif'] as String?);
            if (ok && context.mounted) {
              showToast('Charge annulée', context, second: 2);
            }
            break;
        }
      },
      itemBuilder: (_) => [
        if (peutModifier)
          const PopupMenuItem(
            value: 'modifier',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Modifier'),
            ]),
          ),
        if (peutValider)
          const PopupMenuItem(
            value: 'valider',
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 18, color: couleurVertActivite),
              SizedBox(width: 10),
              Text('Marquer réglée'),
            ]),
          ),
        if (peutAnnuler)
          const PopupMenuItem(
            value: 'annuler',
            child: Row(children: [
              Icon(Icons.block_outlined, size: 18, color: couleurRougeActivite),
              SizedBox(width: 10),
              Text('Annuler la charge'),
            ]),
          ),
      ],
    );
  }

  // ── Les échéances mensuelles ──────────────────────────────────────

  Widget _echeances(BuildContext context, ChargesFixes d) {
    final peutGerer =
        _manager.can(AppPermission.manageFixedChargeRecurrence);

    return SectionRepliableActivite(
      titre: 'Chaque mois',
      sousTitre:
          '${d.recurrences.length} ${pluriel(d.recurrences.length, 'échéance')} · ${montantActivite(d.totalRecurrent)} par mois',
      icone: Icons.event_repeat_outlined,
      enfants: [
        for (final echeance in d.recurrences)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: couleurBordureActivite)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B4FD6).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${echeance.jour}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B4FD6),
                        fontFeatures: chiffresActivite),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        echeance.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: couleurTexteActivite),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          echeance.categorieLibelle,
                          echeance.bien ?? 'Agence',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: couleurGrisActivite),
                      ),
                    ],
                  ),
                ),
                Text(
                  montantActivite(echeance.montant),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: couleurTexteActivite,
                      fontFeatures: chiffresActivite),
                ),
                if (peutGerer)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 19, color: couleurGrisActivite),
                    padding: EdgeInsets.zero,
                    onSelected: (choix) async {
                      final cubit = context.read<ChargesFixesCubit>();
                      if (choix == 'modifier') {
                        final valeurs =
                            await FeuilleEcheance.ouvrir(context, echeance);
                        if (valeurs == null) return;
                        final ok = await cubit.modifierEcheance(
                          echeance.id,
                          montant: valeurs['montant'] as double?,
                          jour: valeurs['jour'] as int?,
                        );
                        if (ok && context.mounted) {
                          showToast('Échéance modifiée', context, second: 2);
                        }
                      } else if (choix == 'arreter') {
                        final confirme = await _confirmer(
                          context,
                          titre: 'Arrêter la répétition ?',
                          texte:
                              '« ${echeance.nom} » ne sera plus recréée chaque mois. Les charges déjà enregistrées restent.',
                          action: 'Arrêter',
                          danger: true,
                        );
                        if (confirme != true) return;
                        final ok = await cubit.arreterEcheance(echeance.id);
                        if (ok && context.mounted) {
                          showToast('Répétition arrêtée', context, second: 2);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'modifier',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Modifier l’échéance'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'arreter',
                        child: Row(children: [
                          Icon(Icons.event_busy_outlined,
                              size: 18, color: couleurRougeActivite),
                          SizedBox(width: 10),
                          Text('Arrêter la répétition'),
                        ]),
                      ),
                    ],
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
      ],
    );
  }

  // ── Les actions ───────────────────────────────────────────────────

  Future<void> _ajouter(BuildContext context, {String? famille}) async {
    final cubit = context.read<ChargesFixesCubit>();
    final state = cubit.state;
    final catalogue = state.donnees?.catalogue ?? const <CategorieCharge>[];
    if (catalogue.isEmpty) return;

    final resultat = await FeuilleChargeFixe.ouvrir(
      context,
      catalogue: catalogue,
      biens: state.biens ?? const [],
      famillePreChoisie: famille,
    );
    if (resultat == null) return;

    final ok = await cubit.ajouter(resultat.saisie, document: resultat.document);
    if (ok && context.mounted) {
      showToast(
        resultat.saisie.mensuelle
            ? 'Charge fixe ajoutée, et répétée chaque mois'
            : 'Charge fixe ajoutée',
        context,
        second: 3,
      );
    }
  }

  Future<bool?> _confirmer(
    BuildContext context, {
    required String titre,
    required String texte,
    required String action,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titre,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: couleurTexteActivite)),
        content: Text(texte,
            style: const TextStyle(fontSize: 13.5, color: couleurGrisActivite)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non', style: TextStyle(color: couleurGrisActivite)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? couleurRougeActivite : AppColors.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  /// L'annulation demande ce que l'on récupère et pourquoi : sans cela,
  /// la caisse ne saurait pas quoi reprendre.
  Future<Map<String, dynamic>?> _demanderMotif(
      BuildContext context, Charge charge) {
    final montant = TextEditingController(
        text: (charge.status == 'payed' ? charge.amount ?? 0 : 0)
            .toStringAsFixed(0));
    final motif = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler cette charge',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: couleurTexteActivite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montant,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant rendu (MAD)',
                helperText: 'Ce qui revient dans votre caisse',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: motif,
              decoration: const InputDecoration(labelText: 'Motif (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Retour',
                style: TextStyle(color: couleurGrisActivite)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop({
              'montant': double.tryParse(montant.text.replaceAll(',', '.')),
              'motif': motif.text.trim().isEmpty ? null : motif.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: couleurRougeActivite,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Annuler la charge'),
          ),
        ],
      ),
    );
  }
}
