import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TodaysDiary extends StatelessWidget {
  const TodaysDiary({super.key});

  @override
  Widget build(BuildContext context) {
    final diaryEntries = [
      DiaryEntry(
        id: "1",
        type: DiaryType.meal,
        time: "8:30 AM",
        title: "Breakfast",
        subtitle: "Oatmeal with berries",
        calories: 320,
        icon: FontAwesomeIcons.coffee,
      ),
      DiaryEntry(
        id: "2",
        type: DiaryType.meal,
        time: "1:15 PM",
        title: "Lunch",
        subtitle: "Grilled chicken salad",
        calories: 450,
        icon: FontAwesomeIcons.utensils,
      ),
      DiaryEntry(
        id: "3",
        type: DiaryType.meal,
        time: "3:45 PM",
        title: "Snack",
        subtitle: "Apple with almond butter",
        calories: 180,
        icon: FontAwesomeIcons.apple,
      ),
      DiaryEntry(
        id: "4",
        type: DiaryType.workout,
        time: "6:00 PM",
        title: "Upper Body Workout",
        subtitle: "45 min • Chest & Arms",
        calories: 280,
        icon: FontAwesomeIcons.dumbbell,
      ),
    ];

    final hasEntries = diaryEntries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Diary",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827), // text-primary
                ),
              ),
              if (hasEntries)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 20),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {},
                  child: const Text(
                    "View All",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4F46E5), // brand-primary
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Container background
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA), // neutral-50
            borderRadius: BorderRadius.circular(16),
          ),
          child: hasEntries
              ? Column(
                  children: [
                    for (final entry in diaryEntries) ...[
                      DiaryEntryCard(entry: entry),
                      if (entry != diaryEntries.last) const SizedBox(height: 8),
                    ],
                  ],
                )
              : const EmptyState(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Diary Entry Model
// ─────────────────────────────────────────────
enum DiaryType { meal, workout, weight, water }

class DiaryEntry {
  final String id;
  final DiaryType type;
  final String time;
  final String title;
  final String? subtitle;
  final int? calories;
  final IconData icon;

  DiaryEntry({
    required this.id,
    required this.type,
    required this.time,
    required this.title,
    this.subtitle,
    this.calories,
    required this.icon,
  });
}

// ─────────────────────────────────────────────
// Diary Entry Card
// ─────────────────────────────────────────────
class DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  const DiaryEntryCard({super.key, required this.entry});

  Color _typeColor(DiaryType type) {
    switch (type) {
      case DiaryType.meal:
        return const Color(0xFF4F46E5); // brand-primary
      case DiaryType.workout:
        return const Color(0xFF16A34A); // success
      case DiaryType.weight:
        return const Color(0xFFFACC15); // warning
      case DiaryType.water:
        return const Color(0xFF9333EA); // brand-secondary
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF5F5F5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon Circle
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, color: _typeColor(entry.type), size: 20),
          ),
          const SizedBox(width: 12),

          // Text Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827), // text-primary
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.time,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280), // neutral-500
                      ),
                    ),
                  ],
                ),
                if (entry.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF525252), // neutral-600
                    ),
                  ),
                ],
                if (entry.calories != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "${entry.calories} calories",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF), // neutral-500
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              FontAwesomeIcons.utensils,
              color: Color(0xFF9CA3AF),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No entries yet today",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Start logging your meals, workouts, and other activities to track your progress.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(FontAwesomeIcons.plus, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  "Add Entry",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
