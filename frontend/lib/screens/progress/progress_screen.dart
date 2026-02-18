import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onboarding/screens/progress/progress_skeleton.dart';
import 'progress_controller.dart';
import 'progress_models.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final ProgressController controller;

  @override
  void initState() {
    super.initState();
    controller = ProgressController()..load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FB),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "Progress",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: controller.loading
              ? const ProgressSkeleton()
              // ? _skeleton()
              : controller.error != null
              ? _error()
              : _content(controller.data!),
        );
      },
    );
  }

  Widget _content(ProgressResponse data) {
    // final hasTrend = data.trend.isNotEmpty;
    // final monthLabel = DateFormat.yMMMM().format(controller.selectedMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _monthSelector(controller),
          // _monthSelector(monthLabel),
          const SizedBox(height: 20),

          _metrics(data),
          const SizedBox(height: 30),

          if (!hasAnyWeightData(data))
            _emptyState(data)
          else
            // LineChart(_chart(data)),
            SizedBox(
              height: 300, // or whatever looks good
              child: LineChart(_chart(data)),
            ),

          // if (!hasTrend) _emptyState(),
          // if (hasTrend) _chart(data),
          const SizedBox(height: 30),

          _weightChangeText(data),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return "${months[d.month - 1]} ${d.year}";
  }

  Widget _monthSelector(ProgressController c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundBtn(Icons.chevron_left, c.previousMonth),
        Text(
          _monthLabel(c.selectedMonth),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        _roundBtn(
          Icons.chevron_right,
          c.isCurrentMonth ? null : c.nextMonth,
          disabled: c.isCurrentMonth,
        ),
      ],
    );
  }

  String weightText(double? value, String unit) {
    if (value == null) return "—";
    return "${value.toStringAsFixed(1)} $unit";
  }

  String caloriesText(double? value, String unit) {
    if (value == null) return "—";
    return "${value.toInt()} $unit";
  }

  String bmiText(double? bmi) {
    return bmi == null ? "—" : bmi.toStringAsFixed(1);
  }

  Widget _metrics(ProgressResponse d) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metric(
              "Current Weight",
              weightText(d.metrics.currentWeight, d.units.weight),
              Colors.blue,
            ),
            _metric(
              "Last Week",
              weightText(d.metrics.lastWeekWeight, d.units.weight),
              Colors.amber,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metric(
              "Calories Avg",
              caloriesText(d.metrics.averageCalories, d.units.calories),
              Colors.purple,
            ),
            _metric("BMI", bmiText(d.metrics.bmi), Colors.green),
          ],
        ),
      ],
    );
  }

  LineChartData _chart(ProgressResponse d) {
    if (d.trend.isEmpty) {
      return LineChartData(); // empty-state handled elsewhere
    }

    // final spots = <FlSpot>[];
    //
    // for (int i = 0; i < d.weightTrend.length; i++) {
    //   spots.add(FlSpot(i.toDouble(), d.weightTrend[i].weight!));
    // }

    final spots = <FlSpot>[];

    for (int i = 0; i < d.trend.length; i++) {
      spots.add(FlSpot(i.toDouble(), d.trend[i].weight));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),

      /// ===================== AXIS LABELS =====================
      titlesData: FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),

        /// Y axis (Weight)
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 40,
            getTitlesWidget: (value, _) {
              return Text(
                "${value.toStringAsFixed(0)} ${d.units.weight}",
                style: const TextStyle(fontSize: 11),
              );
            },
          ),
        ),

        /// X axis (Day of month)
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, _) {
              final index = value.toInt();
              if (index < 0 || index >= d.trend.length) {
                return const SizedBox.shrink();
              }

              // final date = DateTime.parse(d.weightTrend[index].date);
              // return Padding(
              //   padding: const EdgeInsets.only(top: 6),
              //   child: Text(
              //     date.day.toString(),
              //     style: const TextStyle(fontSize: 11),
              //   ),
              // );
              final date = d.trend[index].date;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  date.day.toString(),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
        ),
      ),

      /// ===================== LINE =====================
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 4,
          color: Colors.blue.shade600,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(.35),
                Colors.blue.withOpacity(.02),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _chart(ProgressResponse d) {
  //   return SizedBox(
  //     height: 260,
  //     child: LineChart(
  //       LineChartData(
  //         gridData: FlGridData(show: false),
  //         borderData: FlBorderData(show: false),
  //         titlesData: FlTitlesData(show: false),
  //         lineBarsData: [
  //           LineChartBarData(
  //             spots: List.generate(
  //               d.trend.length,
  //               (i) => FlSpot(i.toDouble(), d.trend[i].weight),
  //             ),
  //             isCurved: true,
  //             barWidth: 4,
  //             color: Colors.blue,
  //             dotData: FlDotData(show: true),
  //             belowBarData: BarAreaData(
  //               show: true,
  //               gradient: LinearGradient(
  //                 colors: [
  //                   Colors.blue.withOpacity(.35),
  //                   Colors.blue.withOpacity(.02),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _weightChangeText(ProgressResponse d) {
    final v = d.weightChange.value;

    if (v == null) {
      return const Text(
        "No change since last week",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      );
    }

    final down = d.weightChange.direction == 'down';

    return Text(
      "${down ? '↓' : '↑'} ${v.abs().toStringAsFixed(1)} ${d.units.weight} since last week",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: down ? Colors.green : Colors.red,
      ),
    );
  }

  bool hasAnyWeightData(ProgressResponse d) {
    return d.metrics.currentWeight != null ||
        d.metrics.lastWeekWeight != null ||
        d.trend.isNotEmpty;
  }

  Widget _emptyState(ProgressResponse d) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Icon(Icons.timeline, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 14),
        const Text(
          "No progress data yet",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          "Start logging your weight to see insights here",
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        if (d.goal.targetWeight != null) ...[
          const SizedBox(height: 18),
          Text(
            "Goal: ${d.goal.targetWeight} ${d.units.weight}",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  Widget _error() {
    return const Center(
      child: Text(
        "Failed to load progress",
        style: TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _roundBtn(
    IconData icon,
    VoidCallback? onTap, {
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade200 : Colors.white,
          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: disabled ? Colors.grey : Colors.black,
        ),
      ),
    );
  }
}
