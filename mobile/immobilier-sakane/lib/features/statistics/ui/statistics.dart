import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/statistics/cubit/global_state_cubit.dart';
import 'package:immobilier/models/global_stats.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:immobilier/core/constants/app_colors.dart';
import 'package:immobilier/core/dependencies/dependencies.dart';
import 'package:immobilier/core/utils/show_toast.dart';
import 'package:immobilier/repository/repository.dart';
import 'package:open_file/open_file.dart';
import 'package:toastification/toastification.dart';
import 'package:immobilier/components/tableau_fige.dart';


class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  static Widget page() {
    return BlocProvider<GlobalStateCubit>(
      create: (ctx) => GlobalStateCubit()..fetchData(),
      child: const StatisticsScreen(),
    );
  }

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _exportEnCours = false;

  /// Telecharge les statistiques au format demande puis ouvre le fichier.
  Future<void> _exporter(String format) async {
    setState(() => _exportEnCours = true);
    try {
      final chemin = await Dependencies.get<Repository>()
          .telechargerExportStatistiques(format: format);
      if (!mounted) return;
      showToast(
        {'pdf': 'PDF téléchargé', 'csv': 'Fichier CSV téléchargé'}[format] ??
            'Fichier Excel téléchargé',
        context,
        type: ToastificationType.success,
      );
      await OpenFile.open(chemin);
    } catch (_) {
      if (mounted) {
        showToast("L'export a échoué. Réessayez.", context,
            type: ToastificationType.error);
      }
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Statistiques Globales',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          _exportEnCours
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: "Exporter",
                  onSelected: _exporter,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'xlsx',
                      child: ListTile(
                        leading: Icon(Icons.table_chart_outlined, color: Colors.green),
                        title: Text('Exporter en Excel'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                        title: Text('Exporter en PDF'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'csv',
                      child: ListTile(
                        leading: Icon(Icons.description_outlined, color: Colors.blueGrey),
                        title: Text('Exporter en CSV'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
        ],
      ),
      body: BlocBuilder<GlobalStateCubit, GlobalStateState>(
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(GlobalStateState state) {
    if (state.fetchDataStatus == AppStatus.loading) {
      return  Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Erreur",
        action: AppStrings.tryAgain,
        actionCLick: () =>
            BlocProvider.of<GlobalStateCubit>(context).fetchData(),
      );
    } else if (state.fetchDataStatus == AppStatus.success &&
        state.globalStats != null) {
      return _buildSuccessContent(state.globalStats!, state);
    }
    return const SizedBox();
  }

  Widget _buildSuccessContent(GlobalStats stats, GlobalStateState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFiltersSection(state),
          const SizedBox(height: 16),
          _buildKPIsSection(stats),
          const SizedBox(height: 16),
          _buildIncomeChart(stats),
          const SizedBox(height: 16),
          _buildSummarySection(stats),
          const SizedBox(height: 16),
          _buildTableauDetaille(stats),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(GlobalStateState state) {
    final cubit = BlocProvider.of<GlobalStateCubit>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Période",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPeriodChip('day', 'Jour'),
              const SizedBox(width: 8),
              _buildPeriodChip('month', 'Mois'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MyFormField(
                  label: "",
                  hint: "Date début",
                  readOnly: true,
                  borderColor: Colors.black,
                  activeBorderColor: Colors.black,
                  labelColor: Colors.black,
                  onTap: () => _pickDate(
                    initialDate: state.from!,
                    onPicked: (dt) => cubit.selectDate(dt, "from"),
                  ),
                  controller: TextEditingController()
                    ..text = state.from!.formattedDateFr,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.grey.shade600),
              ),
              Expanded(
                child: MyFormField(
                  label: "",
                  hint: "Date fin",
                  readOnly: true,
                  borderColor: Colors.black,
                  activeBorderColor: Colors.black,
                  labelColor: Colors.black,
                  onTap: () => _pickDate(
                    initialDate: state.to!,
                    onPicked: (dt) => cubit.selectDate(dt, "to"),
                  ),
                  controller: TextEditingController()
                    ..text = state.to!.formattedDateFr,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => cubit.fetchData(),
                  icon: const Icon(Icons.search, color: Colors.white),
                  tooltip: "Rechercher",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label) {
    final cubit = BlocProvider.of<GlobalStateCubit>(context);
    final isSelected = cubit.state.groupBy == value;
    return GestureDetector(
      onTap: () => cubit.changeGoupBy(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildKPIsSection(GlobalStats stats) {
    final total = (stats.totalPlatform ?? 0) + (stats.totalRealworld ?? 0);
    final profit = total - (stats.totalCharges ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  "Plateforme",
                  "${stats.totalPlatform?.toStringAsFixed(2) ?? '0'} MAD",
                  Icons.computer,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  "Réel",
                  "${stats.totalRealworld?.toStringAsFixed(2) ?? '0'} MAD",
                  Icons.handshake,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  "Charges",
                  "${stats.totalCharges?.toStringAsFixed(2) ?? '0'} MAD",
                  Icons.receipt_long,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  "Bénéfice",
                  "${profit.toStringAsFixed(2)} MAD",
                  Icons.trending_up,
                  profit >= 0 ? Colors.teal : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeChart(GlobalStats stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Revenus",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem(Colors.blue, "Plateforme"),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.green, "Réel"),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orange, "Charges"),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child:SfCartesianChart(
              primaryXAxis: CategoryAxis(),
              primaryYAxis: NumericAxis(),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries<StatItem, String>>[
                SplineSeries<StatItem, String>(
                  dataSource: stats.platform ?? [],
                  xValueMapper: (item, _) => item.period ?? '',
                  yValueMapper: (item, _) => item.amount ?? 0,
                  color: Colors.blue,
                  width: 3,
                  name: "Plateforme",
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
                SplineSeries<StatItem, String>(
                  dataSource: stats.realworld ?? [],
                  xValueMapper: (item, _) => item.period ?? '',
                  yValueMapper: (item, _) => item.amount ?? 0,
                  color: Colors.green,
                  width: 3,
                  name: "Réel",
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
                SplineSeries<StatItem, String>(
                  dataSource: stats.charges ?? [],
                  xValueMapper: (item, _) => item.period ?? '',
                  yValueMapper: (item, _) => item.amount ?? 0,
                  color: Colors.orange,
                  width: 3,
                  name: "Charges",
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
              ],
            )
            ,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildSummarySection(GlobalStats stats) {
    final total = (stats.totalPlatform ?? 0) + (stats.totalRealworld ?? 0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Revenu Total",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${total.toStringAsFixed(2)} MAD",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                "Plateforme",
                total == 0
                    ? "0%"
                    : "${((stats.totalPlatform ?? 0) / total * 100).toStringAsFixed(1)}%",
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildSummaryItem(
                "Réel",
                total == 0
                    ? "0%"
                    : "${((stats.totalRealworld ?? 0) / total * 100).toStringAsFixed(1)}%",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) onPicked(picked);
  }

  /// Tableau détaillé par période : première ligne et première colonne figées.
  Widget _buildTableauDetaille(GlobalStats stats) {
    // On regroupe les trois séries par période.
    final periodes = <String>{};
    for (final s in [stats.platform, stats.realworld, stats.charges]) {
      for (final item in (s ?? [])) {
        if (item.period != null) periodes.add(item.period!);
      }
    }
    final tri = periodes.toList()..sort();

    num montant(List<StatItem>? serie, String periode) {
      final trouve = (serie ?? []).where((e) => e.period == periode);
      return trouve.isEmpty ? 0 : (trouve.first.amount ?? 0);
    }

    String f(num v) => v.toStringAsFixed(2).replaceAll('.', ',');

    final lignes = tri.map((p) {
      final plateforme = montant(stats.platform, p);
      final reel = montant(stats.realworld, p);
      final charges = montant(stats.charges, p);
      return [
        f(plateforme),
        f(reel),
        f(plateforme + reel),
        f(charges),
        f(plateforme + reel - charges),
      ];
    }).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Détail par période",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Faites glisser le tableau : l'en-tête et la colonne des périodes restent visibles.",
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TableauFige(
            enteteColonneFigee: "Période",
            entetes: const [
              "Plateforme",
              "Réel",
              "Total",
              "Charges",
              "Solde",
            ],
            colonneFigee: tri,
            lignes: lignes,
          ),
        ],
      ),
    );
  }

}
