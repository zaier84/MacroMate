import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProgressSkeleton extends StatelessWidget {
  const ProgressSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _bar(width: 160, height: 20),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_card(), _card()],
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_card(), _card()],
            ),
            const SizedBox(height: 30),

            _bar(width: double.infinity, height: 260),
          ],
        ),
      ),
    );
  }

  Widget _card() => Container(
    width: 160,
    height: 80,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
  );

  Widget _bar({required double width, required double height}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
  );
}
