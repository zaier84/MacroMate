import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class MealPlanDetailScreen extends StatefulWidget {
  final String planId;

  const MealPlanDetailScreen({super.key, required this.planId});

  @override
  State<MealPlanDetailScreen> createState() => _MealPlanDetailScreenState();
}

class _MealPlanDetailScreenState extends State<MealPlanDetailScreen> {
  final ApiService _api = ApiService();

  bool isLoading = true;
  String? error;

  Map<String, dynamic>? plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final res = await _api.get('/api/meal-plans/${widget.planId}');
      if (res.statusCode != 200) {
        throw Exception('Failed to load plan');
      }
      plan = jsonDecode(res.body);
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Meal Plan',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : _buildPlan(),
    );
  }

  Widget _buildPlan() {
    final days = plan!['days'] as Map<String, dynamic>;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) {
        final entry = days.entries.elementAt(index);
        final date = entry.key;
        final meals = entry.value;

        return _DayCard(date: date, meals: meals);
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  final String date;
  final Map<String, dynamic> meals;

  const _DayCard({required this.date, required this.meals});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...['breakfast', 'lunch', 'dinner']
                .where((m) => meals[m] != null)
                .map((meal) => _MealBlock(mealType: meal, meal: meals[meal]))
                .toList(),
          ],
        ),
      ),
    );
  }
}

class _MealBlock extends StatelessWidget {
  final String mealType;
  final Map<String, dynamic> meal;

  const _MealBlock({required this.mealType, required this.meal});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mealType.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            meal['name'],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MacroChip(label: '🔥 ${meal['calories']} kcal'),
              _MacroChip(label: 'P ${meal['protein']}g'),
              _MacroChip(label: 'C ${meal['carbs']}g'),
              _MacroChip(label: 'F ${meal['fats']}g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;

  const _MacroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import '../../services/api_service.dart';
//
// class MealPlanDetailScreen extends StatefulWidget {
//   final String planId;
//
//   const MealPlanDetailScreen({super.key, required this.planId});
//
//   @override
//   State<MealPlanDetailScreen> createState() => _MealPlanDetailScreenState();
// }
//
// class _MealPlanDetailScreenState extends State<MealPlanDetailScreen> {
//   final ApiService _api = ApiService();
//
//   bool isLoading = true;
//   String? error;
//
//   Map<String, dynamic>? plan;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadPlan();
//   }
//
//   Future<void> _loadPlan() async {
//     try {
//       final res = await _api.get('/api/meal-plans/${widget.planId}');
//       if (res.statusCode != 200) {
//         throw Exception('Failed to load plan');
//       }
//       debugPrint(res.body);
//       plan = jsonDecode(res.body);
//     } catch (e) {
//       error = e.toString();
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Meal Plan')),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : error != null
//           ? Center(child: Text(error!))
//           : _buildPlan(),
//     );
//   }
//
//   Widget _buildPlan() {
//     final days = plan!['days'] as Map<String, dynamic>;
//
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: days.entries.map((entry) {
//         final date = entry.key;
//         final meals = entry.value;
//
//         return Card(
//           margin: const EdgeInsets.only(bottom: 12),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   date,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ...['breakfast', 'lunch', 'dinner']
//                     .where((m) {
//                       return meals[m] != null;
//                     })
//                     .map((meal) {
//                       final m = meals[meal];
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               meal.toUpperCase(),
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                             Text(m['name']),
//                             Text(
//                               'Calories: ${m['calories']} | '
//                               'P: ${m['protein']}g '
//                               'C: ${m['carbs']}g '
//                               'F: ${m['fats']}g',
//                             ),
//                           ],
//                         ),
//                       );
//                     })
//                     .toList(),
//               ],
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }
