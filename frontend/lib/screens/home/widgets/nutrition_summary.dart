import 'package:flutter/material.dart';

class NutritionSummary extends StatelessWidget {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const NutritionSummary({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    const brandPrimary = Color(0xFF2563EB);
    const brandSecondary = Color(0xFF06B6D4);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [brandPrimary, brandSecondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.fastfood_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Nutrition Summary",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Calories summary
            Center(
              child: Column(
                children: [
                  Text(
                    "$calories kcal",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Total Calories per day",
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200, thickness: 1),
            const SizedBox(height: 12),

            // Macros distribution
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroStat(
                  label: "Protein",
                  value: protein,
                  color: Colors.purpleAccent,
                ),
                _MacroStat(
                  label: "Carbs",
                  value: carbs,
                  color: Colors.blueAccent,
                ),
                _MacroStat(
                  label: "Fat",
                  value: fat,
                  color: Colors.orangeAccent,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Info summary
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.lightBlue.shade100),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Maintain a balanced macro intake to meet your fitness goals efficiently.",
                      style: TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const textSecondary = Color(0xFF6B7280);

    return Column(
      children: [
        Text(
          "$value%",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: textSecondary)),
      ],
    );
  }
}
