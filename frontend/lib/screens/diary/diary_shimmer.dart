import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DiaryShimmer extends StatelessWidget {
  const DiaryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
        children: [
          _dateSelectorShimmer(),
          const SizedBox(height: 12),

          _sectionHeader(),
          _mealCard(),
          _mealCard(),
          _mealCard(),

          const SizedBox(height: 16),
          _sectionHeader(),
          _simpleTile(),

          const SizedBox(height: 16),
          _sectionHeader(),
          _simpleTile(),
        ],
      ),
    );
  }

  Widget _dateSelectorShimmer() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _sectionHeader() {
    return Container(
      height: 22,
      width: 120,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _mealCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _simpleTile() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}
