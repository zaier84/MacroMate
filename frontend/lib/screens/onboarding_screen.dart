import 'package:flutter/material.dart';
import 'package:onboarding/screens/onboarding_screens/activity_level_screen.dart';
import 'package:onboarding/screens/onboarding_screens/dietary_preferences_screen.dart';
import 'package:onboarding/screens/onboarding_screens/macronutrient_distribution_screen.dart';
import 'package:onboarding/screens/onboarding_screens/meal_preferences_screen.dart';
import 'package:onboarding/screens/onboarding_screens/notifications_screen.dart';
import 'package:onboarding/screens/onboarding_screens/onboarding_summary_screen.dart';
import 'package:onboarding/screens/onboarding_screens/personal_info_screen.dart';
import 'package:onboarding/screens/onboarding_screens/body_metrics_screen.dart';
import 'package:onboarding/screens/onboarding_screens/goal_setting_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  late PageController _pageController;
  int _currentPage = 0;

  late final List<WidgetBuilder> _pages;
  final title = [
    "Personal Information",
    "Body Metrics",
    "Goal Setting",
    "Activity Level",
    "Dietary Preferences",
    "Macro Distribution",
    "Meal Preferences",
    "Set Reminders",
    "Setup Complete!",
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _pages = <WidgetBuilder>[
      (context) => PersonalInfoScreen(onContinue: _goToNext),
      (context) => BodyMetricsScreen(onContinue: _goToNext),
      (context) => GoalSettingScreen(onContinue: _goToNext),
      (context) => ActivityLevelScreen(onContinue: _goToNext),
      (context) => DietaryPreferencesScreen(onContinue: _goToNext),
      (context) => MacronutrientDistributionScreen(onContinue: _goToNext),
      (context) => MealPreferencesScreen(onContinue: _goToNext),
      (context) => NotificationsScreen(onContinue: _goToNext),
      (context) => const OnboardingSummaryScreen(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _goToNext() {
    if (_isLastPage) {
      _finishOnboarding();
      return;
    }

    _pageController.animateToPage(
      _currentPage + 1,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {}

  @override
  Widget build(BuildContext context) {
    final progress = (_currentPage + 1) / _pages.length;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_currentPage != _pages.length - 1)
                      IconButton(
                        onPressed: _goToPrevious,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF374151),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔹 Title
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 100),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: Text(
                              title[_currentPage],
                              key: ValueKey(_currentPage),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: headerTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 🔹 Gradient Progress Bar
                          SizedBox(
                            width: 120,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: progress),
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                builder: (context, value, _) {
                                  return Stack(
                                    children: [
                                      // Background
                                      Container(color: const Color(0xFFF3F4F6)),
                                      // Foreground (gradient)
                                      FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: value,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primaryGradientStart,
                                                primaryGradientEnd,
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),

            Expanded(
              child: PageView.builder(
                physics: const NeverScrollableScrollPhysics(),
                controller: _pageController,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  return _pages[i](context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
