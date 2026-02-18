import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:onboarding/screens/home/home_shimmer.dart';

import '../../services/api_service.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../home/widgets/calorie_macro_ring.dart';
import '../home/widgets/vitals_cards.dart';
import '../home/widgets/todays_diary.dart';
import '../home/widgets/bmi_calculator.dart';
import '../home/widgets/quick_access.dart';
import '../home/widgets/avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // late Animation<double> _fadeIn;

  final ApiService _apiService = ApiService();

  bool isRefreshing = false;
  bool isLoading = true;
  String? error;

  Map<String, dynamic>? homeData;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    // _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _loadHome();
  }

  Future<void> _loadHome() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await _apiService.get("/api/dashboard/home");

      if (response.statusCode != 200) {
        throw Exception("Failed to load home data");
      }

      homeData = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(response.body);

      _controller.forward();
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> handleRefresh() async {
    setState(() => isRefreshing = true);
    await _loadHome();
    setState(() => isRefreshing = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ───────────── LOADING ─────────────
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.neutral50,
        body: SafeArea(child: HomeShimmer()),
      );
    }

    // ───────────── ERROR ─────────────
    if (error != null) {
      return Scaffold(
        backgroundColor: AppColors.neutral50,
        body: Center(
          child: Text(
            "Failed to load home\n$error",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final user = homeData!["user"];
    final nutrition = homeData!["nutrition"];
    final vitals = homeData!["vitals"];
    final diary = homeData!["todaysDiary"];
    final bodyMetrics = homeData!["bodyMetrics"];
    final quickAccess = homeData!["quickAccess"];

    final macroConsumed = nutrition["macroConsumed"];
    final macroRemaining = nutrition["macroRemaining"];

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        // child: FadeTransition(
        // opacity: _fadeIn,
        child: RefreshIndicator(
          onRefresh: handleRefresh,
          color: AppColors.brandPrimary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───────────── HEADER ─────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AvatarWidget(imageUrl: user["avatarUrl"]),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back, ${user["name"]} 👋",
                              style: AppTextStyles.subtitle.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Let’s crush your goals today!",
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: handleRefresh,
                      child: AnimatedRotation(
                        turns: isRefreshing ? 1 : 0,
                        duration: const Duration(seconds: 1),
                        child: const Icon(
                          FontAwesomeIcons.arrowsRotate,
                          color: AppColors.brandPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ───────────── CALORIE & MACRO RING ─────────────
                // CalorieMacroRing(
                //   calories: nutrition["caloriesConsumed"],
                //   goalCalories: nutrition["calorieGoal"],
                //   proteinPercent: nutrition["macros"]["proteinPercent"],
                //   carbsPercent: nutrition["macros"]["carbsPercent"],
                //   fatPercent: nutrition["macros"]["fatPercent"],
                // ),

                CalorieMacroRing(
                  calories: nutrition["caloriesConsumed"],
                  goalCalories: nutrition["calorieGoal"],

                  proteinConsumed: (macroConsumed["proteinG"] as num)
                      .toDouble(),
                  carbsConsumed: (macroConsumed["carbsG"] as num).toDouble(),
                  fatConsumed: (macroConsumed["fatG"] as num).toDouble(),

                  proteinRemaining: (macroRemaining["proteinG"] as num)
                      .toDouble(),
                  carbsRemaining: (macroRemaining["carbsG"] as num).toDouble(),
                  fatRemaining: (macroRemaining["fatG"] as num).toDouble(),
                ),

                const SizedBox(height: 24),

                // ───────────── VITALS ─────────────
                VitalsCards(vitals: vitals),

                const SizedBox(height: 24),

                // ───────────── TODAY’S DIARY ─────────────
                TodaysDiary(diary: diary),

                const SizedBox(height: 24),

                // ───────────── BMI ─────────────
                BmiCalculator(
                  height: (bodyMetrics["heightCm"] as num).toDouble(),
                  weight: (65 as num).toDouble(),
                  // weight: (bodyMetrics["weightKg"] as num).toDouble(),
                ),

                // const SizedBox(height: 24),

                // ───────────── QUICK ACCESS ─────────────
                // QuickAccess(config: quickAccess),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        // ),
      ),
    );
  }
}
