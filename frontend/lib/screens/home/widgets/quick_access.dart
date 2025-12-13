import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class QuickAccess extends StatelessWidget {
  const QuickAccess({super.key});

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      {
        'id': 'cheat-meal-balance',
        'title': 'Cheat Meal Balance',
        'description': 'Balance your calories smartly',
        'icon': FontAwesomeIcons.wandMagicSparkles,
        'color': const Color(0xFFF6A63A), // warning color
        'bgColor': const Color(0xFFFFF5E6),
        'borderColor': const Color(0xFFF6A63A).withOpacity(0.2),
      },
      {
        'id': 'ai-insights',
        'title': 'AI Insights',
        'description': 'View health patterns',
        'icon': FontAwesomeIcons.arrowTrendUp,
        'color': const Color(0xFF7C3AED), // brand primary
        'bgColor': const Color(0xFFF3E8FF),
        'borderColor': const Color(0xFF7C3AED).withOpacity(0.2),
      },
      {
        'id': 'workout-planner',
        'title': 'Workout Planner',
        'description': 'Generate AI workout',
        'icon': FontAwesomeIcons.bolt,
        'color': const Color(0xFF22C55E), // success green
        'bgColor': const Color(0xFFE9FCEB),
        'borderColor': const Color(0xFF22C55E).withOpacity(0.2),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Access",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return GestureDetector(
                onTap: () {
                  // Replace with your route navigation logic
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: action['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: action['borderColor'] as Color,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        color: action['color'] as Color,
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action['title'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: action['color'] as Color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action['description'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
