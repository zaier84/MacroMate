class HomeDashboardResponse {
  final User user;
  final Nutrition nutrition;
  final Vitals vitals;
  final TodaysDiaryData todaysDiary;
  final BodyMetrics bodyMetrics;
  final QuickAccessConfig quickAccess;

  HomeDashboardResponse({
    required this.user,
    required this.nutrition,
    required this.vitals,
    required this.todaysDiary,
    required this.bodyMetrics,
    required this.quickAccess,
  });
}

class User {
  final String name;
  final String? avatarUrl;
  User({required this.name, this.avatarUrl});
}

class Nutrition {
  final int caloriesConsumed;
  final int calorieGoal;
  final Macros macros;
  Nutrition({
    required this.caloriesConsumed,
    required this.calorieGoal,
    required this.macros,
  });
}

class Macros {
  final int proteinPercent;
  final int carbsPercent;
  final int fatPercent;
  Macros({
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });
}

class Vitals {
  final WeightVital weight;
  final WaterVital water;
  final StepsVital steps;
  Vitals({required this.weight, required this.water, required this.steps});
}

class WeightVital {
  final double value;
  final double change;
  final String unit;
  WeightVital({required this.value, required this.change, required this.unit});
}

class WaterVital {
  final double consumed;
  final double goal;
  final String unit;
  WaterVital({required this.consumed, required this.goal, required this.unit});
}

class StepsVital {
  final int count;
  final int goal;
  StepsVital({required this.count, required this.goal});
}

class TodaysDiaryData {
  final int totalCalories;
  final List<dynamic> meals;
  TodaysDiaryData({required this.totalCalories, required this.meals});
}

class BodyMetrics {
  final double heightCm;
  final double weightKg;
  BodyMetrics({required this.heightCm, required this.weightKg});
}

class QuickAccessConfig {
  final bool showSnapMeal;
  final bool showLogWater;
  QuickAccessConfig({required this.showSnapMeal, required this.showLogWater});
}
