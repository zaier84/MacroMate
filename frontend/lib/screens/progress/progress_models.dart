class ProgressResponse {
  final String month;
  final Metrics metrics;
  final WeightChange weightChange;
  final List<WeightPoint> trend;
  final Units units;
  final Goal goal;
  final String trendStatus;

  ProgressResponse({
    required this.month,
    required this.metrics,
    required this.weightChange,
    required this.trend,
    required this.units,
    required this.goal,
    required this.trendStatus,
  });

  factory ProgressResponse.fromJson(Map<String, dynamic> json) {
    return ProgressResponse(
      month: json['month'],
      metrics: Metrics.fromJson(json['metrics'] ?? {}),
      weightChange: WeightChange.fromJson(json['weightChange'] ?? {}),
      trend: (json['weightTrend'] as List? ?? [])
          .map((e) => WeightPoint.fromJson(e))
          .toList(),
      units: Units.fromJson(json['units'] ?? {}),
      goal: Goal.fromJson(json['goal'] ?? {}),
      trendStatus: json['trend'] ?? 'stable',
    );
  }
}

class Metrics {
  final double? currentWeight;
  final double? lastWeekWeight;
  final double? averageCalories;
  final double? bmi;

  Metrics({
    this.currentWeight,
    this.lastWeekWeight,
    this.averageCalories,
    this.bmi,
  });

  factory Metrics.fromJson(Map<String, dynamic> json) {
    double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

    return Metrics(
      currentWeight: _num(json['currentWeight']),
      lastWeekWeight: _num(json['lastWeekWeight']),
      averageCalories: _num(json['averageCalories']),
      bmi: _num(json['bmi']),
    );
  }
}

class WeightChange {
  final double? value;
  final String direction;

  WeightChange({this.value, required this.direction});

  factory WeightChange.fromJson(Map<String, dynamic> json) {
    return WeightChange(
      value: json['value'] == null ? null : (json['value'] as num).toDouble(),
      direction: json['direction'] ?? 'stable',
    );
  }
}

class WeightPoint {
  final DateTime date;
  final double weight;

  WeightPoint({required this.date, required this.weight});

  factory WeightPoint.fromJson(Map<String, dynamic> json) {
    return WeightPoint(
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
    );
  }
}

class Units {
  final String weight;
  final String calories;

  Units({required this.weight, required this.calories});

  factory Units.fromJson(Map<String, dynamic> json) {
    return Units(
      weight: json['weight'] ?? 'kg',
      calories: json['calories'] ?? 'kcal',
    );
  }
}

class Goal {
  final double? targetWeight;
  final double? remaining;

  Goal({this.targetWeight, this.remaining});

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      targetWeight: json['targetWeight'] == null
          ? null
          : (json['targetWeight'] as num).toDouble(),
      remaining: json['remaining'] == null
          ? null
          : (json['remaining'] as num).toDouble(),
    );
  }
}
