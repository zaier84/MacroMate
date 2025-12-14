import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MacronutrientDistributionScreen extends StatefulWidget {
  const MacronutrientDistributionScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<MacronutrientDistributionScreen> createState() =>
      _MacronutrientDistributionScreenState();
}

class _MacronutrientDistributionScreenState
    extends State<MacronutrientDistributionScreen> {
  // Theme constants (match other onboarding screens)
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827);
  static const neutralTextColor = Color(0xFF6B7280);
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  // Macro limits from TSX
  static const Map<String, Map<String, int>> macroLimits = {
    'protein': {'min': 10, 'max': 35},
    'carbs': {'min': 30, 'max': 65},
    'fat': {'min': 20, 'max': 35},
  };

  // Presets (icons as emoji for quick parity)
  static const presets = [
    {
      'id': 'balanced',
      'name': 'Balanced (Recommended)',
      'desc': 'Science-backed ratio for general health',
      'split': {'protein': 20, 'carbs': 50, 'fat': 30},
      'icon': '⚖️',
    },
    {
      'id': 'high_protein',
      'name': 'High Protein',
      'desc': 'For fat loss and muscle gain',
      'split': {'protein': 30, 'carbs': 40, 'fat': 30},
      'icon': '💪',
    },
    {
      'id': 'low_carb',
      'name': 'Low Carb',
      'desc': 'Ketogenic-style eating',
      'split': {'protein': 25, 'carbs': 25, 'fat': 50},
      'icon': '🥑',
    },
    {
      'id': 'endurance',
      'name': 'Endurance Focus',
      'desc': 'For runners and athletes',
      'split': {'protein': 15, 'carbs': 60, 'fat': 25},
      'icon': '🏃',
    },
  ];

  // UI state
  int protein = 20;
  int carbs = 50;
  int fat = 30;

  bool inputMode = false; // false => sliders, true => numeric input
  bool _loading = true;
  bool _saving = false;

  // Controllers for numeric input mode
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  // Basic info loaded from prefs
  Map<String, dynamic> basicInfo = {};
  Map<String, dynamic> goalSetting = {};
  Map<String, dynamic> activityLevel = {};

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
    _syncControllers();
  }

  @override
  void dispose() {
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _proteinController.text = protein.toString();
    _carbsController.text = carbs.toString();
    _fatController.text = fat.toString();
  }

  Future<void> _loadFromPrefs() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    try {
      basicInfo =
          jsonDecode(prefs.getString('macromate_personal_info') ?? '{}')
              as Map<String, dynamic> ??
          {};
    } catch (_) {
      basicInfo = {};
    }
    try {
      goalSetting =
          jsonDecode(prefs.getString('onboarding_goal_setting') ?? '{}')
              as Map<String, dynamic> ??
          {};
    } catch (_) {
      goalSetting = {};
    }
    try {
      activityLevel =
          jsonDecode(prefs.getString('onboarding_activity_level') ?? '{}')
              as Map<String, dynamic> ??
          {};
    } catch (_) {
      activityLevel = {};
    }

    // Optionally, if previously saved macro distribution exists, load it
    try {
      final macroRaw = prefs.getString('macromate_macro_distribution') ?? '{}';
      final parsed = jsonDecode(macroRaw) as Map<String, dynamic>;
      if (parsed.isNotEmpty &&
          parsed['proteinPercent'] != null &&
          parsed['carbsPercent'] != null &&
          parsed['fatPercent'] != null) {
        protein = (parsed['proteinPercent'] as num).toInt();
        carbs = (parsed['carbsPercent'] as num).toInt();
        fat = (parsed['fatPercent'] as num).toInt();
      }
    } catch (_) {}

    _syncControllers();
    if (mounted) setState(() => _loading = false);
  }

  // Calculate daily calories (Mifflin-St Jeor with gender adjustment, and goal/activity)
  int calculateDailyCalories() {
    final age = int.tryParse(basicInfo['age']?.toString() ?? '') ?? 0;
    double weight =
        double.tryParse(basicInfo['weight']?.toString() ?? '') ??
        0.0; // numeric in stored units
    final weightUnit = basicInfo['weightUnit']?.toString() ?? 'lbs';
    var heightRaw = basicInfo['height']?.toString() ?? '';
    final heightUnit = basicInfo['heightUnit']?.toString() ?? '';
    final isMale = basicInfo['gender']?.toString() == 'male';

    if (weightUnit == 'lbs' && weight > 0) {
      weight = weight / 2.205;
    }

    double heightCm = 0.0;
    if (heightUnit == 'ft-in' && heightRaw.isNotEmpty) {
      // Accept formats like 5'10" or "5.8" (fallback)
      if (heightRaw.contains("'")) {
        try {
          final parts = heightRaw.split("'");
          final feet = double.tryParse(parts[0]) ?? 0.0;
          final inches =
              double.tryParse(
                parts.length > 1 ? parts[1].replaceAll('"', '') : '',
              ) ??
              0.0;
          heightCm = (feet * 12 + inches) * 2.54;
        } catch (_) {
          heightCm = (double.tryParse(heightRaw) ?? 0.0) * 30.48;
        }
      } else {
        heightCm = (double.tryParse(heightRaw) ?? 0.0) * 30.48;
      }
    } else {
      heightCm = double.tryParse(heightRaw) ?? 0.0;
    }

    if (weight <= 0 || heightCm <= 0 || age <= 0) {
      return 2000; // fallback
    }

    double bmr = 10 * weight + 6.25 * heightCm - 5 * age;
    bmr += isMale ? 5 : -161;

    final activityMultiplier = (activityLevel['activityMultiplier'] is num)
        ? (activityLevel['activityMultiplier'] as num).toDouble()
        : 1.2;
    var tdee = bmr * activityMultiplier;

    final goal = goalSetting['primaryGoal']?.toString();
    final rate = goalSetting['weightChangeRate']?.toString();

    final deficits = {
      'slow': 250,
      'moderate': 500,
      'faster': 750,
      'aggressive': 1000,
    };
    final surpluses = {
      'slow': 250,
      'moderate': 500,
      'faster': 750,
      'aggressive': 1000,
    };

    if (goal == 'lose' && rate != null) {
      tdee -= deficits[rate] ?? 500;
    } else if (goal == 'gain' && rate != null) {
      tdee += surpluses[rate] ?? 500;
    }

    return tdee.round();
  }

  int get dailyCalories => calculateDailyCalories();

  Map<String, int> calculateMacroGrams() {
    // protein & carbs 4 kcal/g, fat 9 kcal/g
    final p = ((dailyCalories * protein) / 100 / 4).round();
    final c = ((dailyCalories * carbs) / 100 / 4).round();
    final f = ((dailyCalories * fat) / 100 / 9).round();
    return {'proteinGrams': p, 'carbGrams': c, 'fatGrams': f};
  }

  Map<String, int> get grams => calculateMacroGrams();

  int get total => protein + carbs + fat;
  bool get isValid => total == 100;

  // Robust redistribution when changing one macro value:
  // Sets chosen macro to newValue; distributes remaining (100 - newValue) to other macros
  // proportionally to their previous shares, then clamps to min/max and corrects rounding drift.
  void _setMacroWithRedistribution(String macro, int newValue) {
    final keys = ['protein', 'carbs', 'fat'];
    if (!keys.contains(macro)) return;

    final minVal = macroLimits[macro]!['min']!;
    final maxVal = macroLimits[macro]!['max']!;
    newValue = newValue.clamp(minVal, maxVal);

    final prev = {'protein': protein, 'carbs': carbs, 'fat': fat};
    final others = keys.where((k) => k != macro).toList();
    final remaining = 100 - newValue;
    final totalOthersPrev = prev[others[0]]! + prev[others[1]]!;

    // If totalOthersPrev is zero (edge), split remaining evenly
    int newA = 0;
    int newB = 0;
    if (totalOthersPrev <= 0) {
      newA = (remaining / 2).floor();
      newB = remaining - newA;
    } else {
      final aPrev = prev[others[0]]!;
      final bPrev = prev[others[1]]!;
      final aRaw = (aPrev / totalOthersPrev) * remaining;
      final bRaw = (bPrev / totalOthersPrev) * remaining;
      newA = aRaw.round();
      newB = bRaw.round();
    }

    // Apply min/max clamps to others and distribute any overspill/deficit
    final clampAndFix = (String key, int val) {
      final mn = macroLimits[key]!['min']!;
      final mx = macroLimits[key]!['max']!;
      return val.clamp(mn, mx);
    };

    int aClamped = clampAndFix(others[0], newA);
    int bClamped = clampAndFix(others[1], newB);

    // If clamping changed sum (newValue + aClamped + bClamped) != 100, adjust
    int sumNow = newValue + aClamped + bClamped;
    int diff = 100 - sumNow;

    // Attempt to fix diff by adjusting others within their bounds
    if (diff != 0) {
      // Try to adjust other A then B
      if (diff > 0) {
        // need to add
        final addableA = macroLimits[others[0]]!['max']! - aClamped;
        final takeA = min(addableA, diff);
        aClamped += takeA;
        diff -= takeA;

        final addableB = macroLimits[others[1]]!['max']! - bClamped;
        final takeB = min(addableB, diff);
        bClamped += takeB;
        diff -= takeB;
      } else {
        // diff < 0 need to remove
        final removableA = aClamped - macroLimits[others[0]]!['min']!;
        final takeA = min(removableA, -diff);
        aClamped -= takeA;
        diff += takeA;

        final removableB = bClamped - macroLimits[others[1]]!['min']!;
        final takeB = min(removableB, -diff);
        bClamped -= takeB;
        diff += takeB;
      }
    }

    // Final fallback: if still diff != 0, adjust the macro itself within bounds
    int finalMacro = newValue;
    if (diff != 0) {
      finalMacro = (finalMacro + diff).clamp(minVal, maxVal);
      diff = 100 - (finalMacro + aClamped + bClamped);
      // try adjust others again if needed (rare)
      if (diff != 0) {
        // force adjust bClamped
        bClamped = (bClamped + diff).clamp(
          macroLimits[others[1]]!['min']!,
          macroLimits[others[1]]!['max']!,
        );
      }
    }

    setState(() {
      if (macro == 'protein') {
        protein = finalMacro;
        // assign others in original order
        if (others[0] == 'carbs') {
          carbs = aClamped;
          fat = bClamped;
        } else {
          fat = aClamped;
          carbs = bClamped;
        }
      } else if (macro == 'carbs') {
        carbs = finalMacro;
        if (others[0] == 'protein') {
          protein = aClamped;
          fat = bClamped;
        } else {
          fat = aClamped;
          protein = bClamped;
        }
      } else {
        fat = finalMacro;
        if (others[0] == 'protein') {
          protein = aClamped;
          carbs = bClamped;
        } else {
          carbs = aClamped;
          protein = bClamped;
        }
      }
      _syncControllers();
    });
  }

  // If numeric input mode and user edits one field, clamp it and keep others unchanged;
  // user needs to ensure total becomes 100 or press Reset/Presets.
  // void _handleInputChange(String macro, String value) {
  //   final v = int.tryParse(value) ?? 0;
  //   final mn = macroLimits[macro]!['min']!;
  //   final mx = macroLimits[macro]!['max']!;
  //   final clamped = v.clamp(mn, mx);
  //   setState(() {
  //     if (macro == 'protein') protein = clamped;
  //     if (macro == 'carbs') carbs = clamped;
  //     if (macro == 'fat') fat = clamped;
  //     _syncControllers();
  //   });
  // }

  void _handleInputChange(String macro, String value) {
    final v = int.tryParse(value) ?? 0;
    final mn = macroLimits[macro]!['min']!;
    final mx = macroLimits[macro]!['max']!;
    final clamped = v.clamp(mn, mx);
    int newP = protein, newC = carbs, newF = fat;
    if (macro == 'protein') newP = clamped;
    if (macro == 'carbs') newC = clamped;
    if (macro == 'fat') newF = clamped;

    // Try to set safely using redistribution to ensure sliders stay valid.
    _setSplitSafe(newP, newC, newF);
  }

  void _setSplitSafe(int p, int c, int f) {
    final keys = ['protein', 'carbs', 'fat'];
    final mins = {
      'protein': macroLimits['protein']!['min']!,
      'carbs': macroLimits['carbs']!['min']!,
      'fat': macroLimits['fat']!['min']!,
    };
    final maxs = {
      'protein': macroLimits['protein']!['max']!,
      'carbs': macroLimits['carbs']!['max']!,
      'fat': macroLimits['fat']!['max']!,
    };

    // Initial clamp
    p = p.clamp(mins['protein']!, maxs['protein']!);
    c = c.clamp(mins['carbs']!, maxs['carbs']!);
    f = f.clamp(mins['fat']!, maxs['fat']!);

    // Fix sum
    int sum = p + c + f;
    int diff = 100 - sum;

    // Distribute diff across macros that are not at their limits
    // Try multiple passes if needed.
    List<String> order = [
      'carbs',
      'fat',
      'protein',
    ]; // preference order to absorb diff
    int tries = 0;
    while (diff != 0 && tries < 10) {
      bool changed = false;
      for (final k in order) {
        if (diff == 0) break;
        int cur;
        if (k == 'protein')
          cur = p;
        else if (k == 'carbs')
          cur = c;
        else
          cur = f;

        final minK = mins[k]!;
        final maxK = maxs[k]!;

        if (diff > 0) {
          final room = maxK - cur;
          if (room > 0) {
            final delta = min(room, diff);
            if (k == 'protein') p += delta;
            if (k == 'carbs') c += delta;
            if (k == 'fat') f += delta;
            diff -= delta;
            changed = true;
          }
        } else {
          // diff < 0 => need to reduce some value
          final excess = cur - minK;
          if (excess > 0) {
            final delta = min(excess, -diff);
            if (k == 'protein') p -= delta;
            if (k == 'carbs') c -= delta;
            if (k == 'fat') f -= delta;
            diff += delta;
            changed = true;
          }
        }
      }

      if (!changed) break;
      tries++;
    }

    // Final fallback: if still a diff (rare), adjust protein within bounds
    if (diff != 0) {
      final mn = mins['protein']!, mx = maxs['protein']!;
      final candidate = (p + diff).clamp(mn, mx);
      diff = diff - (candidate - p);
      p = candidate;
    }

    setState(() {
      protein = p;
      carbs = c;
      fat = f;
      _syncControllers();
    });
  }

  // void _applyPreset(Map<String, dynamic> preset) {
  //   final split = preset['split'] as Map<String, dynamic>;
  //   setState(() {
  //     protein = (split['protein'] as num).toInt();
  //     carbs = (split['carbs'] as num).toInt();
  //     fat = (split['fat'] as num).toInt();
  //     _syncControllers();
  //   });
  // }

  void _applyPreset(Map<String, dynamic> preset) {
    final split = preset['split'] as Map<String, dynamic>;
    final p = (split['protein'] as num).toInt();
    final c = (split['carbs'] as num).toInt();
    final f = (split['fat'] as num).toInt();
    _setSplitSafe(p, c, f);
  }

  void _resetToDefault() {
    setState(() {
      protein = 20;
      carbs = 50;
      fat = 30;
      _syncControllers();
    });
  }

  Future<void> _handleContinue() async {
    if (!isValid) return;

    setState(() => _saving = true);

    final gramsMap = grams;
    final macroData = {
      // BACKEND EXPECTATIONS
      // "proteinPercent": 30,
      // "carbsPercent": 45,
      // "fatPercent": 25,
      'proteinPercent': protein,
      'carbsPercent': carbs,
      'fatPercent': fat,
      // 'dailyCalories': dailyCalories,
      // 'proteinGrams': gramsMap['proteinGrams'],
      // 'carbGrams': gramsMap['carbGrams'],
      // 'fatGrams': gramsMap['fatGrams'],
    };

    // debugPrint("MACRO DISTRIBUTION: ");
    // debugPrint(macroData.toString());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'onboarding_macro_distribution',
      jsonEncode(macroData),
    );

    setState(() => _saving = false);

    if (!mounted) return;
    // Navigator.of(context).pushNamed('/onboarding/tracking-preferences');
    widget.onContinue();
  }

  Widget _smallCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderDefault),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gramsMap = grams;
    final proteinGrams = gramsMap['proteinGrams'];
    final carbGrams = gramsMap['carbGrams'];
    final fatGrams = gramsMap['fatGrams'];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _loading
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
                                    Icons.bar_chart,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Macronutrient Split',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: headerTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Adjust how much of your daily calories come from each macronutrient.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: neutralTextColor),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Daily calories card
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
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Text(
                                  'Your Daily Calorie Target',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${dailyCalories.toString()} kcal',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: primaryGradientStart,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Based on your goals and activity level',
                                  style: TextStyle(color: neutralTextColor),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Presets grid
                          const Text(
                            'Quick Presets',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: presets.map((p) {
                              final split = p['split'] as Map<String, dynamic>;
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _applyPreset(p),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: cardBorderDefault,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        p['icon'] as String,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        p['name'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: headerTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        p['desc'] as String,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${split['protein']}% • ${split['carbs']}% • ${split['fat']}%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: primaryGradientStart,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 12),

                          // Custom Distribution header
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Custom Distribution',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    setState(() => inputMode = !inputMode),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: headerTextColor,
                                  elevation: 0,
                                  side: const BorderSide(
                                    color: cardBorderDefault,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  inputMode ? 'Sliders' : 'Numbers',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _resetToDefault,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: headerTextColor,
                                  elevation: 0,
                                  side: const BorderSide(
                                    color: cardBorderDefault,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.refresh, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'Reset',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Protein section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Protein',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: headerTextColor,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Supports muscle growth and repair',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$protein%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                      Text(
                                        '${proteinGrams}g',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (inputMode)
                                TextField(
                                  controller: _proteinController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      _handleInputChange('protein', v),
                                )
                              else
                                Slider(
                                  value: protein
                                      .clamp(
                                        macroLimits['protein']!['min']!,
                                        macroLimits['protein']!['max']!,
                                      )
                                      .toDouble(),
                                  // value: protein.toDouble(),
                                  min: macroLimits['protein']!['min']!
                                      .toDouble(),
                                  max: macroLimits['protein']!['max']!
                                      .toDouble(),
                                  divisions:
                                      macroLimits['protein']!['max']! -
                                      macroLimits['protein']!['min']!,
                                  label: '$protein%',
                                  onChanged: (val) {
                                    _setMacroWithRedistribution(
                                      'protein',
                                      val.round(),
                                    );
                                  },
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${macroLimits['protein']!['min']}%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${macroLimits['protein']!['max']}%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Carbs section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Carbohydrates',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: headerTextColor,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Primary energy source for your body',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$carbs%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      Text(
                                        '${carbGrams}g',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (inputMode)
                                TextField(
                                  controller: _carbsController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      _handleInputChange('carbs', v),
                                )
                              else
                                Slider(
                                  value: carbs
                                      .clamp(
                                        macroLimits['carbs']!['min']!,
                                        macroLimits['carbs']!['max']!,
                                      )
                                      .toDouble(),
                                  // value: carbs.toDouble(),
                                  min: macroLimits['carbs']!['min']!.toDouble(),
                                  max: macroLimits['carbs']!['max']!.toDouble(),
                                  divisions:
                                      macroLimits['carbs']!['max']! -
                                      macroLimits['carbs']!['min']!,
                                  label: '$carbs%',
                                  onChanged: (val) {
                                    _setMacroWithRedistribution(
                                      'carbs',
                                      val.round(),
                                    );
                                  },
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${macroLimits['carbs']!['min']}%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${macroLimits['carbs']!['max']}%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Fats section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Fats',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: headerTextColor,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Supports hormones and cell health',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$fat%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFEA580C),
                                        ),
                                      ),
                                      Text(
                                        '${fatGrams}g',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (inputMode)
                                TextField(
                                  controller: _fatController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      _handleInputChange('fat', v),
                                )
                              else
                                Slider(
                                  value: fat
                                      .clamp(
                                        macroLimits['fat']!['min']!,
                                        macroLimits['fat']!['max']!,
                                      )
                                      .toDouble(),
                                  // value: fat.toDouble(),
                                  min: macroLimits['fat']!['min']!.toDouble(),
                                  max: macroLimits['fat']!['max']!.toDouble(),
                                  divisions:
                                      macroLimits['fat']!['max']! -
                                      macroLimits['fat']!['min']!,
                                  label: '$fat%',
                                  onChanged: (val) {
                                    _setMacroWithRedistribution(
                                      'fat',
                                      val.round(),
                                    );
                                  },
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${macroLimits['fat']!['min']}%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${macroLimits['fat']!['max']}%',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Validation card
                          Container(
                            decoration: BoxDecoration(
                              color: isValid
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isValid
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFFECACA),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Text(
                                  isValid ? '✅' : '❌',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: isValid
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total: $total%',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isValid
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF7C2D12),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isValid
                                            ? 'Perfect! Your macros add up to 100%'
                                            : 'Adjust to reach exactly 100% (currently $total%)',
                                        style: TextStyle(
                                          color: isValid
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Summary card
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFAFAFA), Color(0xFFF3F4F6)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Daily Targets',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          '${proteinGrams}g',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Protein',
                                          style: TextStyle(
                                            color: neutralTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${protein}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          '${carbGrams}g',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Carbs',
                                          style: TextStyle(
                                            color: neutralTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${carbs}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          '${fatGrams}g',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFEA580C),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Fat',
                                          style: TextStyle(
                                            color: neutralTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${fat}%',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Continue
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isValid && !_saving
                                  ? _handleContinue
                                  : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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

                          const SizedBox(height: 36),
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
