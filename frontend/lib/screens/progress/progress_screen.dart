import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  /// dummy data
  final currentWeight = 76.5;
  final lastWeekWeight = 77.8;
  final avgCalories = 2120;
  final bmi = 23.4;

  final List<double> weights = [78, 77.8, 78.2, 78.5, 78.2, 77.6, 77.2, 76.5];
  // final List<double> weights = [78, 77.8, 77.6, 77.4, 77.2, 77.1, 76.8, 76.5];

  @override
  Widget build(BuildContext context) {
    final weightDiff = (currentWeight - lastWeekWeight);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),

            /// ===================== TOP METRICS =====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricCard(
                  label: "Current Weight",
                  value: "$currentWeight kg",
                  mainColor: Colors.blue,
                ),
                _metricCard(
                  label: "Last week",
                  value: "$lastWeekWeight kg",
                  mainColor: Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _metricCard(
                  label: "Calories Avg",
                  value: "$avgCalories kcal",
                  mainColor: Colors.purple,
                ),
                _metricCard(
                  label: "BMI",
                  value: bmi.toStringAsFixed(1),
                  mainColor: Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 35),

            /// ===================== MONTH SELECT =====================
            _monthSelector(),

            const SizedBox(height: 18),

            /// ===================== GRAPH SECTION =====================
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 270,

                /// <<< PERFECT height
                child: LineChart(_buildChart()),
              ),
            ),

            const SizedBox(height: 40),

            /// ===================== RESULT CHANGE =====================
            Center(
              child: Text(
                weightDiff < 0
                    ? "↓ ${(weightDiff.abs()).toStringAsFixed(1)} kg since last week"
                    : "↑ ${weightDiff.toStringAsFixed(1)} kg since last week",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: weightDiff < 0 ? Colors.green : Colors.red,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // =====================
  // beautiful metric card
  // =====================
  Widget _metricCard({
    required String label,
    required String value,
    required Color mainColor,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: mainColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================================
  // Month switching UI
  // ================================
  Widget _monthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundBtn(Icons.chevron_left),
        const Text(
          "October 2025",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        _roundBtn(Icons.chevron_right),
      ],
    );
  }

  Widget _roundBtn(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20),
    );
  }

  // ====================================
  // fl_chart line config
  // ====================================
  LineChartData _buildChart() {
    return LineChartData(
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: List.generate(
            weights.length,
            (i) => FlSpot(i.toDouble(), weights[i]),
          ),
          isCurved: true,
          color: Colors.blue.shade600,
          barWidth: 4,
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
}
