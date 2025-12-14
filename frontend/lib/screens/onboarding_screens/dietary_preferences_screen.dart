import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

enum DietType {
  none,
  vegetarian,
  vegan,
  keto,
  low_carb,
  paleo,
  mediterranean,
  intermittent_fasting,
  custom,
}

class DietOption {
  final DietType id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const DietOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  // Theme constants (aligned with your other onboarding screens)
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827);
  static const neutralTextColor = Color(0xFF6B7280);
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  DietType? _selectedDiet;
  final _customDietController = TextEditingController();
  final _otherAllergiesController = TextEditingController();
  final Set<String> _selectedAllergies = {};

  bool _loading = false;
  bool _saving = false;

  // Diet options (colors chosen to stay cohesive with theme)
  static const List<DietOption> dietOptions = [
    DietOption(
      id: DietType.none,
      title: 'No Specific Diet',
      description: 'I eat everything without restrictions',
      icon: Icons.restaurant,
      color: Color(0xFF374151), // neutral-600
      bgColor: Color(0xFFF9FAFB), // neutral-50
      borderColor: Color(0xFFF3F4F6),
    ),
    DietOption(
      id: DietType.vegetarian,
      title: 'Vegetarian',
      description: 'No meat, but includes dairy and eggs',
      icon: Icons.eco,
      color: Color(0xFF16A34A),
      bgColor: Color(0xFFF0FDF4),
      borderColor: Color(0xFFD1FAE5),
    ),
    DietOption(
      id: DietType.vegan,
      title: 'Vegan',
      description: 'No animal products at all',
      icon: Icons.eco,
      color: Color(0xFF059669),
      bgColor: Color(0xFFECFDF5),
      borderColor: Color(0xFFDCFCE7),
    ),
    DietOption(
      id: DietType.keto,
      title: 'Keto',
      description: 'High fat, very low carb diet',
      icon: Icons.favorite,
      color: Color(0xFF7C3AED),
      bgColor: Color(0xFFF6F3FF),
      borderColor: Color(0xFFEDE9FE),
    ),
    DietOption(
      id: DietType.low_carb,
      title: 'Low-Carb',
      description: 'Reduced carbohydrate intake',
      icon: Icons.grain,
      color: Color(0xFFEA580C),
      bgColor: Color(0xFFFFF7ED),
      borderColor: Color(0xFFFDE8C7),
    ),
    DietOption(
      id: DietType.paleo,
      title: 'Paleo',
      description: 'Whole foods, no processed foods',
      icon: Icons.set_meal,
      color: Color(0xFFF59E0B),
      bgColor: Color(0xFFFFFBEB),
      borderColor: Color(0xFFFEF3C7),
    ),
    DietOption(
      id: DietType.mediterranean,
      title: 'Mediterranean',
      description: 'Fish, olive oil, fruits, and vegetables',
      icon: Icons.set_meal,
      color: Color(0xFF2563EB),
      bgColor: Color(0xFFEEF2FF),
      borderColor: Color(0xFFDBEAFE),
    ),
    DietOption(
      id: DietType.intermittent_fasting,
      title: 'Intermittent Fasting',
      description: 'Time-restricted eating windows',
      icon: Icons.schedule,
      color: Color(0xFF4F46E5),
      bgColor: Color(0xFFEEF2FF),
      borderColor: Color(0xFFEDE9FE),
    ),
    DietOption(
      id: DietType.custom,
      title: 'Custom Diet',
      description: 'I follow my own eating plan',
      icon: Icons.restaurant_menu,
      color: Color(0xFFDB2777),
      bgColor: Color(0xFFFDF2F8),
      borderColor: Color(0xFFFCE7F3),
    ),
  ];

  // Common allergies
  static const List<Map<String, String>> commonAllergies = [
    {'id': 'dairy', 'label': 'Dairy-free'},
    {'id': 'gluten', 'label': 'Gluten-free'},
    {'id': 'nuts', 'label': 'Nut allergy'},
    {'id': 'shellfish', 'label': 'Shellfish allergy'},
    {'id': 'soy', 'label': 'Soy allergy'},
    {'id': 'eggs', 'label': 'Egg allergy'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _customDietController.dispose();
    _otherAllergiesController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('macromate_dietary_preferences') ?? '{}';
    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final dietTypeStr = parsed['dietType'] as String?;
      final allergies =
          (parsed['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final other = parsed['otherAllergies'] as String? ?? '';
      final custom = parsed['customDiet'] as String? ?? '';

      setState(() {
        _selectedDiet = dietTypeStr != null
            ? _dietTypeFromString(dietTypeStr)
            : null;
        _selectedAllergies.clear();
        _selectedAllergies.addAll(allergies);
        _otherAllergiesController.text = other;
        _customDietController.text = custom;
      });
    } catch (_) {
      // ignore parse errors, keep defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DietType _dietTypeFromString(String s) {
    return DietType.values.firstWhere(
      (e) => e.toString().split('.').last == s,
      orElse: () => DietType.none,
    );
  }

  String _dietTypeToString(DietType d) => d.toString().split('.').last;

  void _toggleAllergy(String id) {
    setState(() {
      if (_selectedAllergies.contains(id)) {
        _selectedAllergies.remove(id);
      } else {
        _selectedAllergies.add(id);
      }
    });
  }

  bool isFormValid() {
    if (_selectedDiet == null) return false;
    if (_selectedDiet == DietType.custom &&
        _customDietController.text.trim().isEmpty)
      return false;
    return true;
  }

  Future<void> _handleContinue() async {
    if (!isFormValid()) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    final dietaryData = {
      // BACKEND EXPECTATIONS
      // "dietType": "none",
      // "allergies": ["gluten", "shellfish"],
      // "dislikes": [],
      'dietType': _dietTypeToString(_selectedDiet!),
      'allergies': _selectedAllergies.toList(),
      "dislikes": [],
      // 'customDiet': _selectedDiet == DietType.custom
      //     ? _customDietController.text.trim()
      //     : '',
      // 'otherAllergies': _otherAllergiesController.text.trim(),
    };

    // debugPrint("DIETARY PREFERENCES: ");
    // debugPrint(dietaryData.toString());

    await prefs.setString(
      'onboarding_dietary_preferences',
      jsonEncode(dietaryData),
    );

    setState(() => _saving = false);

    if (!mounted) return;
    // Navigator.of(context).pushNamed('/onboarding/macro-distribution');
    widget.onContinue();
  }

  Widget _buildDietCard(DietOption option) {
    final selected = _selectedDiet == option.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: selected ? option.bgColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? option.borderColor : cardBorderDefault,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedDiet = option.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
              if (selected)
                Container(
                  width: 18,
                  height: 18,
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

  @override
  Widget build(BuildContext context) {
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
                                    Icons.food_bank,
                                    // Icons.utensils,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Dietary preferences',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: headerTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tell us about your eating style and any restrictions so we can personalize your recommendations.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: neutralTextColor),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Diet selection
                          const Text(
                            'Do you follow a specific diet?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: dietOptions
                                .map(
                                  (opt) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildDietCard(opt),
                                  ),
                                )
                                .toList(),
                          ),

                          // Custom input
                          if (_selectedDiet == DietType.custom) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Please describe your custom diet',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: headerTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customDietController,
                              decoration: InputDecoration(
                                hintText:
                                    'e.g., Plant-based with occasional fish',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Allergies
                          const Text(
                            'Do you have any dietary restrictions or allergies?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: commonAllergies.map((a) {
                              final id = a['id']!;
                              final label = a['label']!;
                              final checked = _selectedAllergies.contains(id);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      onChanged: (_) => _toggleAllergy(id),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: headerTextColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 8),
                          const Text(
                            'Other allergies or restrictions (optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _otherAllergiesController,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g., Onions, garlic, specific foods...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Info note (privacy)
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: const [
                                Text(
                                  '🔒 Privacy Note',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: headerTextColor,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your dietary preferences are stored securely and used only to customize your food recommendations and nutrition tracking.',
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
                                backgroundColor: const Color(0xFF2563EB),
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
