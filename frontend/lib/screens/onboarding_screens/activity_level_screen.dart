import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

enum ActivityLevel {
  sedentary,
  lightly_active,
  moderately_active,
  very_active,
  super_active,
}

class ActivityOption {
  final ActivityLevel id;
  final String title;
  final String description;
  final String details;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final double multiplier;

  const ActivityOption({
    required this.id,
    required this.title,
    required this.description,
    required this.details,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.multiplier,
  });
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  // theme constants (matching your onboarding screens)
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  ActivityLevel? _selected;
  bool _saving = false;

  // Activity options converted from TSX
  static const List<ActivityOption> activityOptions = [
    ActivityOption(
      id: ActivityLevel.sedentary,
      title: 'Sedentary',
      description: 'Little to no exercise',
      details: 'Desk job, no regular exercise, minimal walking',
      icon: Icons.event_seat,
      iconColor: Color(0xFF374151),
      bgColor: Color(0xFFF9FAFB),
      borderColor: Color(0xFFF3F4F6),
      multiplier: 1.2,
    ),
    ActivityOption(
      id: ActivityLevel.lightly_active,
      title: 'Lightly Active',
      description: 'Light exercise 1–3 days/week',
      details: 'Light workouts, walking, or sports occasionally',
      icon: Icons.self_improvement,
      iconColor: Color(0xFF2563EB),
      bgColor: Color(0xFFEEF2FF),
      borderColor: Color(0xFFDBEAFE),
      multiplier: 1.375,
    ),
    ActivityOption(
      id: ActivityLevel.moderately_active,
      title: 'Moderately Active',
      description: 'Moderate exercise 3–5 days/week',
      details: 'Regular workouts, active lifestyle, consistent training',
      icon: Icons.directions_bike,
      iconColor: Color(0xFF16A34A),
      bgColor: Color(0xFFF0FDF4),
      borderColor: Color(0xFFD1FAE5),
      multiplier: 1.55,
    ),
    ActivityOption(
      id: ActivityLevel.very_active,
      title: 'Very Active',
      description: 'Hard exercise 6–7 days/week',
      details: 'Daily intense workouts, training programs, active job',
      icon: Icons.flash_on,
      iconColor: Color(0xFFEA580C),
      bgColor: Color(0xFFFFF7ED),
      borderColor: Color(0xFFFDE8C7),
      multiplier: 1.725,
    ),
    ActivityOption(
      id: ActivityLevel.super_active,
      title: 'Super Active',
      description: 'Twice per day, heavy workouts',
      details: 'Multiple daily workouts, physical job, competitive athlete',
      icon: Icons.local_fire_department,
      iconColor: Color(0xFFDC2626),
      bgColor: Color(0xFFFEE2E2),
      borderColor: Color(0xFFFECACA),
      multiplier: 1.9,
    ),
  ];

  Future<void> _saveAndContinue() async {
    if (_selected == null) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    final activityData = {
      // BACKEND EXPECTATIONS
      // "activityLevel": "moderate",
      // "activityMultiplier": 1.55,

      'activityLevel': _selected.toString().split('.').last,
      'activityMultiplier':
          activityOptions.firstWhere((a) => a.id == _selected).multiplier ??
          1.2,
    };

    // debugPrint("ACTIVITY LEVEL: ");
    // debugPrint(activityData.toString());

    await prefs.setString(
      'onboarding_activity_level',
      jsonEncode(activityData),
    );

    setState(() => _saving = false);

    if (!mounted) return;
    // Navigator.of(context).pushNamed('/onboarding/dietary-preferences');
    widget.onContinue();
  }

  Widget _buildActivityCard(ActivityOption option) {
    final isSelected = _selected == option.id;
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
        onTap: () => setState(() => _selected = option.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: option.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(option.icon, color: option.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: headerTextColor,
                            ),
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
                    const SizedBox(height: 4),
                    Text(
                      option.description,
                      style: const TextStyle(color: neutralTextColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option.details,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGradientStart.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Activity Factor: ${option.multiplier}x',
                        style: TextStyle(
                          color: primaryGradientStart,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
                    // Welcome block
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
                              Icons.local_activity,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'How active are you?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: headerTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your activity level helps us calculate your daily calorie needs more accurately.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: neutralTextColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Activity options list
                    Column(
                      children: activityOptions
                          .map(
                            (o) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildActivityCard(o),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 12),

                    // Info card
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEEF2FF), Color(0x3498DBFF)],
                          // colors: [Color(0xFFEEF2FF), Color(0xFFECF0F1)],
                          // colors: [Color(0xFFEEF2FF), primaryGradientStart],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x3498DBFF)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: const [
                          Text(
                            '💡 How we use this information',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your activity level helps us calculate your Total Daily Energy Expenditure (TDEE) to provide accurate calorie and macro recommendations.',
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
                        onPressed: _selected != null && !_saving
                            ? _saveAndContinue
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
