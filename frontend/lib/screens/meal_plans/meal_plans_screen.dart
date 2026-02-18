import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onboarding/screens/meal_plans/meal_plan_detail_screen.dart';
import 'package:onboarding/theme/colors.dart';
import '../../services/api_service.dart';

class MealPlansScreen extends StatefulWidget {
  const MealPlansScreen({super.key});

  @override
  State<MealPlansScreen> createState() => _MealPlansScreenState();
}

class _MealPlansScreenState extends State<MealPlansScreen> {
  final ApiService _api = ApiService();

  bool isLoading = true;
  bool isGenerating = false;
  String? error;

  List mealPlans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final res = await _api.get('api/meal-plans');
      if (res.statusCode != 200) {
        throw Exception('Failed to load meal plans');
      }

      final body = jsonDecode(res.body);
      mealPlans = body['meal_plans'] ?? [];
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _generatePlan() async {
    try {
      setState(() => isGenerating = true);

      final res = await _api.post(
        '/api/meal-plans/generate',
        jsonEncode({"days": 7}),
      );

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Failed to generate meal plan');
      }

      await _loadPlans();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Meal Plans',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: isGenerating ? null : _generatePlan,
              icon: isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primaryGradientStart,
                // backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          : mealPlans.isEmpty
          ? _EmptyState(onGenerate: _generatePlan)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: mealPlans.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = mealPlans[i];
                return _MealPlanCard(
                  startDate: p["start_date"],
                  endDate: p["end_date"],
                  days: p["days_count"],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MealPlanDetailScreen(planId: p["plan_id"]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _MealPlanCard extends StatelessWidget {
  final String startDate;
  final String endDate;
  final int days;
  final VoidCallback onTap;

  const _MealPlanCard({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryGradientStart.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  color: AppColors.primaryGradientStart,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startDate → $endDate',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$days day AI-generated meal plan',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGenerate;

  const _EmptyState({required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppColors.primaryGradientStart,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Meal Plans Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate your first AI-powered meal plan tailored to your goals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onGenerate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Generate Meal Plan'),
            ),
          ],
        ),
      ),
    );
  }
}
