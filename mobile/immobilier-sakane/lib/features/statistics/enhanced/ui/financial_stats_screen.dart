import 'package:flutter/services.dart';
import 'package:immobilier/components/bouton_export.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/droits.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/statistics/enhanced/cubit/financial_stats_cubit.dart';
import 'package:immobilier/features/statistics/enhanced/ui/feuille_rapport.dart';
import 'package:immobilier/models/financial_stats.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:immobilier/components/tableau_fige.dart';
import 'package:immobilier/components/ligne_commentaire.dart';
import 'package:intl/intl.dart' show DateFormat;

class FinancialStatsScreen extends StatefulWidget {
  const FinancialStatsScreen({Key? key}) : super(key: key);

  static Widget page({int? realestateId}) {
    return BlocProvider(
      create: (_) => FinancialStatsCubit(realestateId: realestateId)
        ..fetchStats(),
      child: const FinancialStatsScreen(),
    );
  }

  @override
  State<FinancialStatsScreen> createState() => _FinancialStatsScreenState();
}

class _FinancialStatsScreenState extends State<FinancialStatsScreen>
    with SingleTickerProviderStateMixin {

  /// L'onglet affiché, avec le détail de chaque ligne.
  TableauExportable? _tableauExport(FinancialStatsState state) {
    final s = state.stats;
    if (s == null) return null;
    final periode = 'Du ${dateExport(state.from)} au ${dateExport(state.to)}'
        '${state.repartition == 'nuit' ? ' — argent réparti par nuit' : ' — argent à l\'encaissement'}';
    const types = {
      'income': 'Revenu',
      'expense': 'Dépense',
      'refund': 'Remboursement',
      'cancellation': 'Annulation',
      'expense_reversal': 'Dépense annulée',
    };
    double signe(FinancialTransactionItem t) =>
        t.type == 'income' || t.type == 'expense_reversal' ? t.amount : -t.amount;

    switch (_tabController.index) {
      case 1:
        double net = 0;
        final choisies = s.transactions
            .where((t) => _correspond(t.type, _filtreType))
            .toList();
        final lignes = choisies.map((t) {
          net += signe(t);
          return [t.date, types[t.type] ?? t.type, t.description, _auteur(t) ?? '', montantExport(signe(t))];
        }).toList();
        return TableauExportable(
          titre: _filtreType == null
              ? 'Transactions'
              : 'Transactions - ${_libellesTypes[_filtreType] ?? _filtreType}',
          sousTitre: periode,
          colonnes: const ['Date', 'Type', 'Description', 'Par', 'Montant'],
          lignes: lignes,
          totaux: ['TOTAL', '', '', '', montantExport(net)],
        );
      case 2:
        double ca = 0, dep = 0, remb = 0, ann = 0, ben = 0;
        int jr = 0, jl = 0;
        final lignes = _compares(s.comparative).map((p) {
          ca += p.revenue;
          dep += p.expenses;
          remb += p.refunds;
          ann += p.cancellations;
          ben += p.profit;
          jr += p.reservedDays;
          jl += p.nonReservedDays;
          return [p.title, '${p.reservedDays}', '${p.nonReservedDays}',
            '${_taux(p.reservedDays, p.nonReservedDays)} %', montantExport(p.revenue),
            montantExport(p.expenses), montantExport(p.refunds), montantExport(p.cancellations),
            montantExport(p.profit)];
        }).toList();
        return TableauExportable(
          titre: 'Comparatif des biens',
          sousTitre: periode,
          colonnes: const ['Bien', 'Jours rés.', 'Jours lib.', 'Occupation', 'CA', 'Dépenses', 'Remb.', 'Annul.', 'Bénéfice'],
          lignes: lignes,
          totaux: ['TOTAL', '$jr', '$jl', '${_taux(jr, jl)} %', montantExport(ca), montantExport(dep),
            montantExport(remb), montantExport(ann), montantExport(ben)],
        );
      default:
        final r = s.summary;
        return TableauExportable(
          titre: "Vue d'ensemble",
          sousTitre: periode,
          colonnes: const ['Indicateur', 'Montant (MAD)'],
          lignes: [
            ['Revenus', montantExport(r.totalIncome)],
            if (r.totalTva > 0.004) ['dont TVA encaissée', montantExport(r.totalTva)],
            if (r.totalAirbnb > 0.004) ['dont Airbnb', montantExport(r.totalAirbnb)],
            ['Dépenses', montantExport(r.totalExpenses)],
            ['Dépenses annulées', montantExport(r.totalExpenseReversals)],
            ['Remboursements', montantExport(r.totalRefunds)],
            ['Annulations', montantExport(r.totalCancellations)],
            ['Bénéfice net', montantExport(r.netProfit)],
            ...s.transactions.map((t) => [
                  '${t.date} - ${types[t.type] ?? t.type} - ${t.description}'
                      '${_auteur(t) == null ? '' : ' - ${_auteur(t)}'}',
                  montantExport(signe(t)),
                ]),
            if (s.caisse != null) ...[
              ['Caisse — entrées', montantExport(s.caisse!.entrees)],
              ['Caisse — sorties', montantExport(s.caisse!.sorties)],
              ['Caisse — net', montantExport(s.caisse!.net)],
              ...s.caisse!.mouvements.map((m) => [
                    '${dateHeureExport(m.date)} - ${m.caisse} - ${m.libelle}'
                        '${m.par == null ? '' : ' - ${m.par}'}'
                        '${m.commentaire == null ? '' : ' - ${m.commentaire}'}',
                    montantExport(m.estEntree ? m.montant : -m.montant),
                  ]),
            ],
          ],
        );
    }
  }

  /// Qui est à l'origine de l'écriture : pour une annulation, celui qui a
  /// supprimé la réservation ; sinon, celui qui l'a créée.
  static String? _auteur(FinancialTransactionItem t) {
    if ((t.par ?? '').isEmpty) return null;
    return t.type == 'cancellation' ? 'Supprimée par ${t.par}' : 'Créé par ${t.par}';
  }

  late TabController _tabController;

  /// Le type d'écriture retenu dans l'onglet Transactions. Nul : tous.
  String? _filtreType;

  /// Les biens retenus dans le comparatif ; nul : tous.
  Set<int>? _biensCompares;

  List<PropertyComparative> _compares(List<PropertyComparative> tous) => _biensCompares == null
      ? tous
      : tous.where((p) => _biensCompares!.contains(p.id)).toList();

  /// Une carte de la vue d'ensemble ouvre ses lignes, sur la période
  /// déjà choisie.
  void _filtrerTransactions(String? type) {
    setState(() => _filtreType = type);
    _tabController.animateTo(1);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinancialStatsCubit, FinancialStatsState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              state.singlePropertyMode
                  ? 'Statistiques du Bien'
                  : 'Statistiques Financières',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            actions: [
              if (peut(AppPermission.downloadStatsReport))
              IconButton(
                tooltip: 'Télécharger le rapport',
                icon: const Icon(Icons.summarize_outlined, color: Colors.white),
                onPressed: () => ouvrirFeuilleRapport(context, state),
              ),
              BoutonExport(tableau: () => _tableauExport(state)),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'Vue d\'ensemble'),
                Tab(text: 'Transactions'),
                /*Tab(text: 'Clients'),*/
                Tab(text: 'Comparatif'),
              ],
            ),
          ),
          // La barre de période défile avec le contenu : elle libère
          // l'écran quand on descend, et revient dès qu'on remonte.
          body: NestedScrollView(
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: _FilterBar(
                  state: state,
                  onRapport: () => ouvrirFeuilleRapport(context, state),
                ),
              ),
            ],
            body: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, FinancialStatsState state) {
    if (state.fetchStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    }
    if (state.fetchStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? 'Erreur',
        action: AppStrings.tryAgain,
        actionCLick: () =>
            context.read<FinancialStatsCubit>().fetchStats(),
      );
    }
    if (state.stats == null) {
      return const SizedBox.shrink();
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _OverviewTab(stats: state.stats!, onFiltrer: _filtrerTransactions),
        _TransactionsTab(
          transactions: state.stats!.transactions,
          filtre: _filtreType,
          onFiltre: (type) => setState(() => _filtreType = type),
        ),
        //_ClientsTab(clients: state.stats!.clients),
        _ComparativeTab(
          comparative: state.stats!.comparative,
          tableau: () => _tableauExport(state),
          selection: _biensCompares,
          onSelection: (choix) => setState(() => _biensCompares = choix),
        ),
      ],
    );
  }
}

// ─── Filter Bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatefulWidget {
  final FinancialStatsState state;
  final VoidCallback onRapport;
  const _FilterBar({required this.state, required this.onRapport});

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

/// Le choix de la période : un jour, un mois, une année ou un intervalle
/// libre. Choisir une date lance la recherche.
class _FilterBarState extends State<_FilterBar> {
  static const _moisNoms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet',
    'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  static const _moisCourts = [
    'Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin',
    'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.',
  ];

  late DateTime _from;
  late DateTime _to;

  /// 'jour' | 'mois' | 'annee' | 'periode'
  late String _mode;

  @override
  void initState() {
    super.initState();
    _from = widget.state.from!;
    _to = widget.state.to!;
    _mode = _deviner();
  }

  @override
  void didUpdateWidget(_FilterBar old) {
    super.didUpdateWidget(old);
    if (widget.state.from != old.state.from || widget.state.to != old.state.to) {
      _from = widget.state.from!;
      _to = widget.state.to!;
      if (widget.state.quickPeriod != 'custom') _mode = _deviner();
    }
  }

  static DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _limite => DateTime(DateTime.now().year + 1, 12, 31);

  DateTime _borne(DateTime d) {
    if (d.isBefore(DateTime(2020))) return DateTime(2020);
    if (d.isAfter(_limite)) return _limite;
    return d;
  }

  String _deviner() {
    switch (widget.state.quickPeriod) {
      case 'today':
      case 'yesterday':
        return 'jour';
      case 'month':
        return 'mois';
      case 'year':
        return 'annee';
    }
    return _jour(_from) == _jour(_to) ? 'jour' : 'periode';
  }

  String get _libelle {
    switch (_mode) {
      case 'jour':
        return _from.formattedDateFr;
      case 'mois':
        return '${_moisNoms[_from.month - 1]} ${_from.year}';
      case 'annee':
        return 'Année ${_from.year}';
      default:
        return '${_from.formattedDateFr}  →  ${_to.formattedDateFr}';
    }
  }

  void _appliquer(DateTime from, DateTime to) {
    setState(() {
      _from = from;
      _to = to;
    });
    context.read<FinancialStatsCubit>().setDateRange(from, to);
  }

  Future<void> _changerMode(String mode) async {
    setState(() => _mode = mode);
    await _ouvrirSelecteur();
  }

  Future<void> _ouvrirSelecteur() async {
    switch (_mode) {
      case 'jour':
        final d = await _choisirJour();
        if (d != null) _appliquer(d, d);
        break;
      case 'mois':
        final m = await _choisirMois();
        if (m != null) {
          _appliquer(DateTime(m.year, m.month, 1), DateTime(m.year, m.month + 1, 0));
        }
        break;
      case 'annee':
        final a = await _choisirAnnee();
        if (a != null) _appliquer(DateTime(a, 1, 1), DateTime(a, 12, 31));
        break;
      default:
        final p = await _choisirPeriode();
        if (p != null) _appliquer(p.start, p.end);
    }
  }

  ThemeData _theme(BuildContext context) => Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: AppColors.primaryColor,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF17262E),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          headerBackgroundColor: AppColors.primaryColor,
          headerForegroundColor: Colors.white,
          todayBorder: BorderSide(color: AppColors.primaryColor),
          dayShape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          rangeSelectionBackgroundColor: AppColors.primaryColor.withValues(alpha: .12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );

  Future<T?> _feuille<T>({
    required String titre,
    required Widget Function(BuildContext, StateSetter) contenu,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Theme(
        data: _theme(ctx),
        child: StatefulBuilder(
          builder: (ctx, maj) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5DDE2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(titre,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                  const SizedBox(height: 10),
                  contenu(ctx, maj),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _choisirJour() => _feuille<DateTime>(
        titre: 'Choisir un jour',
        contenu: (ctx, _) => CalendarDatePicker(
          initialDate: _borne(_from),
          firstDate: DateTime(2020),
          lastDate: _limite,
          onDateChanged: (d) => Navigator.of(ctx).pop(d),
        ),
      );

  Future<DateTime?> _choisirMois() {
    var annee = _from.year;
    final maintenant = DateTime.now();
    return _feuille<DateTime>(
      titre: 'Choisir un mois',
      contenu: (ctx, maj) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: annee > 2020 ? () => maj(() => annee--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text('$annee',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
              ),
              IconButton(
                onPressed: annee < maintenant.year + 1 ? () => maj(() => annee++) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: List.generate(12, (i) {
              return _CasePeriode(
                libelle: _moisCourts[i],
                choisi: _mode == 'mois' && _from.year == annee && _from.month == i + 1,
                courant: maintenant.year == annee && maintenant.month == i + 1,
                onTap: () => Navigator.of(ctx).pop(DateTime(annee, i + 1)),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<int?> _choisirAnnee() {
    final maintenant = DateTime.now().year;
    final annees = [for (var a = maintenant + 1; a >= 2020; a--) a];
    return _feuille<int>(
      titre: 'Choisir une année',
      contenu: (ctx, _) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
        children: annees
            .map((a) => _CasePeriode(
                  libelle: '$a',
                  choisi: _mode == 'annee' && _from.year == a,
                  courant: a == maintenant,
                  onTap: () => Navigator.of(ctx).pop(a),
                ))
            .toList(),
      ),
    );
  }

  Future<DateTimeRange?> _choisirPeriode() {
    var debut = _borne(_from);
    var fin = _borne(_to);
    if (fin.isBefore(debut)) {
      final t = debut;
      debut = fin;
      fin = t;
    }
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _limite,
      initialDateRange: DateTimeRange(start: debut, end: fin),
      helpText: 'Choisir une période',
      builder: (ctx, child) => Theme(data: _theme(ctx), child: child!),
    );
  }

  /// Lit une date écrite jour/mois/année : 05/09/2026, 5/9/26, 05-09-2026.
  static DateTime? _lireDate(String texte) {
    final m = RegExp(r'^\s*(\d{1,2})[/.\- ](\d{1,2})[/.\- ](\d{2,4})\s*$').firstMatch(texte);
    if (m == null) return null;
    final jour = int.parse(m.group(1)!);
    final mois = int.parse(m.group(2)!);
    var annee = int.parse(m.group(3)!);
    if (annee < 100) annee += 2000;
    if (mois < 1 || mois > 12 || jour < 1 || jour > 31) return null;
    final d = DateTime(annee, mois, jour);
    // Refuse le 31/02 plutôt que de glisser au mois suivant.
    if (d.month != mois || d.day != jour) return null;
    return d;
  }

  Widget _champDate(
    TextEditingController controleur,
    String libelle, {
    bool autofocus = false,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controleur,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [_FormatDate()],
      style: const TextStyle(fontSize: 16, letterSpacing: 1, color: Color(0xFF17262E)),
      decoration: InputDecoration(
        labelText: libelle,
        hintText: 'jj/mm/aaaa',
        prefixIcon: const Icon(Icons.event_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    );
  }

  void _expliquerRepartition(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Comment l'argent est compté",
            style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
        content: const SingleChildScrollView(
          child: Text(
            "À l'encaissement : chaque montant compte en entier, à la date où il a été "
            "enregistré (saisie de la réservation, prolongation, remboursement, "
            "suppression, charge).\n\n"
            "Réparti par nuit : l'argent d'une réservation est divisé par son nombre de "
            "nuits, et chaque nuit compte dans la période où elle tombe. Les charges "
            "restent à leur date.\n\n"
            "Exemple : séjour du 27/08 au 04/09 (8 nuits), 2 400 MAD, saisi le 20/08.\n"
            "• À l'encaissement : 2 400 MAD en août, 0 en septembre.\n"
            "• Par nuit : 300 MAD par nuit, soit 1 500 MAD en août (5 nuits) "
            "et 900 MAD en septembre (3 nuits).\n\n"
            "Les nuits et le taux d'occupation se calculent toujours nuit par nuit.",
            style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF28414F)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Compris')),
        ],
      ),
    );
  }

  /// Saisie de la période au clavier, au format jour/mois/année.
  Future<void> _saisirPeriode() async {
    final du = TextEditingController(text: _from.formattedDateFr);
    final au = TextEditingController(
        text: _jour(_from) == _jour(_to) ? '' : _to.formattedDateFr);
    String? erreur;

    final resultat = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, maj) {
          void valider() {
            final debut = _lireDate(du.text);
            final fin = au.text.trim().isEmpty ? debut : _lireDate(au.text);
            if (debut == null) {
              maj(() => erreur = 'Date de début invalide : écrivez jj/mm/aaaa.');
              return;
            }
            if (fin == null) {
              maj(() => erreur = 'Date de fin invalide : écrivez jj/mm/aaaa.');
              return;
            }
            if (fin.isBefore(debut)) {
              maj(() => erreur = 'La date de fin est avant la date de début.');
              return;
            }
            Navigator.of(ctx).pop(DateTimeRange(start: debut, end: fin));
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Saisir la période',
                style: TextStyle(fontSize: 17, color: Color(0xFF17262E))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Format jour/mois/année. Laissez « Au » vide pour un seul jour.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7B84)),
                ),
                const SizedBox(height: 14),
                _champDate(du, 'Du', autofocus: true),
                const SizedBox(height: 12),
                _champDate(au, 'Au (facultatif)', onSubmitted: valider),
                if (erreur != null) ...[
                  const SizedBox(height: 10),
                  Text(erreur!, style: TextStyle(fontSize: 12.5, color: Colors.red.shade700)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: valider,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Rechercher'),
              ),
            ],
          );
        },
      ),
    );

    if (resultat == null || !mounted) return;
    setState(() =>
        _mode = _jour(resultat.start) == _jour(resultat.end) ? 'jour' : 'periode');
    _appliquer(resultat.start, resultat.end);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FinancialStatsCubit>();
    final primaire = AppColors.primaryColor;
    const modes = [('jour', 'Jour'), ('mois', 'Mois'), ('annee', 'Année'), ('periode', 'Période')];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 20, color: primaire),
              const SizedBox(width: 8),
              const Text(
                'Période',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Spacer(),
              // Écrire la période au clavier, plutôt que la chercher dans
              // un calendrier.
              TextButton.icon(
                onPressed: _saisirPeriode,
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Saisir'),
                style: TextButton.styleFrom(
                  foregroundColor: primaire,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final m in modes)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _changerMode(m.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _mode == m.$1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _mode == m.$1
                              ? const [
                                  BoxShadow(
                                      color: Color(0x1417262E), blurRadius: 6, offset: Offset(0, 1))
                                ]
                              : null,
                        ),
                        child: Text(
                          m.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _mode == m.$1 ? FontWeight.bold : FontWeight.w500,
                            color: _mode == m.$1 ? primaire : const Color(0xFF6B7B84),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: primaire.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _ouvrirSelecteur,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: primaire.withValues(alpha: .3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 19, color: primaire),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _libelle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF17262E)),
                            ),
                          ),
                          Icon(Icons.expand_more, color: primaire),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: primaire,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => cubit.setDateRange(_from, _to),
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.search, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PillChip(
                label: 'Hier',
                selected: widget.state.quickPeriod == 'yesterday',
                onTap: () => cubit.setQuickPeriod('yesterday'),
              ),
              _PillChip(
                label: "Aujourd'hui",
                selected: widget.state.quickPeriod == 'today',
                onTap: () => cubit.setQuickPeriod('today'),
              ),
              _PillChip(
                label: 'Semaine',
                selected: widget.state.quickPeriod == 'week',
                onTap: () => cubit.setQuickPeriod('week'),
              ),
              _PillChip(
                label: 'Ce mois',
                selected: widget.state.quickPeriod == 'month',
                onTap: () => cubit.setQuickPeriod('month'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Comment l'argent est compté dans la période choisie.
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 17, color: Color(0xFF4A5B64)),
              const SizedBox(width: 6),
              const Text('Argent',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _PillChip(
                      label: "À l'encaissement",
                      selected: widget.state.repartition != 'nuit',
                      onTap: () => cubit.setRepartition('encaissement'),
                    ),
                    _PillChip(
                      label: 'Réparti par nuit',
                      selected: widget.state.repartition == 'nuit',
                      onTap: () => cubit.setRepartition('nuit'),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Comment est-ce calculé ?',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.info_outline, size: 20, color: primaire),
                onPressed: () => _expliquerRepartition(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Le rapport complet de la période, en PDF ou Excel.
          if (peut(AppPermission.downloadStatsReport))
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onRapport,
              icon: const Icon(Icons.summarize_outlined, size: 19),
              label: const Text('Télécharger le rapport',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaire,
                side: BorderSide(color: primaire.withValues(alpha: .4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Écrit les barres de jj/mm/aaaa au fil de la frappe.
class _FormatDate extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue ancien, TextEditingValue nouveau) {
    final chiffres = nouveau.text.replaceAll(RegExp(r'[^0-9]'), '');
    final b = StringBuffer();
    for (var i = 0; i < chiffres.length && i < 8; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(chiffres[i]);
    }
    final texte = b.toString();
    return TextEditingValue(
      text: texte,
      selection: TextSelection.collapsed(offset: texte.length),
    );
  }
}

/// Une case de mois ou d'année dans le sélecteur.
class _CasePeriode extends StatelessWidget {
  final String libelle;
  final bool choisi;
  final bool courant;
  final VoidCallback onTap;

  const _CasePeriode({
    required this.libelle,
    required this.choisi,
    required this.courant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaire = AppColors.primaryColor;
    return Material(
      color: choisi ? primaire : const Color(0xFFF2F5F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: courant && !choisi ? primaire : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: choisi || courant ? FontWeight.bold : FontWeight.w500,
              color: choisi ? Colors.white : const Color(0xFF17262E),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: selected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyPickerSheet extends StatelessWidget {
  const _PropertyPickerSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinancialStatsCubit, FinancialStatsState>(
      builder: (context, state) {
        final cubit = context.read<FinancialStatsCubit>();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          builder: (_, scrollController) => Column(
            children: [
              // handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sélectionner les biens',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => cubit.clearRealestateFilter(),
                      child: Text(
                        'Tous',
                        style:
                            TextStyle(color: AppColors.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: state.allRealestates.length,
                  itemBuilder: (_, i) {
                    final prop = state.allRealestates[i];
                    final selected =
                        state.selectedRealestateIds.contains(prop.id);
                    return CheckboxListTile(
                      value: selected,
                      activeColor: AppColors.primaryColor,
                      title: Text(prop.title ?? '',
                          style: const TextStyle(fontSize: 14)),
                      onChanged: (_) =>
                          cubit.toggleRealestate(prop.id!),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Appliquer',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Alerts Banner ───────────────────────────────────────────────────────────

class _AlertsBanner extends StatelessWidget {
  final List<StatAlert> alerts;
  const _AlertsBanner({required this.alerts});

  Color _toColor(String c) {
    if (c == 'red') return Colors.red.shade600;
    if (c == 'orange') return Colors.orange.shade600;
    return Colors.yellow.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: Colors.red.shade50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = alerts[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _toColor(a.color).withOpacity(0.1),
              border: Border(
                  left: BorderSide(color: _toColor(a.color), width: 3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: _toColor(a.color), size: 16),
                const SizedBox(width: 6),
                Text(a.message,
                    style: TextStyle(
                        fontSize: 11, color: _toColor(a.color))),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Taux d'occupation en pourcentage, une décimale.
String _taux(int reservees, int libres) {
  final total = reservees + libres;
  return total == 0 ? '0.0' : (reservees / total * 100).toStringAsFixed(1);
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final FinancialStats stats;

  /// Ouvre l'onglet Transactions filtré sur le type de la carte.
  final ValueChanged<String?> onFiltrer;

  const _OverviewTab({required this.stats, required this.onFiltrer});

  @override
  Widget build(BuildContext context) {
    final s = stats.summary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiGrid(s),
          if (s.totalTva > 0.004) ...[
            const SizedBox(height: 12),
            _ligneTva(s.totalTva),
          ],
          if (s.totalAirbnb > 0.004) ...[
            SizedBox(height: s.totalTva > 0.004 ? 8 : 12),
            _ligneAirbnb(s.totalAirbnb),
          ],
          const SizedBox(height: 20),
          if (stats.revenueByPeriod.isNotEmpty) _chart(context, stats),
          // Toutes les opérations passées dans les caisses sur la période.
          // Un serveur plus ancien ne les renvoie pas : rien n'est affiché.
          if (stats.caisse != null) ...[
            const SizedBox(height: 20),
            _SectionCaisse(caisse: stats.caisse!),
          ],
        ],
      ),
    );
  }

  Widget _kpiGrid(StatsSummary s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _KpiCard(
            label: 'Revenus',
            value: s.totalIncome,
            color: Colors.green.shade600,
            icon: Icons.trending_up,
            onTap: () => onFiltrer('income')),
        _KpiCard(
            label: 'Dépenses',
            value: s.totalExpenses,
            color: Colors.red.shade600,
            icon: Icons.trending_down,
            onTap: () => onFiltrer('expense')),
        _KpiCard(
            label: 'Remboursements',
            value: s.totalRefunds,
            color: Colors.orange.shade600,
            icon: Icons.undo,
            onTap: () => onFiltrer('refund')),
        _KpiCard(
            label: 'Annulations',
            value: s.totalCancellations,
            color: Colors.red.shade300,
            icon: Icons.cancel_outlined,
            onTap: () => onFiltrer('cancellation')),
        _KpiCard(
            label: 'Charges annulées',
            value: s.totalExpenseReversals,
            color: Colors.teal.shade600,
            icon: Icons.undo_rounded,
            onTap: () => onFiltrer('expense_reversal')),
        _KpiCard(
            label: 'Bénéfice net',
            value: s.netProfit,
            color: s.netProfit >= 0
                ? Colors.blue.shade700
                : Colors.red.shade700,
            icon: Icons.account_balance_wallet,
            onTap: () => onFiltrer(null)),
      ],
    );
  }

  /// La TVA des factures appliquées, déjà comprise dans les revenus.
  Widget _ligneTva(double tva) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onFiltrer('income'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('dont TVA encaissée',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              ),
              Text(
                '${tva.toStringAsFixed(2)} MAD',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Les revenus des réservations Airbnb, déjà compris dans les revenus :
  /// ils sont entrés dans la caisse Airbnb.
  Widget _ligneAirbnb(double montant) {
    const rose = Color(0xFFFF5A5F);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onFiltrer('income'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.airbnb, color: rose, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('dont Airbnb',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              ),
              Text(
                '${montant.toStringAsFixed(2)} MAD',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: rose),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chart(BuildContext context, FinancialStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenus vs Dépenses',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              legend: Legend(isVisible: true),
              series: <CartesianSeries<PeriodRevenue, String>>[
                SplineSeries<PeriodRevenue, String>(
                  name: 'Revenus',
                  color: Colors.green,
                  dataSource: stats.revenueByPeriod,
                  xValueMapper: (d, _) => d.period,
                  yValueMapper: (d, _) => d.income,
                ),
                SplineSeries<PeriodRevenue, String>(
                  name: 'Dépenses',
                  color: Colors.red,
                  dataSource: stats.revenueByPeriod,
                  xValueMapper: (d, _) => d.period,
                  yValueMapper: (d, _) => d.expenses,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${value.toStringAsFixed(2)} MAD',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Voir le détail',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: .8))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Opérations de caisse ─────────────────────────────────────────────────────

String _montantCaisse(double v) => '${v.toStringAsFixed(2)} MAD';

/// Les entrées et sorties de toutes les caisses sur la période : les
/// totaux, la répartition par motif, puis chaque opération.
class _SectionCaisse extends StatefulWidget {
  final CaisseStats caisse;
  const _SectionCaisse({required this.caisse});

  @override
  State<_SectionCaisse> createState() => _SectionCaisseState();
}

class _SectionCaisseState extends State<_SectionCaisse> {
  static const _parPage = 20;
  int _affichees = _parPage;

  @override
  void didUpdateWidget(_SectionCaisse old) {
    super.didUpdateWidget(old);
    // Une nouvelle période : on repart des premières lignes.
    if (!identical(old.caisse, widget.caisse)) _affichees = _parPage;
  }

  static final _vert = Colors.green.shade700;
  static final _rouge = Colors.red.shade700;

  @override
  Widget build(BuildContext context) {
    final c = widget.caisse;
    final ops = c.mouvements;
    final visibles = ops.take(_affichees).toList();
    final reste = ops.length - visibles.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.point_of_sale_outlined,
                    size: 18, color: AppColors.primaryColor),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Opérations de caisse',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                if (ops.isNotEmpty)
                  Text('${ops.length} opération${ops.length > 1 ? 's' : ''}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _chiffre('Entrées', _montantCaisse(c.entrees), _vert,
                        Icons.south_west)),
                const SizedBox(width: 8),
                Expanded(
                    child: _chiffre('Sorties', _montantCaisse(c.sorties),
                        _rouge, Icons.north_east)),
                const SizedBox(width: 8),
                Expanded(
                    child: _chiffre(
                        'Net',
                        '${c.net >= 0 ? '+' : '−'}${_montantCaisse(c.net.abs())}',
                        c.net >= 0 ? Colors.blue.shade700 : _rouge,
                        Icons.account_balance_wallet_outlined)),
              ],
            ),
            if (c.parMotif.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sousTitre('Par motif'),
              const SizedBox(height: 6),
              for (final m in c.parMotif) _ligneMotif(m),
            ],
            const SizedBox(height: 16),
            _sousTitre('Détail des opérations'),
            const SizedBox(height: 4),
            if (ops.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text('Aucune opération de caisse sur cette période',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600)),
                ),
              )
            else
              for (int i = 0; i < visibles.length; i++) ...[
                _ligneOperation(visibles[i]),
                if (i < visibles.length - 1) const Divider(height: 1),
              ],
            if (reste > 0)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _affichees += _parPage),
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text(
                      'Voir plus ($reste restante${reste > 1 ? 's' : ''})'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sousTitre(String texte) => Text(texte,
      style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4A5B64)));

  Widget _chiffre(
      String libelle, String valeur, Color couleur, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 13, color: couleur),
              const SizedBox(width: 4),
              Flexible(
                child: Text(libelle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: couleur)),
          ),
        ],
      ),
    );
  }

  Widget _ligneMotif(CaisseMotifStat m) {
    final couleur = m.estEntree ? _vert : _rouge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(m.libelle,
                style:
                    const TextStyle(fontSize: 12.5, color: Color(0xFF17262E))),
          ),
          Text('${m.nombre}×',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          const SizedBox(width: 10),
          Text(
            '${m.estEntree ? '+' : '−'}${_montantCaisse(m.total)}',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.bold, color: couleur),
          ),
        ],
      ),
    );
  }

  Widget _iconeCaisse(String type, Color couleur) {
    switch (type) {
      case 'airbnb':
        return const FaIcon(FontAwesomeIcons.airbnb,
            size: 14, color: Color(0xFFFF5A5F));
      case 'agence':
        return Icon(Icons.store_mall_directory_outlined,
            size: 16, color: couleur);
      case 'banque':
        return Icon(Icons.account_balance_outlined, size: 16, color: couleur);
      default:
        return Icon(Icons.person_outline, size: 16, color: couleur);
    }
  }

  Widget _ligneOperation(CaisseOperation o) {
    final couleur = o.estEntree ? _vert : _rouge;
    final date =
        o.date == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(o.date!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: couleur.withValues(alpha: .1),
            child: _iconeCaisse(o.caisseType, couleur),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.libelle.isEmpty
                      ? (o.estEntree ? 'Entrée' : 'Sortie')
                      : o.libelle,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF17262E)),
                ),
                const SizedBox(height: 2),
                Text('$date • ${o.caisse}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (o.par != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: Color(0xFF6B7B84)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text('par ${o.par}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A5B64))),
                        ),
                      ],
                    ),
                  ),
                LigneCommentaire(o.commentaire,
                    taille: 11.5, marge: const EdgeInsets.only(top: 3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${o.estEntree ? '+' : '−'}${_montantCaisse(o.montant)}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: couleur),
          ),
        ],
      ),
    );
  }
}

// ─── Transactions Tab ────────────────────────────────────────────────────────

/// Une ligne entre-t-elle dans le filtre ? « Dépenses » montre aussi les
/// annulations de charges : son total est alors celui de la vue d'ensemble
/// (dépenses moins charges annulées).
bool _correspond(String type, String? filtre) =>
    filtre == null || type == filtre || (filtre == 'expense' && type == 'expense_reversal');

/// Les types d'écriture, tels que l'utilisateur les nomme.
const _libellesTypes = {
  'income': 'Revenus',
  'expense': 'Dépenses',
  'refund': 'Remboursements',
  'cancellation': 'Annulations',
  'expense_reversal': 'Charges annulées',
};

class _TransactionsTab extends StatelessWidget {
  final List<FinancialTransactionItem> transactions;
  final String? filtre;
  final ValueChanged<String?> onFiltre;

  const _TransactionsTab({
    required this.transactions,
    required this.filtre,
    required this.onFiltre,
  });

  static bool _positif(String type) => type == 'income' || type == 'expense_reversal';

  @override
  Widget build(BuildContext context) {
    final primaire = AppColors.primaryColor;
    final choisies =
        transactions.where((t) => _correspond(t.type, filtre)).toList();
    final total = choisies.fold<double>(
        0, (somme, t) => somme + (_positif(t.type) ? t.amount : -t.amount));

    // Le filtre et le total défilent avec les lignes : ils ne restent pas
    // figés en haut de l'onglet.
    final entete = <Widget>[
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: Color(0xFF4A5B64)),
                const SizedBox(width: 6),
                const Text('Filtrer par type',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF17262E))),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Choisir un type',
                  onSelected: (v) => onFiltre(v == 'tous' ? null : v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'tous', child: Text('Tous les types')),
                    for (final e in _libellesTypes.entries)
                      PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaire.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaire.withValues(alpha: .3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(filtre == null ? 'Tous' : (_libellesTypes[filtre] ?? filtre!),
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.bold, color: primaire)),
                        Icon(Icons.arrow_drop_down, size: 18, color: primaire),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _puce(null, 'Tous', transactions.length),
                  for (final e in _libellesTypes.entries)
                    _puce(e.key, e.value, transactions.where((t) => _correspond(t.type, e.key)).length),
                ],
              ),
            ),
          ],
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFF2F5F7),
        child: Row(
          children: [
            Text('${choisies.length} ligne${choisies.length > 1 ? 's' : ''}'
                '${filtre == 'expense' ? ' • charges annulées déduites' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B84))),
            const Spacer(),
            Text(
              'Total : ${total >= 0 ? '+' : '-'}${total.abs().toStringAsFixed(2)} MAD',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: total >= 0 ? Colors.green.shade700 : Colors.red.shade700),
            ),
          ],
        ),
      ),
    ];

    return ListView.builder(
      itemCount: entete.length + (choisies.isEmpty ? 1 : choisies.length),
      itemBuilder: (_, i) {
        if (i < entete.length) return entete[i];

        if (choisies.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Text(
              filtre == null
                  ? 'Aucune transaction'
                  : 'Aucune ligne « ${_libellesTypes[filtre] ?? filtre} » sur cette période',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        final t = choisies[i - entete.length];
        final isIncome = t.type == 'income';
        final isReversal = t.type == 'expense_reversal';
        final color = isIncome
            ? Colors.green.shade600
            : isReversal
                ? Colors.teal.shade600
                : Colors.red.shade600;
        final sign = _positif(t.type) ? '+' : '-';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Icon(_typeIcon(t.type), color: color, size: 16),
                ),
                title: Text(t.description,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF17262E))),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${t.date} • ${_libellesTypes[t.type] ?? t.type}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 12, color: Color(0xFF6B7B84)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${t.type == 'cancellation' ? 'Supprimée par' : 'Créé par'} ${(t.par ?? '').isEmpty ? '—' : t.par}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A5B64)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  '$sign${t.amount.toStringAsFixed(2)} MAD',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _puce(String? type, String libelle, int nombre) {
    final choisi = filtre == type;
    final primaire = AppColors.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text('$libelle ($nombre)'),
        selected: choisi,
        showCheckmark: false,
        onSelected: (_) => onFiltre(type),
        selectedColor: primaire.withValues(alpha: .15),
        backgroundColor: Colors.white,
        side: BorderSide(color: choisi ? primaire : const Color(0xFFD5DDE2)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: choisi ? FontWeight.bold : FontWeight.w500,
          color: choisi ? primaire : const Color(0xFF4A5B64),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward;
      case 'expense':
        return Icons.arrow_upward;
      case 'refund':
        return Icons.undo;
      case 'cancellation':
        return Icons.cancel_outlined;
      case 'expense_reversal':
        return Icons.undo_rounded;
      default:
        return Icons.attach_money;
    }
  }
}

// ─── Clients Tab ─────────────────────────────────────────────────────────────

class _ClientsTab extends StatelessWidget {
  final ClientStats clients;
  const _ClientsTab({required this.clients});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow(Icons.people, 'Total clients', clients.total,
                Colors.blue.shade600),
            const SizedBox(height: 16),
            _statRow(Icons.person_add, 'Nouveaux clients',
                clients.newClients, Colors.green.shade600),
            const SizedBox(height: 16),
            _statRow(Icons.repeat, 'Clients fidèles', clients.returning,
                Colors.purple.shade600),
          ],
        ),
      ),
    );
  }

  Widget _statRow(IconData icon, String label, int value, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          '$value',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

// ─── Comparative Tab ─────────────────────────────────────────────────────────

class _ComparativeTab extends StatelessWidget {
  final List<PropertyComparative> comparative;

  /// Le tableau affiché, pour les boutons Excel et PDF.
  final TableauExportable? Function() tableau;

  /// Les biens comparés ; nul : tous.
  final Set<int>? selection;
  final ValueChanged<Set<int>?> onSelection;

  const _ComparativeTab({
    required this.comparative,
    required this.tableau,
    required this.selection,
    required this.onSelection,
  });

  void _exporter(BuildContext context, String format) {
    final t = tableau();
    if (t != null) lancerExport(context, t, format);
  }

  Future<void> _choisirBiens(BuildContext context) async {
    final choisis = Set<int>.from(selection ?? comparative.map((p) => p.id));
    final recherche = TextEditingController();

    final resultat = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (feuille) => StatefulBuilder(
        builder: (feuille, maj) {
          final q = recherche.text.trim().toLowerCase();
          final visibles =
              comparative.where((p) => q.isEmpty || p.title.toLowerCase().contains(q)).toList();
          final tous = choisis.length == comparative.length;

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(feuille).size.height * .8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5DDE2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Biens à comparer',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                        ),
                        Text('${choisis.length} / ${comparative.length}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7B84))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: recherche,
                      onChanged: (_) => maj(() {}),
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un bien',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    CheckboxListTile(
                      value: tous,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Tous les biens',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17262E))),
                      onChanged: (v) => maj(() {
                        if (v == true) {
                          choisis.addAll(comparative.map((p) => p.id));
                        } else {
                          choisis.clear();
                        }
                      }),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        children: visibles
                            .map((p) => CheckboxListTile(
                                  value: choisis.contains(p.id),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(p.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14, color: Color(0xFF17262E))),
                                  subtitle: Text(
                                      '${p.reservedDays} nuits réservées • ${p.revenue.toStringAsFixed(0)} MAD',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B84))),
                                  onChanged: (v) => maj(() {
                                    if (v == true) {
                                      choisis.add(p.id);
                                    } else {
                                      choisis.remove(p.id);
                                    }
                                  }),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(feuille).pop(),
                          child: const Text('Annuler'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: choisis.isEmpty
                              ? null
                              : () => Navigator.of(feuille).pop(Set<int>.from(choisis)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Comparer (${choisis.length})'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (resultat == null) return;
    onSelection(resultat.length == comparative.length ? null : resultat);
  }

  @override
  Widget build(BuildContext context) {
    if (comparative.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    final liste = selection == null
        ? comparative
        : comparative.where((p) => selection!.contains(p.id)).toList();

    int jr = 0, jl = 0;
    double ca = 0, dep = 0, remb = 0, ann = 0, ben = 0;
    for (final p in liste) {
      jr += p.reservedDays;
      jl += p.nonReservedDays;
      ca += p.revenue;
      dep += p.expenses;
      remb += p.refunds;
      ann += p.cancellations;
      ben += p.profit;
    }

    final primaire = AppColors.primaryColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Material(
                color: primaire.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => _choisirBiens(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: primaire.withValues(alpha: .4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rtl, size: 18, color: primaire),
                        const SizedBox(width: 6),
                        Text(
                          selection == null
                              ? 'Tous les biens (${comparative.length})'
                              : '${liste.length} bien${liste.length > 1 ? 's' : ''} sur ${comparative.length}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaire),
                        ),
                        Icon(Icons.arrow_drop_down, color: primaire),
                      ],
                    ),
                  ),
                ),
              ),
              if (selection != null)
                TextButton(
                  onPressed: () => onSelection(null),
                  child: const Text('Tous'),
                ),
              ElevatedButton.icon(
                onPressed: () => _exporter(context, 'xlsx'),
                icon: const Icon(Icons.table_chart_outlined, size: 17),
                label: const Text('Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _exporter(context, 'pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Faites glisser le tableau dans les deux sens.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),

          // Tableau a en-tete et premiere colonne figes, totaux en bas.
          TableauFige(
            enteteColonneFigee: 'Appartement',
            entetes: const [
              'Jours réservés',
              'Jours libres',
              'Occupation',
              'CA (MAD)',
              'Dépenses (MAD)',
              'Remboursements (MAD)',
              'Annulations (MAD)',
              'Bénéfice (MAD)',
            ],
            colonneFigee: liste.map((p) => p.title).toList(),
            lignes: liste
                .map((p) => [
                      '${p.reservedDays}',
                      '${p.nonReservedDays}',
                      '${_taux(p.reservedDays, p.nonReservedDays)} %',
                      p.revenue.toStringAsFixed(0),
                      p.expenses.toStringAsFixed(0),
                      p.refunds.toStringAsFixed(0),
                      p.cancellations.toStringAsFixed(0),
                      p.profit.toStringAsFixed(0),
                    ])
                .toList(),
            totaux: [
              '$jr',
              '$jl',
              '${_taux(jr, jl)} %',
              ca.toStringAsFixed(0),
              dep.toStringAsFixed(0),
              remb.toStringAsFixed(0),
              ann.toStringAsFixed(0),
              ben.toStringAsFixed(0),
            ],
            largeurColonneFigee: 130,
          ),
        ],
      ),
    );
  }
}

