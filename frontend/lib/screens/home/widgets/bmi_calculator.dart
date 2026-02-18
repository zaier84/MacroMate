import 'package:flutter/material.dart';
import 'dart:math' as math;

class BmiCalculator extends StatelessWidget {
  final double height; // in cm
  final double weight; // in kg

  const BmiCalculator({super.key, required this.height, required this.weight});

  double get bmi => weight / ((height / 100) * (height / 100));

  String get bmiCategory {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 24.9) return "Normal";
    if (bmi < 29.9) return "Overweight";
    return "Obese";
  }

  double get bmiProgress {
    // Map BMI range (10–35) into [0, 1] for the ring progress
    return ((bmi - 10) / (35 - 10)).clamp(0.0, 1.0);
  }

  Color get categoryColor {
    if (bmi < 18.5) return Colors.blueAccent.shade100;
    if (bmi < 24.9) return Colors.greenAccent.shade400;
    if (bmi < 29.9) return Colors.orangeAccent.shade200;
    return Colors.redAccent.shade200;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              "BMI Calculator",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // BMI Value + Ring
            Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background ring (neutral)
                      CustomPaint(
                        size: const Size(90, 90),
                        painter: _RingPainter(
                          progress: 1,
                          color: Colors.grey.shade200,
                        ),
                      ),
                      // Gradient ring (progress)
                      CustomPaint(
                        size: const Size(90, 90),
                        painter: _RingPainter(
                          progress: bmiProgress,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // BMI Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            bmi.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "BMI",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bmiCategory,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: categoryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Height: ${height.toStringAsFixed(0)} cm",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        "Weight: ${weight.toStringAsFixed(1)} kg",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200, thickness: 1),

            const SizedBox(height: 12),
            Text(
              "A Body Mass Index (BMI) between 18.5 and 24.9 is considered healthy. "
              "Maintain your balance through proper diet and exercise.",
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Gradient? gradient;
  final Color? color;

  _RingPainter({required this.progress, this.gradient, this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final rect = Offset.zero & size;
    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = color ?? Colors.grey.shade300;
    }

    canvas.drawArc(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.gradient != gradient;
  }
}
