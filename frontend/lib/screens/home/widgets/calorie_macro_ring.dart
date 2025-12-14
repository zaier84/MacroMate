import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../theme/text_styles.dart';

class CalorieMacroRing extends StatelessWidget {
  final int calories;
  final int goalCalories;
  final int proteinPercent;
  final int carbsPercent;
  final int fatPercent;

  const CalorieMacroRing({
    super.key,
    required this.calories,
    required this.goalCalories,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (calories / goalCalories).clamp(0.0, 1.0);
    final remaining = max(goalCalories - calories, 0);
    final percentage = (progress * 100).toStringAsFixed(0);

    return Container(
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
          // ───────────── CIRCULAR RING ─────────────
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  painter: _CalorieRingPainter(progress),
                  child: const SizedBox.expand(),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$remaining kcal",
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "remaining",
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$percentage%",
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ───────────── MACRO BARS ─────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MacroIndicator(
                label: "Protein",
                percent: proteinPercent,
                color: Colors.redAccent,
              ),
              _MacroIndicator(
                label: "Carbs",
                percent: carbsPercent,
                color: Colors.blueAccent,
              ),
              _MacroIndicator(
                label: "Fat",
                percent: fatPercent,
                color: Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Custom painter for the circular calorie ring
// ─────────────────────────────────────────────
class _CalorieRingPainter extends CustomPainter {
  final double progress;

  _CalorieRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final minSide = min(size.width, size.height);
    final radius = (minSide / 2) - strokeWidth / 2;

    final center = Offset(size.width / 2, size.height / 2);
    final backgroundPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // start angle at top (same as your TSX - rotated -90deg)
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    // Make gradient cover exactly the arc we will draw.
    // Use startAngle and endAngle to avoid the gradient wrapping around the unused part.
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      tileMode: TileMode.clamp,
      colors: const [
        // Color(0xFF36C9B0), // teal-ish (matches "#36C9B0")
        // Color(0xFF2FA4FF), // blue (matches "#2FA4FF")
        AppColors.primaryGradientStart,
        AppColors.primaryGradientEnd,
      ],
      stops: const [0.0, 1.0],
    );

    final foregroundPaint = Paint()
      ..shader = gradient.createShader(
        // shader rect should be centered and use radius to cover the arc correctly
        Rect.fromCircle(center: center, radius: radius + strokeWidth / 2),
      )
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // draw background circle
    canvas.drawCircle(center, radius, backgroundPaint);

    // draw arc with shader paint
    // IMPORTANT: drawArc will only render the portion (sweepAngle) and since our gradient is
    // constrained with startAngle/endAngle & TileMode.clamp, the gradient will map uniformly
    // along the drawn arc.
    if (sweepAngle > 0.0001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        foregroundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CalorieRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─────────────────────────────────────────────
// Macro indicator bar (Protein / Carbs / Fat)
// ─────────────────────────────────────────────
class _MacroIndicator extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const _MacroIndicator({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              width: (percent / 100) * 80,
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.9), color],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "$percent%",
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
