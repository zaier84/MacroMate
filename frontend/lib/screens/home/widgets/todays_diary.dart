import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TodaysDiary extends StatelessWidget {
  final Map<String, dynamic> diary;

  const TodaysDiary({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    final List meals = diary["meals"] ?? [];

    final List<DiaryEntry> diaryEntries = meals.map<DiaryEntry>((meal) {
      return DiaryEntry(
        id: meal["id"],
        type: DiaryType.meal,
        time: _formatTime(meal["time"]),
        title: meal["type"],
        subtitle: null,
        calories: meal["calories"],
        icon: _mealIcon(meal["type"]),
      );
    }).toList();

    final hasEntries = diaryEntries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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
                  color: Color(0xFF111827),
                ),
              ),
              if (hasEntries)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 20),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "View All",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Content
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: hasEntries
              ? Column(
                  children: [
                    for (final entry in diaryEntries) ...[
                      DiaryEntryCard(entry: entry),
                      if (entry != diaryEntries.last)
                        const SizedBox(height: 8),
                    ],
                  ],
                )
              : const EmptyState(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  String _formatTime(String? time) {
    if (time == null || time == "00:00") return "";
    return time;
  }

  IconData _mealIcon(String type) {
    switch (type.toLowerCase()) {
      case "breakfast":
        return FontAwesomeIcons.coffee;
      case "lunch":
        return FontAwesomeIcons.utensils;
      case "dinner":
        return FontAwesomeIcons.bowlFood;
      case "snack":
        return FontAwesomeIcons.apple;
      default:
        return FontAwesomeIcons.utensils;
    }
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
        return const Color(0xFF4F46E5);
      case DiaryType.workout:
        return const Color(0xFF16A34A);
      case DiaryType.weight:
        return const Color(0xFFFACC15);
      case DiaryType.water:
        return const Color(0xFF9333EA);
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      entry.time,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                if (entry.calories != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "${entry.calories} calories",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
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
            "Start logging your meals to track your nutrition.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
