import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime selectedDate = DateTime.now();
  Map<int, bool> expandState = {};

  // Dummy data for meals
  final List<Map<String, dynamic>> mealItemsBreakfast = [
    {"name": "Egg", "cal": 70, "p": 6, "c": 0, "f": 5},
    {"name": "Bread", "cal": 80, "p": 3, "c": 15, "f": 1},
  ];

  final List<Map<String, dynamic>> mealItemsLunch = [
    {"name": "Chicken Breast", "cal": 200, "p": 30, "c": 0, "f": 5},
    {"name": "Rice", "cal": 220, "p": 4, "c": 45, "f": 1},
  ];

  final List<Map<String, dynamic>> mealItemsDinner = [
    {"name": "Salmon", "cal": 250, "p": 25, "c": 0, "f": 15},
    {"name": "Salad", "cal": 80, "p": 2, "c": 8, "f": 3},
  ];

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateSelector(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(0),
                  children: [
                    _sectionHeader("Meals"),
                    _buildMealCard(
                      index: 0,
                      title: "Breakfast",
                      calories: 150,
                      protein: 9,
                      carbs: 15,
                      fat: 6,
                      time: "8:30 AM",
                      items: mealItemsBreakfast,
                    ),
                    _buildMealCard(
                      index: 1,
                      title: "Lunch",
                      calories: 420,
                      protein: 34,
                      carbs: 45,
                      fat: 6,
                      time: "1:00 PM",
                      items: mealItemsLunch,
                    ),
                    _buildMealCard(
                      index: 2,
                      title: "Dinner",
                      calories: 330,
                      protein: 27,
                      carbs: 8,
                      fat: 18,
                      time: "8:00 PM",
                      items: mealItemsDinner,
                    ),
                    const SizedBox(height: 16),
                    _sectionHeader("Weight"),
                    _weightTile(),
                    const SizedBox(height: 16),
                    _sectionHeader("Other Logs"),
                    _otherLogsTile(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
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
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => selectedDate = picked);
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
            onPressed: () {
              setState(() {
                if (selectedDate.isBefore(DateTime.now())) {
                  selectedDate = selectedDate.add(const Duration(days: 1));
                }
              });
            },
          ),
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

  Widget _buildMealCard({
    required int index,
    required String title,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required String time,
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
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              spreadRadius: -2,
              offset: const Offset(0, 3),
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
                    fontSize: 15,
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
              Column(children: items.map((e) => _mealItem(e)).toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macrosRow(int protein, int carbs, int fat) {
    return Row(
      children: [
        _macroBadge(
          "Protein",
          protein,
          Colors.red.shade200,
          Colors.red.shade800,
        ),
        const SizedBox(width: 8),
        _macroBadge("Carbs", carbs, Colors.blue.shade200, Colors.blue.shade800),
        const SizedBox(width: 8),
        _macroBadge(
          "Fats",
          fat,
          Colors.orange.shade200,
          Colors.orange.shade800,
        ),
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
          Text(
            item["name"],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text("${item["cal"]} cal"),
          Text("P${item["p"]} C${item["c"]} F${item["f"]}"),
        ],
      ),
    );
  }

  Widget _weightTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: -2,
            offset: const Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text("Weight", style: TextStyle(fontWeight: FontWeight.w600)),
          Text("72.4 kg", style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _otherLogsTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: -2,
            offset: const Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text("Water Intake", style: TextStyle(fontWeight: FontWeight.w600)),
          Text("1.5 L", style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
