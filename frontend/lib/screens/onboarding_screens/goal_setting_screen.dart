import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

enum PrimaryGoal { lose, maintain, gain, fitness, healthy, muscle }

enum WeightChangeRate { slow, moderate, faster, aggressive }

class GoalOption {
  final PrimaryGoal id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const GoalOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}

class WeightRate {
  final WeightChangeRate id;
  final String title;
  final String description;
  final String subtitle;
  final double lbsPerWeek;
  final double kgPerWeek;
  final int? calorieDeficit;
  final int? calorieSurplus;
  final String? warning;

  const WeightRate({
    required this.id,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.lbsPerWeek,
    required this.kgPerWeek,
    this.calorieDeficit,
    this.calorieSurplus,
    this.warning,
  });
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  // App theme constants (aligned with personal_info_screen)
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB); // neutral border
  static const cardAccentBorder = Color(
    0xFFBFDBFE,
  ); // used in personal_info privacy card

  // UI state
  PrimaryGoal? _selectedGoal;
  final _targetWeightController = TextEditingController();
  WeightChangeRate? _selectedRate;

  Map<String, dynamic> basicInfo = {};
  bool _loadingBasic = true;
  bool _saving = false;

  // Goal options updated to use theme-friendly, soft colors
  static const List<GoalOption> goalOptions = [
    GoalOption(
      id: PrimaryGoal.lose,
      title: 'Lose Weight',
      description: 'Create a calorie deficit to shed pounds safely',
      icon: Icons.trending_down,
      color: Color(0xFFDC2626), // red-600
      bgColor: Color(0xFFFEE2E2), // red-50
      borderColor: Color(0xFFFECACA), // red-200
    ),
    GoalOption(
      id: PrimaryGoal.maintain,
      title: 'Maintain Weight',
      description: 'Keep your current weight with balanced nutrition',
      icon: Icons.remove,
      color: Color(0xFF2563EB), // blue-600
      bgColor: Color(0xFFEEF2FF), // blue-50
      borderColor: Color(0xFFDBEAFE), // blue-200
    ),
    GoalOption(
      id: PrimaryGoal.gain,
      title: 'Gain Weight',
      description: 'Build muscle and increase weight in a healthy way',
      icon: Icons.trending_up,
      color: Color(0xFF16A34A), // green-600
      bgColor: Color(0xFFF0FDF4), // green-50
      borderColor: Color(0xFFD1FAE5), // green-200
    ),
    GoalOption(
      id: PrimaryGoal.fitness,
      title: 'Improve Fitness',
      description: 'Focus on strength, endurance, and overall health',
      icon: Icons.fitness_center,
      color: Color(0xFF7C3AED), // purple-600
      bgColor: Color(0xFFF6F3FF), // purple-50
      borderColor: Color(0xFFEDE9FE), // purple-200
    ),
    GoalOption(
      id: PrimaryGoal.healthy,
      title: 'Eat Healthier',
      description: 'Make better food choices and improve nutrition',
      icon: Icons.local_dining,
      color: Color(0xFFEA580C), // orange-600
      bgColor: Color(0xFFFFF7ED), // orange-50
      borderColor: Color(0xFFFDE8C7), // orange-200 (soft)
    ),
    GoalOption(
      id: PrimaryGoal.muscle,
      title: 'Build Muscle',
      description: 'Increase muscle mass and strength',
      icon: Icons.favorite,
      color: Color(0xFFDB2777), // pink-600
      bgColor: Color(0xFFFDF2F8), // pink-50
      borderColor: Color(0xFFFCE7F3), // pink-200
    ),
  ];

  // Weight loss/gain rates (unchanged; kept theme-neutral)
  static const List<WeightRate> weightLossRates = [
    WeightRate(
      id: WeightChangeRate.slow,
      title: 'Slow & Steady',
      description: '0.25 kg / 0.5 lbs per week',
      subtitle: 'Best for sustainable, long-term fat loss',
      lbsPerWeek: 0.5,
      kgPerWeek: 0.25,
      calorieDeficit: 250,
    ),
    WeightRate(
      id: WeightChangeRate.moderate,
      title: 'Moderate',
      description: '0.5 kg / 1 lb per week',
      subtitle: 'A balanced approach—popular and safe for most users',
      lbsPerWeek: 1,
      kgPerWeek: 0.5,
      calorieDeficit: 500,
    ),
    WeightRate(
      id: WeightChangeRate.faster,
      title: 'Faster',
      description: '0.75 kg / 1.5 lbs per week',
      subtitle: 'Still within healthy limits but requires higher discipline',
      lbsPerWeek: 1.5,
      kgPerWeek: 0.75,
      calorieDeficit: 750,
    ),
    WeightRate(
      id: WeightChangeRate.aggressive,
      title: 'Aggressive',
      description: '1 kg / 2 lbs per week',
      subtitle:
          'Max limit for short-term goals. Only for users with significant weight to lose',
      lbsPerWeek: 2,
      kgPerWeek: 1,
      calorieDeficit: 1000,
      warning:
          'Not suitable for everyone—can be hard to maintain. Consult a professional.',
    ),
  ];

  static const List<WeightRate> weightGainRates = [
    WeightRate(
      id: WeightChangeRate.slow,
      title: 'Slow',
      description: '0.25 kg / 0.5 lbs per week',
      subtitle: 'Ideal for lean muscle gain with minimal fat',
      lbsPerWeek: 0.5,
      kgPerWeek: 0.25,
      calorieSurplus: 250,
    ),
    WeightRate(
      id: WeightChangeRate.moderate,
      title: 'Moderate',
      description: '0.5 kg / 1 lb per week',
      subtitle: 'Common rate for general bulking',
      lbsPerWeek: 1,
      kgPerWeek: 0.5,
      calorieSurplus: 500,
    ),
    WeightRate(
      id: WeightChangeRate.faster,
      title: 'Aggressive',
      description: '0.75 kg / 1.5 lbs per week',
      subtitle: 'May lead to faster gains but can include fat mass',
      lbsPerWeek: 1.5,
      kgPerWeek: 0.75,
      calorieSurplus: 750,
    ),
    WeightRate(
      id: WeightChangeRate.aggressive,
      title: 'Very Aggressive',
      description: '1 kg / 2 lbs per week',
      subtitle:
          'Only recommended for underweight users or advanced bulking cycles',
      lbsPerWeek: 2,
      kgPerWeek: 1,
      calorieSurplus: 1000,
      warning: 'Risk of higher fat gain',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBasicInfo();
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadBasicInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('macromate_personal_info') ?? '{}';
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        basicInfo = parsed;
        _loadingBasic = false;
      });
    } catch (_) {
      setState(() {
        basicInfo = {};
        _loadingBasic = false;
      });
    }
  }

  bool get needsTargetWeight {
    return _selectedGoal == PrimaryGoal.lose ||
        _selectedGoal == PrimaryGoal.gain;
  }

  bool get needsRate {
    return needsTargetWeight &&
        (_targetWeightController.text.trim().isNotEmpty);
  }

  bool isFormValid() {
    if (_selectedGoal == null) return false;
    if (needsTargetWeight && _targetWeightController.text.trim().isEmpty) {
      return false;
    }
    if (needsRate && _selectedRate == null) return false;
    return true;
  }

  int calculateCalories() {
    final age = int.tryParse(basicInfo['age']?.toString() ?? '') ?? 0;
    final weight =
        double.tryParse(basicInfo['weight']?.toString() ?? '') ?? 0.0;
    var height = double.tryParse(basicInfo['height']?.toString() ?? '') ?? 0.0;

    if (basicInfo['heightUnit'] == 'ft-in') {
      height = height * 30.48;
    }

    final bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    const activityMultiplier = 1.2;
    final tdee = bmr * activityMultiplier;

    if (_selectedGoal == PrimaryGoal.lose) {
      final rate = weightLossRates.firstWhere(
        (r) => r.id == _selectedRate,
        orElse: () => weightLossRates[1],
      );
      final deficit = rate.calorieDeficit ?? 500;
      return (tdee - deficit).round();
    } else if (_selectedGoal == PrimaryGoal.gain) {
      final rate = weightGainRates.firstWhere(
        (r) => r.id == _selectedRate,
        orElse: () => weightGainRates[1],
      );
      final surplus = rate.calorieSurplus ?? 500;
      return (tdee + surplus).round();
    } else {
      return tdee.round();
    }
  }

  String getWeightChangeLabel() {
    if (_selectedGoal == PrimaryGoal.lose) return 'lose';
    if (_selectedGoal == PrimaryGoal.gain) return 'gain';
    return 'change';
  }

  Future<void> _handleContinue() async {
    if (!isFormValid()) return;
    setState(() => _saving = true);

    debugPrint(basicInfo.toString());

    final targetWeight = double.tryParse(_targetWeightController.text) ?? null;
    final goalData = {
      // BACKEND EXPECTATIOS
      // "primaryGoal": "lose_weight",
      // "targetWeight": 60.0, // kg
      // "weightChangeRate":
      //     "standard", // maps to server preset (standard -> 0.5 kg/week)
      // OR send numeric weekly_goal:
      // "weekly_goal": -0.5

      'primaryGoal': _selectedGoal.toString().split('.').last,
      'targetWeight': targetWeight,
      'weightChangeRate': _selectedRate?.toString().split('.').last,
      // 'currentWeight': double.tryParse(basicInfo['weight']?.toString() ?? ''),
      // 'weightUnit': basicInfo['weightUnit'] ?? 'lbs',
    };

    // debugPrint("GOAL SETTINGS:");
    // debugPrint(goalData.toString());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboarding_goal_setting', jsonEncode(goalData));

    setState(() => _saving = false);

    if (!mounted) return;
    // Navigator.of(context).pushNamed('/onboarding/activity-level');
    widget.onContinue();
  }

  Widget _buildGoalCard(GoalOption option) {
    final isSelected = _selectedGoal == option.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? option.bgColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? option.borderColor : cardBorderDefault,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedGoal = option.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: option.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(option.icon, color: option.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: headerTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: const TextStyle(
                        color: neutralTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: primaryGradientStart,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateCard(WeightRate rate) {
    final isSelected = _selectedRate == rate.id;
    final unit = (basicInfo['weightUnit'] ?? 'lbs').toString();
    final perWeekText = unit == 'lbs'
        ? '${rate.lbsPerWeek} lbs/week'
        : '${rate.kgPerWeek} kg/week';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? primaryGradientStart.withOpacity(0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? primaryGradientStart.withOpacity(0.85)
              : cardBorderDefault,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedRate = rate.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rate.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: headerTextColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          perWeekText,
                          style: TextStyle(
                            color: primaryGradientStart,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rate.subtitle,
                      style: const TextStyle(
                        color: neutralTextColor,
                        fontSize: 13,
                      ),
                    ),
                    if (rate.warning != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rate.warning!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: primaryGradientStart,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalSummary() {
    final unit = (basicInfo['weightUnit'] ?? 'lbs').toString();
    final curWeight =
        double.tryParse(basicInfo['weight']?.toString() ?? '') ?? 0.0;
    final target = double.tryParse(_targetWeightController.text) ?? 0.0;

    final diff = (target - curWeight).abs();
    final rateList = _selectedGoal == PrimaryGoal.lose
        ? weightLossRates
        : weightGainRates;
    final rate = rateList.firstWhere(
      (r) => r.id == _selectedRate,
      orElse: () => rateList[1],
    );
    final perWeek = unit == 'lbs' ? rate.lbsPerWeek : rate.kgPerWeek;
    final weeks = perWeek > 0 ? (diff / perWeek) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAFAFA), Color(0xFFF3F4F6)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Goal Summary',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    diff.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$unit to ${_selectedGoal.toString().split('.').last}',
                    style: const TextStyle(
                      color: neutralTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    perWeek.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryGradientStart,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'unit/week',
                    style: TextStyle(color: neutralTextColor, fontSize: 12),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    weeks.isFinite ? weeks.toStringAsFixed(0) : '0',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'weeks needed',
                    style: TextStyle(color: neutralTextColor, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = (basicInfo['weightUnit'] ?? 'lbs').toString();
    final curWeightText = basicInfo['weight']?.toString() ?? '';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _loadingBasic
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Welcome
                          Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: const LinearGradient(
                                    colors: [
                                      primaryGradientStart,
                                      primaryGradientEnd,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.adjust,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "What's your primary goal?",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: headerTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Choose your main objective to help us personalize your experience.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: neutralTextColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Primary Goal
                          const Text(
                            'Primary Goal',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: goalOptions
                                .map(
                                  (opt) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildGoalCard(opt),
                                  ),
                                )
                                .toList(),
                          ),

                          const SizedBox(height: 16),

                          // Target Weight
                          if (needsTargetWeight) ...[
                            const Text(
                              'What is your goal weight?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: headerTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              alignment: Alignment.centerRight,
                              children: [
                                TextField(
                                  controller: _targetWeightController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    hintText: unit == 'lbs' ? '150' : '68',
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Text(
                                    unit,
                                    style: const TextStyle(
                                      color: neutralTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_targetWeightController.text.isNotEmpty &&
                                curWeightText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'You want to ${getWeightChangeLabel()} ${((double.tryParse(_targetWeightController.text) ?? 0) - (double.tryParse(curWeightText) ?? 0)).abs().toStringAsFixed(1)} $unit',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: neutralTextColor,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],

                          // Rate selection
                          if (needsRate) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'How quickly do you want to ${getWeightChangeLabel()} weight?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: headerTextColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'ℹ️ Safe rates only',
                                    style: TextStyle(
                                      color: primaryGradientStart,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children:
                                  (_selectedGoal == PrimaryGoal.lose
                                          ? weightLossRates
                                          : weightGainRates)
                                      .map(
                                        (r) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: _buildRateCard(r),
                                        ),
                                      )
                                      .toList(),
                            ),

                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                border: Border.all(
                                  color: const Color(0xFFD1FAE5),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Text(
                                    '💡',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Recommended: We suggest aiming for 0.5–1.0 $unit/week for healthy, sustainable progress.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            if (_selectedRate == WeightChangeRate.aggressive)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '⚠️',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Aggressive Rate Selected',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            "This rate is harder to sustain and may not be suitable for everyone. Please consult a health professional if you're unsure. Consider starting with a moderate approach first.",
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 12),

                            if (_targetWeightController.text.isNotEmpty &&
                                curWeightText.isNotEmpty &&
                                _selectedRate != null)
                              _buildGoalSummary(),
                          ],

                          const SizedBox(height: 16),

                          // Calculated calories
                          if (_selectedGoal != null &&
                              _selectedRate != null &&
                              _targetWeightController.text.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryGradientStart.withOpacity(0.05),
                                    primaryGradientEnd.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryGradientStart.withOpacity(0.15),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Text(
                                    'Your Daily Calorie Goal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: headerTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    calculateCalories().toString(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primaryGradientStart,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Based on your ${_selectedGoal.toString().split('.').last} weight goal at a ${(_selectedGoal == PrimaryGoal.lose ? weightLossRates : weightGainRates).firstWhere((r) => r.id == _selectedRate, orElse: () => (_selectedGoal == PrimaryGoal.lose ? weightLossRates[1] : weightGainRates[1])).title.toLowerCase()} pace',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: neutralTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Continue button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isFormValid() && !_saving
                                  ? _handleContinue
                                  : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                backgroundColor: const Color(
                                  0xFF2563EB,
                                ), // match personal_info primary
                                foregroundColor: Colors.white,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
