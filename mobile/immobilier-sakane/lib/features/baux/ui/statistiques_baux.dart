import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/features/baux/cubit/statistiques_baux_cubit.dart';
import 'package:immobilier/features/baux/ui/components/baux_commun.dart';
import 'package:immobilier/features/caisses/ui/garantir_caisse.dart';
import 'package:immobilier/models/statistiques_baux.dart';

/// Les chiffres de la location longue duree : ce qui a ete appele, ce qui est
/// rentre, ce qui manque, et depuis quand.
class StatistiquesBauxPage extends StatelessWidget {
  const StatistiquesBauxPage({super.key});

  static Widget page() => BlocProvider(
        create: (_) => StatistiquesBauxCubit()..charger(),
        child: const StatistiquesBauxPage(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursBail.fond,
      appBar: AppBar(
        title: const Text('Statistiques des baux',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
      ),
      body: BlocBuilder<StatistiquesBauxCubit, StatistiquesBauxState>(
        builder: (context, state) {
          final cubit = context.read<StatistiquesBauxCubit>();
          if (state.chiffres == null && state.statut == AppStatus.loading) {
            return Center(child: MyLoadingIndicator());
          }
          if (state.chiffres == null) {
            return Center(
              child: MyErrorWidget(
                error: state.erreur ?? 'Les statistiques sont indisponibles.',
                action: AppStrings.tryAgain,
                actionCLick: cubit.charger,
              ),
            );
          }
          final c = state.chiffres!;
          return RefreshIndicator(
            color: CouleursBail.teinte,
            onRefresh: cubit.charger,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              children: [
                _Periode(state: state),
                if (state.statut == AppStatus.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(
                        minHeight: 3, color: CouleursBail.teinte, backgroundColor: Colors.transparent),
                  ),
                if (state.erreur != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(state.erreur!,
                        style: const TextStyle(color: CouleursBail.retard, fontSize: 12.5)),
                  ),
                const SizedBox(height: 14),
                if (c.vide)
                  const _Vide()
                else ...[
                  _Loyers(loyers: c.loyers, retard: c.retard),
                  const SizedBox(height: 16),
                  _Occupation(occupation: c.occupation, baux: c.baux, depots: c.depotsDetenus),
                  if (c.parMois.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ParMois(mois: c.parMois),
                  ],
                  if (c.retards.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Retards(retards: c.retards),
                  ],
                  if (c.prochainesEcheances.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Prochaines(echeances: c.prochainesEcheances),
                  ],
                  if (c.finsProches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _Fins(fins: c.finsProches),
                  ],
                  if (c.parBien.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ParBien(biens: c.parBien),
                  ],
                  if (c.parMode.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _ParMode(modes: c.parMode),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// La periode : l'annee, les douze derniers mois, le mois, ou au choix.
class _Periode extends StatelessWidget {
  final StatistiquesBauxState state;

  const _Periode({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StatistiquesBauxCubit>();
    final maintenant = DateTime.now();
    final choix = <String, List<DateTime>>{
      'Cette année': [DateTime(maintenant.year, 1, 1), DateTime(maintenant.year, 12, 31)],
      'Ce mois': [
        DateTime(maintenant.year, maintenant.month, 1),
        DateTime(maintenant.year, maintenant.month + 1, 0),
      ],
      '12 derniers mois': [
        DateTime(maintenant.year, maintenant.month - 11, 1),
        DateTime(maintenant.year, maintenant.month + 1, 0),
      ],
      'Année dernière': [DateTime(maintenant.year - 1, 1, 1), DateTime(maintenant.year - 1, 12, 31)],
    };
    return CarteBail(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range_outlined, size: 17, color: CouleursBail.teinte),
              const SizedBox(width: 6),
              Expanded(
                child: Text(periodeBail(state.du, state.au),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
              ),
              TextButton(
                onPressed: () => _choisir(context, cubit),
                child: const Text('Modifier'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in choix.entries)
                _puce(
                  e.key,
                  actif: _memeJour(state.du, e.value[0]) && _memeJour(state.au, e.value[1]),
                  onTap: () => cubit.periode(e.value[0], e.value[1]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _puce(String texte, {required bool actif, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: actif ? CouleursBail.teinte : CouleursBail.fondTeinte,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(texte,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: actif ? Colors.white : CouleursBail.teinte,
            )),
      ),
    );
  }

  Future<void> _choisir(BuildContext context, StatistiquesBauxCubit cubit) async {
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 6),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: state.du, end: state.au),
      helpText: 'Période des statistiques',
    );
    if (plage != null) await cubit.periode(plage.start, plage.end);
  }
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return CarteBail(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      child: Column(
        children: const [
          Icon(Icons.insights_outlined, size: 44, color: CouleursBail.aVenir),
          SizedBox(height: 12),
          Text('Aucun bail sur cette période',
              style: TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
          SizedBox(height: 4),
          Text('Changez la période, ou créez un premier contrat de location.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux)),
        ],
      ),
    );
  }
}

/// Les loyers : appeles, encaisses, ce qui manque, et le retard.
class _Loyers extends StatelessWidget {
  final LoyersBaux loyers;
  final RetardBaux retard;

  const _Loyers({required this.loyers, required this.retard});

  @override
  Widget build(BuildContext context) {
    final part = loyers.appele <= 0 ? 0.0 : (loyers.encaisse / loyers.appele).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreSection(texte: 'Loyers', icone: Icons.payments_outlined),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Encaissé',
                            style: TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                        Text(montantLisible(loyers.encaisse),
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: CouleursBail.paye)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('sur ${montantLisible(loyers.appele)} appelés',
                          style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                      Text('${loyers.recouvrement.toStringAsFixed(1)} % recouvrés',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: CouleursBail.texte)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: part.toDouble(),
                  minHeight: 9,
                  backgroundColor: CouleursBail.bordure,
                  color: CouleursBail.paye,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _CarteChiffre(
                    titre: 'Impayé',
                    valeur: montantLisible(loyers.impaye),
                    couleur: loyers.impaye > 0.004 ? CouleursBail.partiel : CouleursBail.paye,
                    detail: '${loyers.echeances} ${pluralEcheances(loyers.echeances)}',
                  ),
                  const SizedBox(width: 10),
                  _CarteChiffre(
                    titre: 'En retard',
                    valeur: montantLisible(retard.montant),
                    couleur: retard.montant > 0.004 ? CouleursBail.retard : CouleursBail.paye,
                    detail: retard.echeances == 0
                        ? 'Rien d\'échu impayé'
                        : '${retard.echeances} ${pluralEcheances(retard.echeances)} échues',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.event_repeat_outlined, size: 16, color: CouleursBail.texteDoux),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Loyer mensuel attendu des baux actifs : '
                      '${montantLisible(loyers.mensuelAttendu)}',
                      style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// L'occupation du parc et le compte des baux.
class _Occupation extends StatelessWidget {
  final OccupationBaux occupation;
  final CompteBaux baux;
  final double depots;

  const _Occupation({required this.occupation, required this.baux, required this.depots});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreSection(texte: 'Parc et contrats', icone: Icons.home_work_outlined),
        const SizedBox(height: 8),
        Row(
          children: [
            _CarteChiffre(
              titre: 'Occupation',
              valeur: '${occupation.taux.toStringAsFixed(1)} %',
              couleur: CouleursBail.teinte,
              detail: '${occupation.loues} loués sur ${occupation.biens}',
            ),
            const SizedBox(width: 10),
            _CarteChiffre(
              titre: 'Logements libres',
              valeur: '${occupation.libres}',
              couleur: occupation.libres > 0 ? CouleursBail.aPayer : CouleursBail.paye,
              detail: occupation.libres == 0 ? 'Tout est loué' : 'à louer',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _CarteChiffre(
              titre: 'Baux actifs',
              valeur: '${baux.actifs}',
              couleur: CouleursBail.paye,
              detail: '${baux.nouveaux} ${baux.nouveaux == 1 ? 'nouveau' : 'nouveaux'} '
                  'sur la période',
            ),
            const SizedBox(width: 10),
            _CarteChiffre(
              titre: 'Dépôts détenus',
              valeur: montantLisible(depots),
              couleur: CouleursBail.texte,
              detail: baux.finis == 0
                  ? '${baux.termines} terminés en tout'
                  : '${baux.finis} terminés sur la période',
            ),
          ],
        ),
      ],
    );
  }
}

/// Mois par mois : ce qui a ete appele, et la part rentree.
class _ParMois extends StatelessWidget {
  final List<MoisBaux> mois;

  const _ParMois({required this.mois});

  @override
  Widget build(BuildContext context) {
    final sommet = mois.fold<double>(0, (m, e) => e.appele > m ? e.appele : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreSection(texte: 'Mois par mois', icone: Icons.bar_chart_outlined),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            children: [
              for (final m in mois) ...[
                _ligne(m, sommet),
                if (m != mois.last) const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legende(CouleursBail.paye, 'Encaissé'),
                  const SizedBox(width: 14),
                  _legende(CouleursBail.bordure, 'Appelé'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligne(MoisBaux m, double sommet) {
    final largeurAppele = sommet <= 0 ? 0.0 : (m.appele / sommet).clamp(0.0, 1.0);
    final part = m.appele <= 0 ? 0.0 : (m.encaisse / m.appele).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(m.libelle,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: CouleursBail.texte)),
            ),
            Text(montantLisible(m.encaisse),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: CouleursBail.paye,
                    fontFeatures: [FontFeature.tabularFigures()])),
            Text(' / ${montantLisible(m.appele)}',
                style: const TextStyle(
                    fontSize: 12,
                    color: CouleursBail.texteDoux,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, bornes) => Stack(
            children: [
              Container(
                width: bornes.maxWidth * largeurAppele,
                height: 8,
                decoration: BoxDecoration(
                    color: CouleursBail.bordure, borderRadius: BorderRadius.circular(4)),
              ),
              Container(
                width: bornes.maxWidth * largeurAppele * part,
                height: 8,
                decoration: BoxDecoration(
                    color: CouleursBail.paye, borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legende(Color couleur, String texte) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(texte, style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
      ],
    );
  }
}

/// Qui doit de l'argent, combien, et depuis combien de temps.
class _Retards extends StatelessWidget {
  final List<RetardLocataire> retards;

  const _Retards({required this.retards});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitreSection(texte: 'Retards (${retards.length})', icone: Icons.warning_amber_outlined),
        const SizedBox(height: 8),
        CarteBail(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final r in retards)
                ListTile(
                  onTap: () => GoRouter.of(context).push(cheminBail(r.bailId)),
                  leading: CircleAvatar(
                    backgroundColor: CouleursBail.retard.withValues(alpha: .12),
                    child: Text('${r.echeances}',
                        style: const TextStyle(
                            color: CouleursBail.retard, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(r.locataire ?? 'Locataire',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: CouleursBail.texte)),
                  subtitle: Text(
                    [
                      if ((r.bien ?? '').isNotEmpty) r.bien!,
                      if (r.jours != null) 'depuis ${r.jours} j',
                    ].join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: CouleursBail.texteDoux),
                  ),
                  trailing: Text(montantLisible(r.montant),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: CouleursBail.retard)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ce qui tombe dans les trente jours.
class _Prochaines extends StatelessWidget {
  final List<EcheanceProche> echeances;

  const _Prochaines({required this.echeances});

  @override
  Widget build(BuildContext context) {
    final total = echeances.fold<double>(0, (s, e) => s + e.reste);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreSection(texte: 'À encaisser sous 30 jours', icone: Icons.event_available_outlined),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${echeances.length} ${pluralEcheances(echeances.length)} • '
                  '${montantLisible(total)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursBail.texte)),
              const SizedBox(height: 8),
              for (final e in echeances.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () => GoRouter.of(context).push(cheminBail(e.bailId)),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 7, color: CouleursBail.aPayer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.bien ?? 'Bien',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte)),
                        ),
                        Text(dateBail(DateTime.tryParse(e.echeance ?? '')),
                            style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
                        const SizedBox(width: 10),
                        Text(montantLisible(e.reste),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: CouleursBail.aPayer)),
                      ],
                    ),
                  ),
                ),
              if (echeances.length > 10)
                Text('et ${echeances.length - 10} autres',
                    style: const TextStyle(fontSize: 12, color: CouleursBail.texteDoux)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Les baux qui arrivent a terme : de quoi relancer avant le depart.
class _Fins extends StatelessWidget {
  final List<FinProche> fins;

  const _Fins({required this.fins});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TitreSection(texte: 'Baux finissant bientôt (${fins.length})', icone: Icons.timelapse_outlined),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            children: [
              for (final f in fins)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => GoRouter.of(context).push(cheminBail(f.bailId)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(f.bien ?? 'Bien',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte)),
                        ),
                        PastilleBail(
                          texte: libelleJoursRestants(f.jours),
                          couleur: f.jours <= 15 ? CouleursBail.retard : CouleursBail.partiel,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bien par bien : qui rapporte, qui traine.
class _ParBien extends StatelessWidget {
  final List<BienBaux> biens;

  const _ParBien({required this.biens});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreSection(texte: 'Par logement', icone: Icons.apartment_outlined),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            children: [
              for (final b in biens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(b.bien,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: CouleursBail.texte)),
                          ),
                          Text(montantLisible(b.encaisse),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: CouleursBail.paye)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${b.echeances} ${pluralEcheances(b.echeances)}',
                          'appelés ${montantLisible(b.appele)}',
                          if (b.retard > 0.004) 'en retard ${montantLisible(b.retard)}',
                        ].join(' • '),
                        style: TextStyle(
                            fontSize: 11.5,
                            color: b.retard > 0.004 ? CouleursBail.retard : CouleursBail.texteDoux),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Comment les loyers rentrent : especes, virement, cheque.
class _ParMode extends StatelessWidget {
  final List<ModeBaux> modes;

  const _ParMode({required this.modes});

  @override
  Widget build(BuildContext context) {
    final total = modes.fold<double>(0, (s, m) => s + m.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreSection(texte: 'Moyens de paiement', icone: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 8),
        CarteBail(
          child: Column(
            children: [
              for (final m in modes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${m.libelle} (${m.nombre})',
                            style: const TextStyle(fontSize: 12.5, color: CouleursBail.texte)),
                      ),
                      Text(montantLisible(m.total),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: CouleursBail.texte)),
                      const SizedBox(width: 8),
                      Text(total <= 0 ? '' : '${(100 * m.total / total).round()} %',
                          style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une carte chiffree, comme celles de la fiche d'un bail.
class _CarteChiffre extends StatelessWidget {
  final String titre;
  final String valeur;
  final Color couleur;
  final String detail;

  const _CarteChiffre({
    required this.titre,
    required this.valeur,
    required this.couleur,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CouleursBail.bordure),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valeur,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: couleur)),
            ),
            const SizedBox(height: 2),
            Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: CouleursBail.texteDoux)),
          ],
        ),
      ),
    );
  }
}

/// « 1 échéance », « 4 échéances ».
String pluralEcheances(int n) => n == 1 ? 'échéance' : 'échéances';
