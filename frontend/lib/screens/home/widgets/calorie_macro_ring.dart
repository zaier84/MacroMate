import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/text_styles.dart';

class CalorieMacroRing extends StatelessWidget {
  final int calories;
  final int goalCalories;

  final double proteinConsumed;
  final double carbsConsumed;
  final double fatConsumed;

  final double proteinRemaining;
  final double carbsRemaining;
  final double fatRemaining;

  const CalorieMacroRing({
    super.key,
    required this.calories,
    required this.goalCalories,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
    required this.proteinRemaining,
    required this.carbsRemaining,
    required this.fatRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final safeGoal = goalCalories <= 0 ? 1 : goalCalories;
    final targetCalories = goalCalories;
    final consumedCalories = calories;
    final remainingCalories = max(targetCalories - consumedCalories, 0);

    return GestureDetector(
      onTap: () => _showMacroBreakdown(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // ───────────── CALORIE RING ─────────────
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: (consumedCalories / safeGoal).clamp(0.0, 1.0),
              ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        painter: _CalorieRingPainter(progress),
                        child: const SizedBox.expand(),
                      ),
                      // Column(
                      //   mainAxisSize: MainAxisSize.min,
                      //   children: [
                      //     Text(
                      //       "$remainingCalories kcal",
                      //       style: AppTextStyles.heading.copyWith(
                      //         fontSize: 20,
                      //         fontWeight: FontWeight.bold,
                      //       ),
                      //     ),
                      //     const SizedBox(height: 4),
                      //     Text(
                      //       "remaining",
                      //       style: AppTextStyles.caption.copyWith(
                      //         color: AppColors.textSecondary,
                      //       ),
                      //     ),
                      //     const SizedBox(height: 4),
                      //     Text(
                      //       "${(progress * 100).toStringAsFixed(0)}%",
                      //       style: AppTextStyles.caption.copyWith(
                      //         color: AppColors.brandPrimary,
                      //         fontWeight: FontWeight.w600,
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$remainingCalories kcal",
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "remaining",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "of $targetCalories kcal",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // const SizedBox(height: 4),
                          // Text(
                          //   "${consumedCalories} kcal consumed",
                          //   style: AppTextStyles.caption.copyWith(
                          //     color: AppColors.brandPrimary,
                          //     fontWeight: FontWeight.w600,
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ───────────── MACROS ─────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MacroIndicator(
                  label: "Protein",
                  consumed: proteinConsumed,
                  remaining: proteinRemaining,
                  color: Colors.redAccent,
                ),
                _MacroIndicator(
                  label: "Carbs",
                  consumed: carbsConsumed,
                  remaining: carbsRemaining,
                  color: Colors.blueAccent,
                ),
                _MacroIndicator(
                  label: "Fat",
                  consumed: fatConsumed,
                  remaining: fatRemaining,
                  color: Colors.orangeAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Macro breakdown bottom sheet
  // ─────────────────────────────────────────────
  void _showMacroBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                "Macro Breakdown",
                style: AppTextStyles.heading.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 16),

              _macroRow(
                "Protein",
                proteinConsumed,
                proteinRemaining,
                Colors.red,
              ),
              _macroRow("Carbs", carbsConsumed, carbsRemaining, Colors.blue),
              _macroRow("Fat", fatConsumed, fatRemaining, Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _macroRow(
    String label,
    double consumed,
    double remaining,
    Color color,
  ) {
    final total = consumed + remaining;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.subtitle),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${consumed.toStringAsFixed(1)} g consumed",
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text(
                "${remaining.toStringAsFixed(1)} g remaining",
                style: AppTextStyles.caption,
              ),
              Text(
                "Target ${total.toStringAsFixed(0)} g",
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Ring painter
// ─────────────────────────────────────────────
class _CalorieRingPainter extends CustomPainter {
  final double progress;

  _CalorieRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final radius = (min(size.width, size.height) / 2) - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final bgPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        AppColors.primaryGradientStart,
        AppColors.primaryGradientEnd,
      ],
    );

    final fgPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_CalorieRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────
// Macro bar (animated)
// ─────────────────────────────────────────────
class _MacroIndicator extends StatelessWidget {
  final String label;
  final double consumed;
  final double remaining;
  final Color color;

  const _MacroIndicator({
    required this.label,
    required this.consumed,
    required this.remaining,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final total = consumed + remaining;
    final progress = total <= 0 ? 0.0 : consumed / total;

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  width: 80,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: value * 80,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.9), color],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          // "${consumed.toStringAsFixed(0)} g",
          "${consumed.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} g",
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// import 'dart:math';
// import 'package:flutter/material.dart';
// import '../../../theme/colors.dart';
// import '../../../theme/text_styles.dart';
//
// class CalorieMacroRing extends StatelessWidget {
//   final int calories;
//   final int goalCalories;
//
//   final double proteinConsumed;
//   final double carbsConsumed;
//   final double fatConsumed;
//
//   final double proteinRemaining;
//   final double carbsRemaining;
//   final double fatRemaining;
//
//   const CalorieMacroRing({
//     super.key,
//     required this.calories,
//     required this.goalCalories,
//     required this.proteinConsumed,
//     required this.carbsConsumed,
//     required this.fatConsumed,
//     required this.proteinRemaining,
//     required this.carbsRemaining,
//     required this.fatRemaining,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final safeGoal = goalCalories <= 0 ? 1 : goalCalories;
//     final progress = (calories / safeGoal).clamp(0.0, 1.0);
//     final remainingCalories = max(goalCalories - calories, 0);
//     final percentage = (progress * 100).toStringAsFixed(0);
//
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.03),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // ───────────── CALORIE RING ─────────────
//           SizedBox(
//             width: 150,
//             height: 150,
//             child: Stack(
//               alignment: Alignment.center,
//               children: [
//                 CustomPaint(
//                   painter: _CalorieRingPainter(progress),
//                   child: const SizedBox.expand(),
//                 ),
//                 Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       "$remainingCalories kcal",
//                       style: AppTextStyles.heading.copyWith(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       "remaining",
//                       style: AppTextStyles.caption.copyWith(
//                         color: AppColors.textSecondary,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       "$percentage%",
//                       style: AppTextStyles.caption.copyWith(
//                         color: AppColors.brandPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 24),
//
//           // ───────────── MACROS (GRAMS) ─────────────
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               _MacroIndicator(
//                 label: "Protein",
//                 consumed: proteinConsumed,
//                 remaining: proteinRemaining,
//                 color: Colors.redAccent,
//               ),
//               _MacroIndicator(
//                 label: "Carbs",
//                 consumed: carbsConsumed,
//                 remaining: carbsRemaining,
//                 color: Colors.blueAccent,
//               ),
//               _MacroIndicator(
//                 label: "Fat",
//                 consumed: fatConsumed,
//                 remaining: fatRemaining,
//                 color: Colors.orangeAccent,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // Circular calorie ring painter
// // ─────────────────────────────────────────────
// class _CalorieRingPainter extends CustomPainter {
//   final double progress;
//
//   _CalorieRingPainter(this.progress);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final strokeWidth = 14.0;
//     final radius = (min(size.width, size.height) / 2) - strokeWidth / 2;
//     final center = Offset(size.width / 2, size.height / 2);
//
//     final bgPaint = Paint()
//       ..color = const Color(0xFFE5E7EB)
//       ..strokeWidth = strokeWidth
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//
//     canvas.drawCircle(center, radius, bgPaint);
//
//     if (progress <= 0) return;
//
//     final sweepAngle = 2 * pi * progress;
//     const startAngle = -pi / 2;
//
//     final gradient = SweepGradient(
//       startAngle: startAngle,
//       endAngle: startAngle + sweepAngle,
//       colors: const [
//         AppColors.primaryGradientStart,
//         AppColors.primaryGradientEnd,
//       ],
//     );
//
//     final fgPaint = Paint()
//       ..shader = gradient.createShader(
//         Rect.fromCircle(center: center, radius: radius),
//       )
//       ..strokeWidth = strokeWidth
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//
//     canvas.drawArc(
//       Rect.fromCircle(center: center, radius: radius),
//       startAngle,
//       sweepAngle,
//       false,
//       fgPaint,
//     );
//   }
//
//   @override
//   bool shouldRepaint(_CalorieRingPainter oldDelegate) =>
//       oldDelegate.progress != progress;
// }
//
// // ─────────────────────────────────────────────
// // Macro indicator (grams based)
// // ─────────────────────────────────────────────
// class _MacroIndicator extends StatelessWidget {
//   final String label;
//   final double consumed;
//   final double remaining;
//   final Color color;
//
//   const _MacroIndicator({
//     required this.label,
//     required this.consumed,
//     required this.remaining,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final total = consumed + remaining;
//     final progress = total <= 0 ? 0.0 : (consumed / total).clamp(0.0, 1.0);
//
//     return Column(
//       children: [
//         Stack(
//           alignment: Alignment.centerLeft,
//           children: [
//             Container(
//               width: 80,
//               height: 8,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade200,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//             ),
//             AnimatedContainer(
//               duration: const Duration(milliseconds: 500),
//               curve: Curves.easeInOut,
//               width: progress * 80,
//               height: 8,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [color.withOpacity(0.9), color],
//                 ),
//                 borderRadius: BorderRadius.circular(4),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 6),
//         Text(
//           "${consumed.toStringAsFixed(0)}g / ${total.toStringAsFixed(0)}g",
//           style: AppTextStyles.caption.copyWith(
//             color: color,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Text(
//           label,
//           style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
//         ),
//       ],
//     );
//   }
// }
