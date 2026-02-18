import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class VitalsCards extends StatelessWidget {
  final Map<String, dynamic> vitals;

  const VitalsCards({super.key, required this.vitals});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).colorScheme.surface.withOpacity(0.9);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;

    final water = vitals["water"];
    final steps = vitals["steps"];
    final weight = vitals["weight"];

    final List<Map<String, dynamic>> items = [
      {
        'icon': FontAwesomeIcons.weightScale,
        'label': 'Weight',
        'value': weightValue(weight),
        'color': Colors.orangeAccent,
      },
      {
        'icon': FontAwesomeIcons.droplet,
        'label': 'Water',
        'value': waterValue(water),
        'color': Colors.blueAccent,
      },
      {
        'icon': FontAwesomeIcons.personWalking,
        'label': 'Steps',
        'value': stepsValue(steps),
        'color': Colors.greenAccent,
      },
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: accent.withOpacity(0.08),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item['label'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['value'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────── HELPERS ─────────────────

  String weightValue(Map<String, dynamic>? weight) {
    if (weight == null || weight["value"] == null) return "—";
    return "${weight["value"]} ${weight["unit"]}";
  }

  String waterValue(Map<String, dynamic>? water) {
    if (water == null) return "—";
    return "${water["consumed"]}/${water["goal"]} ${water["unit"]}";
  }

  String stepsValue(Map<String, dynamic>? steps) {
    if (steps == null || steps["count"] == null) return "—";
    return "${steps["count"]}";
  }
}
