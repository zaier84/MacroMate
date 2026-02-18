import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
// import '../../theme/colors.dart';

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  Widget _box({
    required double height,
    double width = double.infinity,
    BorderRadius? radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius ?? BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────── HEADER ─────────
            Row(
              children: [
                _box(height: 44, width: 44, radius: BorderRadius.circular(22)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(height: 14, width: 160),
                    const SizedBox(height: 6),
                    _box(height: 12, width: 120),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ───────── CALORIE RING ─────────
            Center(
              child: _box(
                height: 180,
                width: 180,
                radius: BorderRadius.circular(90),
              ),
            ),

            const SizedBox(height: 24),

            // ───────── VITALS CARDS ─────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _box(height: 90, width: 100),
                _box(height: 90, width: 100),
                _box(height: 90, width: 100),
              ],
            ),

            const SizedBox(height: 24),

            // ───────── TODAY'S DIARY ─────────
            _box(height: 140),

            const SizedBox(height: 24),

            // ───────── BMI CARD ─────────
            _box(height: 160),

            const SizedBox(height: 24),

            // ───────── QUICK ACCESS ─────────
            Row(
              children: [
                _box(height: 60, width: 140),
                const SizedBox(width: 12),
                _box(height: 60, width: 140),
              ],
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
