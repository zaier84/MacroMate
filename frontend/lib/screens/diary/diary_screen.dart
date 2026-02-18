import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:onboarding/screens/diary/diary_shimmer.dart';
import 'package:onboarding/services/api_service.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final ApiService _api = ApiService();

  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  String? error;

  Map<String, dynamic>? diaryData;
  Map<int, bool> expandState = {};

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  Future<void> _loadDiary() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final res = await _api.get("/api/diary?date=$dateStr");

      if (res.statusCode == 200) {
        diaryData = jsonDecode(res.body);
      } else {
        error = "Failed to load diary";
      }
    } catch (e) {
      error = e.toString();
    }

    setState(() => isLoading = false);
  }

  void _changeDate(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
      expandState.clear();
    });
    _loadDiary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Diary",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
          child: Column(
            children: [
              _buildDateSelector(),
              const SizedBox(height: 8),

              Expanded(
                child: isLoading
                    ? const DiaryShimmer()
                    : error != null
                    ? Center(child: Text(error!))
                    : _buildDiaryContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────

  Widget _buildDiaryContent() {
    final meals = diaryData?["meals"] as List? ?? [];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _sectionHeader("Meals"),

        if (meals.isEmpty)
          _emptyCard("No meals logged for this day")
        else
          ...meals.asMap().entries.map((entry) {
            final i = entry.key;
            final meal = entry.value;

            return _buildMealCard(
              index: i,
              title: meal["title"],
              time: meal["time"],
              calories: (meal["totals"]["calories"] as num).toInt(),
              protein: (meal["totals"]["protein"] as num).round(),
              carbs: (meal["totals"]["carbs"] as num).round(),
              fat: (meal["totals"]["fat"] as num).round(),
              items: List<Map<String, dynamic>>.from(meal["items"]),
            );
          }),

        const SizedBox(height: 16),

        _sectionHeader("Weight"),
        _weightTile(),

        const SizedBox(height: 16),

        _sectionHeader("Other Logs"),
        _otherLogsTile(),

        const SizedBox(height: 40),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // DATE SELECTOR
  // ─────────────────────────────────────────────
  Widget _buildDateSelector() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDateOnly = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final isToday = selectedDateOnly.isAtSameMomentAs(todayDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () =>
                _changeDate(selectedDate.subtract(const Duration(days: 1))),
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: todayDate,
              );
              if (picked != null) _changeDate(picked);
            },
            child: Row(
              children: [
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: isToday
                ? null
                : () => _changeDate(selectedDate.add(const Duration(days: 1))),
            color: isToday ? Colors.grey.shade400 : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MEAL CARD
  // ─────────────────────────────────────────────

  Widget _buildMealCard({
    required int index,
    required String title,
    required String time,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required List<Map<String, dynamic>> items,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          expandState[index] = !(expandState[index] ?? false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              spreadRadius: -2,
              offset: Offset(0, 3),
              color: Colors.black12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "$calories kcal",
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(time, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            _macrosRow(protein, carbs, fat),

            if (expandState[index] == true) ...[
              const SizedBox(height: 12),
              const Divider(),
              ...items.map(_mealItem),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────

  Widget _macrosRow(int p, int c, int f) {
    return Row(
      children: [
        _macroBadge("Protein", p, Colors.red.shade200, Colors.red.shade800),
        const SizedBox(width: 8),
        _macroBadge("Carbs", c, Colors.blue.shade200, Colors.blue.shade800),
        const SizedBox(width: 8),
        _macroBadge("Fats", f, Colors.orange.shade200, Colors.orange.shade800),
      ],
    );
  }

  Widget _macroBadge(String label, int value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$label: $value g",
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _mealItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(item["name"])),
          Text("${item["calories"]} cal"),
          Text(
            "P${(item["protein"] as num).round()} "
            "C${(item["carbs"] as num).round()} "
            "F${(item["fat"] as num).round()}",
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WEIGHT + WATER
  // ─────────────────────────────────────────────

  Widget _weightTile() {
    final weight = diaryData?["weight"]["value"];

    return _simpleTile("Weight", weight == null ? "—" : "$weight kg");
  }

  Widget _otherLogsTile() {
    final water = diaryData?["otherLogs"]["water"];

    return _simpleTile(
      "Water Intake",
      "${water["value"]} / ${water["goal"]} ${water["unit"]}",
    );
  }

  Widget _simpleTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: -2,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
      ),
    );
  }
}
