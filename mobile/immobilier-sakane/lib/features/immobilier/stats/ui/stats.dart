import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:immobilier/components/error_widget.dart';
import 'package:immobilier/components/form_field.dart';
import 'package:immobilier/components/loading_indicator.dart';
import 'package:immobilier/core/constants/app_strings.dart';
import 'package:immobilier/core/constants/enums/app_status.dart';
import 'package:immobilier/core/extensions/extension_on_date.dart';
import 'package:immobilier/features/immobilier/stats/cubit/stats_cubit.dart';
import 'package:immobilier/models/realestate_stats.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:immobilier/core/constants/app_colors.dart';



class StatsScreen extends StatefulWidget {
  StatsScreen({Key? key}) : super(key: key);

  static Widget page(int id) {
    return BlocProvider<StatsCubit>(
      create: (ctx) => StatsCubit(id)..fetchData(),
      child: StatsScreen(),
    );
  }

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedPeriod = 'day';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Statistiques',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          return _buildContent(state);
        },
      ),
    );
  }

  Widget _buildContent(StatsState state) {
    if (state.fetchDataStatus == AppStatus.loading) {
      return Center(child: MyLoadingIndicator());
    } else if (state.fetchDataStatus == AppStatus.error) {
      return MyErrorWidget(
        error: state.error ?? "Error",
        action: AppStrings.tryAgain,
        actionCLick: () => BlocProvider.of<StatsCubit>(context).fetchData(),
      );
    } else if (state.fetchDataStatus == AppStatus.success &&
        state.realestateStats != null) {
      return _buildSuccessContent(state);
    }
    return SizedBox();
  }

  Widget _buildSuccessContent(StatsState state) {
    final stats = state.realestateStats!;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Filters section
          _buildFiltersSection(state),

          SizedBox(height: 16),

          // KPIs section
          _buildKPIsSection(stats),

          SizedBox(height: 16),

          // Income chart
          _buildIncomeChart(stats),

          SizedBox(height: 16),

          // Summary section
          _buildSummarySection(stats),

          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(StatsState state) {
    final cubit = BlocProvider.of<StatsCubit>(context);
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Période",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildPeriodChip('day', 'Jour'),
              /*SizedBox(width: 8),
              _buildPeriodChip('week', 'Semaine'),*/
              SizedBox(width: 8),
              _buildPeriodChip('month', 'Mois'),
            ],
          ),
          SizedBox(height: 16),
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
                  //suffix: Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
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
                  //suffix: Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: fetchData,
                  icon: Icon(Icons.search, color: Colors.white),
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
    final cubit = BlocProvider.of<StatsCubit>(context);
    final isSelected = cubit.state.groupBy == value;
    return GestureDetector(
      onTap: () {
        cubit.changeGoupBy(value);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildKPIsSection(RealestateStats stats) {
    final total = stats.platform + stats.realworld;
    final profit = total - stats.charges;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  "Plateforme",
                  "${stats.platform.toStringAsFixed(2)} MAD",
                  Icons.computer,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  "Réel",
                  "${stats.realworld.toStringAsFixed(2)} MAD",
                  Icons.handshake,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  "Charges",
                  "${stats.charges.toStringAsFixed(2)} MAD",
                  Icons.receipt_long,
                  Colors.orange,
                ),
              ),
              SizedBox(width: 12),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Spacer(),
            ],
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /* Widget _buildIncomeChart(RealestateStats stats) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Revenus",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem(Colors.blue, "Plateforme"),
              SizedBox(width: 16),
              _buildLegendItem(Colors.green, "Réel"),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: stats.platformValues.isEmpty && stats.realworldValues.isEmpty
                ? Center(
              child: Text(
                "Aucune donnée disponible",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
                : LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 200,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < stats.platformValues.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              stats.platformValues[value.toInt()].period,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          );
                        }
                        return SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Platform line
                  LineChartBarData(
                    spots: stats.platformValues.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.amount);
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                  // Realworld line
                  LineChartBarData(
                    spots: stats.realworldValues.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.amount);
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
*/

  Widget _buildIncomeChart(RealestateStats stats) {
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
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: stats.platformValues.isEmpty && stats.realworldValues.isEmpty
                ? Center(
                    child: Text(
                      "Aucune donnée disponible",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      labelRotation: 45,
                      labelStyle: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                      ),
                    ),
                    primaryYAxis: NumericAxis(
                      labelStyle: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                      ),
                    ),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    legend: Legend(isVisible: false),
                    series: <CartesianSeries<dynamic, String>>[
                      // Plateforme line
                      SplineSeries<dynamic, String>(
                        dataSource: stats.platformValues,
                        xValueMapper: (item, _) => item.period,
                        yValueMapper: (item, _) => item.amount,
                        color: Colors.blue,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                        name: 'Plateforme',
                        enableTooltip: true,
                      ),
                      // Réel line
                      SplineSeries<dynamic, String>(
                        dataSource: stats.realworldValues,
                        xValueMapper: (item, _) => item.period,
                        yValueMapper: (item, _) => item.amount,
                        color: Colors.green,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                        name: 'Réel',
                        enableTooltip: true,
                      ),
                    ],
                  ),
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
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildSummarySection(RealestateStats stats) {
    final total = stats.platform + stats.realworld;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
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
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Revenu Total",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "${total.toStringAsFixed(2)} MAD",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.3)),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                "Plateforme",
                "${((stats.platform / total) * 100).toStringAsFixed(1)}%",
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildSummaryItem(
                "Réel",
                "${((stats.realworld / total) * 100).toStringAsFixed(1)}%",
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  void fetchData() {
    BlocProvider.of<StatsCubit>(context).fetchData();
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) onPicked(picked);
  }
}
