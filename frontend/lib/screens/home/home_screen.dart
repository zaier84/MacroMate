import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  late Animation<double> _fadeIn;

  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> handleRefresh() async {
    setState(() => isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: Stack(
        children: [
          // ───────────── MAIN SCROLL CONTENT ─────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: RefreshIndicator(
                onRefresh: handleRefresh,
                color: AppColors.brandPrimary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ───────────── HEADER ─────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const AvatarWidget(
                                imageUrl:
                                    "https://avatars.githubusercontent.com/u/100000?v=4",
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome back, Zaier 👋",
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
                              curve: Curves.easeOut,
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
                      const CalorieMacroRing(
                        calories: 1750,
                        goalCalories: 2300,
                        proteinPercent: 20,
                        carbsPercent: 50,
                        fatPercent: 30,
                      ),

                      const SizedBox(height: 24),

                      // ───────────── VITALS CARDS ─────────────
                      const VitalsCards(),

                      const SizedBox(height: 24),

                      // ───────────── TODAY’S DIARY ─────────────
                      const TodaysDiary(),

                      const SizedBox(height: 24),

                      // ───────────── BMI CALCULATOR ─────────────
                      const BmiCalculator(height: 175, weight: 68),

                      const SizedBox(height: 24),

                      // ───────────── QUICK ACCESS ─────────────
                      const QuickAccess(),

                      const SizedBox(height: 80), // space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ───────────── FLOATING ACTION BUTTON (FIXED POSITION) ─────────────
          // Positioned(
          //   bottom: 24,
          //   right: 10,
          //   child: FadeTransition(
          //     opacity: _fadeIn,
          //     child: const FloatingActionButtonMenu(),
          //   ),
          // ),
        ],
      ),
    );
  }
}
