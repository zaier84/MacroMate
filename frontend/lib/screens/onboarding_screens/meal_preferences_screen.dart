import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MealPreferencesScreen extends StatefulWidget {
  const MealPreferencesScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<MealPreferencesScreen> createState() => _MealPreferencesScreenState();
}

class _MealPreferencesScreenState extends State<MealPreferencesScreen> {
  // Theme constants (consistent with other onboarding screens)
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  // State
  String? selectedMealCount; // "2", "3", "4", "custom"
  final TextEditingController _customMealCountController =
      TextEditingController();
  List<String> mealTimes = [];
  final List<String> selectedCuisines = [];

  bool _loading = true;
  bool _saving = false;

  // Data (source-of-truth same as TSX)
  final List<Map<String, dynamic>> mealOptions = const [
    {
      'id': '2',
      'title': '2 meals',
      'description': 'Lunch and dinner, or brunch and dinner',
      'icon': '🍽️',
      'times': ['12:00 PM', '7:00 PM'],
    },
    {
      'id': '3',
      'title': '3 meals',
      'description': 'Traditional breakfast, lunch, and dinner',
      'icon': '🍳',
      'times': ['8:00 AM', '1:00 PM', '7:00 PM'],
    },
    {
      'id': '4',
      'title': '4 meals',
      'description': '3 meals + 1 snack for better appetite control',
      'icon': '🥗',
      'times': ['8:00 AM', '12:00 PM', '3:00 PM', '7:00 PM'],
    },
    {
      'id': 'custom',
      'title': 'Custom',
      'description': "I'll set my own meal schedule",
      'icon': '⚙️',
    },
  ];

  final List<String> favoriteCuisines = const [
    'Italian',
    'Mexican',
    'Chinese',
    'Indian',
    'Thai',
    'Japanese',
    'Mediterranean',
    'American',
    'French',
    'Korean',
    'Middle Eastern',
    'Vietnamese',
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _customMealCountController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString('macromate_meal_preferences');
      if (raw != null) {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        final mealCount = parsed['mealCount']?.toString();
        final times =
            (parsed['mealTimes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final cuisines =
            (parsed['favoriteCuisines'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        setState(() {
          if (mealCount != null) {
            // saved can be string "2","3","4" or custom number -> store as string
            selectedMealCount =
                (mealCount == 'custom' || ['2', '3', '4'].contains(mealCount))
                ? mealCount
                : 'custom';
            if (selectedMealCount == 'custom' &&
                !['2', '3', '4'].contains(mealCount)) {
              _customMealCountController.text = mealCount;
            }
          }
          mealTimes = times;
          selectedCuisines.clear();
          selectedCuisines.addAll(cuisines);
        });
      }
    } catch (_) {
      // ignore parse errors
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleMealCountSelect(Map<String, dynamic> option) {
    setState(() {
      selectedMealCount = option['id'] as String?;
      if (option.containsKey('times')) {
        mealTimes = List<String>.from(option['times'] as List<dynamic>);
      } else {
        mealTimes = [];
      }
      if (selectedMealCount != 'custom') {
        _customMealCountController.clear();
      }
    });
  }

  void _toggleCuisine(String cuisine) {
    setState(() {
      if (selectedCuisines.contains(cuisine)) {
        selectedCuisines.remove(cuisine);
      } else {
        selectedCuisines.add(cuisine);
      }
    });
  }

  void _updateMealTime(int index, String value) {
    final newTimes = List<String>.from(mealTimes);
    if (index >= 0 && index < newTimes.length) {
      newTimes[index] = value;
      setState(() => mealTimes = newTimes);
    }
  }

  bool get _isFormValid {
    if (selectedMealCount == null) return false;
    if (selectedMealCount == 'custom' &&
        _customMealCountController.text.trim().isEmpty)
      return false;
    return true;
  }

  Future<void> _handleContinue() async {
    if (!_isFormValid) return;
    setState(() => _saving = true);

    final mealCountValue = selectedMealCount == 'custom'
        ? _customMealCountController.text.trim()
        : selectedMealCount;
    final data = {
      // BACKEND EXPECTATIONS
      // "mealCount": 3,
      // "mealTimes": ["12:00", "19:00"],
      // "favoriteCuisines": ["Chinese"],
      'mealCount': mealCountValue,
      'mealTimes': mealTimes,
      'favoriteCuisines': selectedCuisines,
    };

    // debugPrint("MEAL PREFERENCES: ");
    // debugPrint(data.toString());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onboarding_meal_preferences', jsonEncode(data));

    setState(() => _saving = false);
    if (!mounted) return;
    // Navigator.of(context).pushNamed('/onboarding/notifications');
    widget.onContinue();
  }

  Widget _buildMealCard(Map<String, dynamic> option) {
    final id = option['id'] as String;
    final isSelected = selectedMealCount == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryGradientStart.withOpacity(0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? primaryGradientStart : cardBorderDefault,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleMealCountSelect(option),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Text(
              option['icon'] as String,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: headerTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    option['description'] as String,
                    style: const TextStyle(color: neutralTextColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // Defensive: if loading show loader
    if (_loading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
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
                    // Intro
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
                              Icons.restaurant_menu,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Meal preferences',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: headerTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Help us understand your eating schedule and food preferences.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: neutralTextColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Meal count selection
                    const Text(
                      'How many meals do you eat per day?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: headerTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: mealOptions
                          .map((opt) => _buildMealCard(opt))
                          .toList(),
                    ),

                    // Custom meal count input
                    if (selectedMealCount == 'custom') ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Number of meals per day',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: headerTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customMealCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 5',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Meal times (if not custom and times exist)
                    if (selectedMealCount != null &&
                        selectedMealCount != 'custom' &&
                        mealTimes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Typical meal times (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: headerTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: mealTimes.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final time = entry.value;
                          final controller = TextEditingController(text: time);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Color(0xFF6B7280),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    'Meal ${idx + 1}:',
                                    style: const TextStyle(
                                      color: headerTextColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    onChanged: (v) => _updateMealTime(idx, v),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Favorite cuisines
                    const Text(
                      'Favorite cuisines (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: headerTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select cuisines you enjoy for personalized meal suggestions.',
                      style: TextStyle(color: neutralTextColor, fontSize: 13),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: favoriteCuisines.map((cuisine) {
                        final selected = selectedCuisines.contains(cuisine);
                        return ChoiceChip(
                          label: Text(cuisine),
                          selected: selected,
                          selectedColor: primaryGradientStart.withOpacity(0.12),
                          labelStyle: TextStyle(
                            color: selected
                                ? primaryGradientStart
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: selected
                                ? primaryGradientStart
                                : cardBorderDefault,
                          ),
                          onSelected: (_) => _toggleCuisine(cuisine),
                        );
                      }).toList(),
                    ),

                    if (selectedCuisines.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Selected: ${selectedCuisines.join(", ")}',
                        style: const TextStyle(color: neutralTextColor),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6EE), Color(0xFFE0F2F0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBCE)),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            '📱 Meal Tracking Made Easy',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "We'll use your preferences to suggest meal times and provide personalized food recommendations. You can always adjust these settings later.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: neutralTextColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFormValid && !_saving
                            ? _handleContinue
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: primaryGradientStart,
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

                    const SizedBox(height: 30),
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
