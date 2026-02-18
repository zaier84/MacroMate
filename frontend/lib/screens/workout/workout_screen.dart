import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final ApiService _api = ApiService();

  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  bool isSaving = false;
  bool hasUnsavedChanges = false;

  List<EditableExercise> exercises = [];

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  /* ───────────────────────── LOAD ───────────────────────── */

  Future<void> _loadWorkout() async {
    setState(() => isLoading = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    try {
      final res = await _api.get(
        '/api/workouts/sessions/by-date?date=$dateStr',
      );

      final body = jsonDecode(res.body);
      final List list = body['exercises'] ?? [];

      exercises = list.map((e) => EditableExercise.fromJson(e)).toList();
      hasUnsavedChanges = false;
    } catch (e) {
      debugPrint(e.toString());
    }

    setState(() => isLoading = false);
  }

  /* ───────────────────────── SAVE ───────────────────────── */

  Future<void> _saveWorkout() async {
    if (!_isValid()) {
      _showError('Each exercise must have at least one valid set.');
      return;
    }

    setState(() => isSaving = true);

    final payload = {
      "date": DateFormat('yyyy-MM-dd').format(selectedDate),
      "exercises": exercises.map((e) => e.toJson()).toList(),
    };

    try {
      await _api.post('/api/workouts/by-date', jsonEncode(payload));
      hasUnsavedChanges = false;
    } catch (_) {
      _showError('Failed to save workout');
    }

    setState(() => isSaving = false);
  }

  bool _isValid() {
    if (exercises.isEmpty) return false;
    for (final e in exercises) {
      if (e.nameController.text.trim().isEmpty) return false;
      if (e.sets.isEmpty) return false;
      for (final s in e.sets) {
        if (s.reps <= 0 || s.weight < 0) return false;
      }
    }
    return true;
  }

  /* ───────────────────────── UI ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!hasUnsavedChanges) return true;
        return await _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: Text(
            'Workout',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          actions: [
            TextButton(
              onPressed: hasUnsavedChanges && !isSaving ? _saveWorkout : null,
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: AppTextStyles.subtitle.copyWith(
                        color: hasUnsavedChanges
                            ? AppColors.brandPrimary
                            : AppColors.neutral600,
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.brandPrimary,
          onPressed: _addExercise,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add Exercise',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Column(
          children: [
            _dateSelector(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : exercises.isEmpty
                  ? const Center(
                      child: Text(
                        'No workout logged',
                        style: TextStyle(color: AppColors.neutral600),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: exercises.length,
                      itemBuilder: (_, i) => _exerciseCard(exercises[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /* ───────────────────────── DATE SELECTOR ───────────────────────── */

  Widget _dateSelector() {
    final today = DateTime.now();
    final isToday = DateUtils.isSameDay(selectedDate, today);

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.brandPrimary),
            onPressed: () async {
              if (hasUnsavedChanges && !await _confirmDiscard()) return;
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
              _loadWorkout();
            },
          ),
          Text(
            DateFormat('EEE, MMM d, yyyy').format(selectedDate),
            style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: isToday ? AppColors.neutral600 : AppColors.brandPrimary,
            ),
            onPressed: isToday
                ? null
                : () async {
                    if (hasUnsavedChanges && !await _confirmDiscard()) return;
                    setState(() {
                      selectedDate = selectedDate.add(const Duration(days: 1));
                    });
                    _loadWorkout();
                  },
          ),
        ],
      ),
    );
  }

  /* ───────────────────────── EXERCISES ───────────────────────── */

  void _addExercise() {
    setState(() {
      exercises.add(EditableExercise.empty());
      hasUnsavedChanges = true;
    });
  }

  Widget _exerciseCard(EditableExercise e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: e.nameController,
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              border: InputBorder.none,
              isDense: true,
            ),
            style: AppTextStyles.subtitle,
            onChanged: (_) => hasUnsavedChanges = true,
          ),
          const SizedBox(height: 12),
          Column(
            children: e.sets
                .asMap()
                .entries
                .map((entry) => _setRow(e, entry.key))
                .toList(),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                e.sets.add(EditableSet.empty());
                hasUnsavedChanges = true;
              });
            },
            icon: const Icon(Icons.add, color: AppColors.brandPrimary),
            label: const Text(
              'Add Set',
              style: TextStyle(color: AppColors.brandPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setRow(EditableExercise e, int index) {
    final s = e.sets[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: s.weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                s.weight = double.tryParse(v) ?? 0;
                hasUnsavedChanges = true;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: s.repsController,
              decoration: const InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                s.reps = int.tryParse(v) ?? 0;
                hasUnsavedChanges = true;
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent),
            onPressed: () {
              setState(() {
                e.sets.removeAt(index);
                hasUnsavedChanges = true;
              });
            },
          ),
        ],
      ),
    );
  }

  /* ───────────────────────── HELPERS ───────────────────────── */

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Unsaved changes'),
            content: const Text('Discard changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ───────────────────────── MODELS ───────────────────────── */

class EditableExercise {
  final TextEditingController nameController;
  final List<EditableSet> sets;

  EditableExercise({required this.nameController, required this.sets});

  factory EditableExercise.empty() =>
      EditableExercise(nameController: TextEditingController(), sets: []);

  factory EditableExercise.fromJson(Map<String, dynamic> json) {
    return EditableExercise(
      nameController: TextEditingController(text: json['exercise_name'] ?? ''),
      sets: (json['sets'] as List).map((s) => EditableSet.fromJson(s)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    "exercise_name": nameController.text.trim(),
    "sets": sets.map((s) => s.toJson()).toList(),
  };
}

class EditableSet {
  double weight;
  int reps;

  final TextEditingController weightController;
  final TextEditingController repsController;

  EditableSet({
    required this.weight,
    required this.reps,
    required this.weightController,
    required this.repsController,
  });

  factory EditableSet.empty() => EditableSet(
    weight: 0,
    reps: 0,
    weightController: TextEditingController(),
    repsController: TextEditingController(),
  );

  factory EditableSet.fromJson(Map<String, dynamic> json) {
    final w = (json['weight_kg'] ?? 0).toDouble();
    final r = json['reps'] ?? 0;

    return EditableSet(
      weight: w,
      reps: r,
      weightController: TextEditingController(text: w.toString()),
      repsController: TextEditingController(text: r.toString()),
    );
  }

  Map<String, dynamic> toJson() => {"weight_kg": weight, "reps": reps};
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
//
// import '../../services/api_service.dart';
//
// class WorkoutScreen extends StatefulWidget {
//   const WorkoutScreen({super.key});
//
//   @override
//   State<WorkoutScreen> createState() => _WorkoutScreenState();
// }
//
// class _WorkoutScreenState extends State<WorkoutScreen> {
//   final ApiService _api = ApiService();
//
//   DateTime selectedDate = DateTime.now();
//   bool isLoading = true;
//   bool isSaving = false;
//   bool hasUnsavedChanges = false;
//
//   List<EditableExercise> exercises = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadWorkout();
//   }
//
//   /* ───────────────────────── LOAD ───────────────────────── */
//
//   Future<void> _loadWorkout() async {
//     setState(() => isLoading = true);
//
//     final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
//
//     try {
//       final res = await _api.get(
//         '/api/workouts/sessions/by-date?date=$dateStr',
//       );
//
//       final body = jsonDecode(res.body);
//       final List list = body['exercises'] ?? [];
//
//       exercises = list.map((e) => EditableExercise.fromJson(e)).toList();
//
//       hasUnsavedChanges = false;
//     } catch (e) {
//       debugPrint(e.toString());
//     }
//
//     setState(() => isLoading = false);
//   }
//
//   /* ───────────────────────── SAVE ───────────────────────── */
//
//   Future<void> _saveWorkout() async {
//     if (!_isValid()) {
//       _showError('Each exercise must have at least one valid set.');
//       return;
//     }
//
//     setState(() => isSaving = true);
//
//     final payload = {
//       "date": DateFormat('yyyy-MM-dd').format(selectedDate),
//       "exercises": exercises.map((e) => e.toJson()).toList(),
//     };
//
//     try {
//       await _api.post('/api/workouts/by-date', jsonEncode(payload));
//
//       hasUnsavedChanges = false;
//     } catch (_) {
//       _showError('Failed to save workout');
//     }
//
//     setState(() => isSaving = false);
//   }
//
//   bool _isValid() {
//     if (exercises.isEmpty) return false;
//
//     for (final e in exercises) {
//       if (e.nameController.text.trim().isEmpty) return false;
//       if (e.sets.isEmpty) return false;
//
//       for (final s in e.sets) {
//         if (s.reps <= 0 || s.weight < 0) return false;
//       }
//     }
//     return true;
//   }
//
//   /* ───────────────────────── UI ───────────────────────── */
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         if (!hasUnsavedChanges) return true;
//         return await _confirmDiscard();
//       },
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Workout'),
//           actions: [
//             TextButton(
//               onPressed: hasUnsavedChanges && !isSaving ? _saveWorkout : null,
//               child: isSaving
//                   ? const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     )
//                   : const Text('Save'),
//             ),
//           ],
//         ),
//         floatingActionButton: FloatingActionButton.extended(
//           onPressed: _addExercise,
//           icon: const Icon(Icons.add),
//           label: const Text('Add Exercise'),
//         ),
//         body: Column(
//           children: [
//             _dateSelector(),
//             Expanded(
//               child: isLoading
//                   ? const Center(child: CircularProgressIndicator())
//                   : exercises.isEmpty
//                   ? const Center(child: Text('No workout logged'))
//                   : ListView.builder(
//                       padding: const EdgeInsets.all(12),
//                       itemCount: exercises.length,
//                       itemBuilder: (_, i) => _exerciseCard(exercises[i]),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _dateSelector() {
//     final today = DateTime.now();
//     final isToday = DateUtils.isSameDay(selectedDate, today);
//
//     return Padding(
//       padding: const EdgeInsets.all(12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           IconButton(
//             icon: const Icon(Icons.chevron_left),
//             onPressed: () async {
//               if (hasUnsavedChanges && !await _confirmDiscard()) return;
//               setState(() {
//                 selectedDate = selectedDate.subtract(const Duration(days: 1));
//               });
//               _loadWorkout();
//             },
//           ),
//           Text(
//             DateFormat('EEE, MMM d, yyyy').format(selectedDate),
//             style: const TextStyle(fontWeight: FontWeight.w600),
//           ),
//           IconButton(
//             icon: const Icon(Icons.chevron_right),
//             onPressed: isToday
//                 ? null
//                 : () async {
//                     if (hasUnsavedChanges && !await _confirmDiscard()) return;
//                     setState(() {
//                       selectedDate = selectedDate.add(const Duration(days: 1));
//                     });
//                     _loadWorkout();
//                   },
//           ),
//         ],
//       ),
//     );
//   }
//
//   /* ───────────────────────── EXERCISES ───────────────────────── */
//
//   void _addExercise() {
//     setState(() {
//       exercises.add(EditableExercise.empty());
//       hasUnsavedChanges = true;
//     });
//   }
//
//   Widget _exerciseCard(EditableExercise e) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           children: [
//             TextField(
//               controller: e.nameController,
//               decoration: const InputDecoration(labelText: 'Exercise Name'),
//               onChanged: (_) => hasUnsavedChanges = true,
//             ),
//             const SizedBox(height: 8),
//             Column(
//               children: e.sets
//                   .asMap()
//                   .entries
//                   .map((entry) => _setRow(e, entry.key))
//                   .toList(),
//             ),
//             TextButton.icon(
//               onPressed: () {
//                 setState(() {
//                   e.sets.add(EditableSet.empty());
//                   hasUnsavedChanges = true;
//                 });
//               },
//               icon: const Icon(Icons.add),
//               label: const Text('Add Set'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _setRow(EditableExercise e, int index) {
//     final s = e.sets[index];
//
//     return Row(
//       children: [
//         Expanded(
//           child: TextField(
//             controller: s.weightController,
//             decoration: const InputDecoration(labelText: 'Weight (kg)'),
//             keyboardType: TextInputType.number,
//             onChanged: (v) {
//               s.weight = double.tryParse(v) ?? 0;
//               hasUnsavedChanges = true;
//             },
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: TextField(
//             controller: s.repsController,
//             decoration: const InputDecoration(labelText: 'Reps'),
//             keyboardType: TextInputType.number,
//             onChanged: (v) {
//               s.reps = int.tryParse(v) ?? 0;
//               hasUnsavedChanges = true;
//             },
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.close),
//           onPressed: () {
//             setState(() {
//               e.sets.removeAt(index);
//               hasUnsavedChanges = true;
//             });
//           },
//         ),
//       ],
//     );
//   }
//
//   /* ───────────────────────── HELPERS ───────────────────────── */
//
//   Future<bool> _confirmDiscard() async {
//     return await showDialog<bool>(
//           context: context,
//           builder: (_) => AlertDialog(
//             title: const Text('Unsaved changes'),
//             content: const Text('Discard changes?'),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context, false),
//                 child: const Text('Cancel'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.pop(context, true),
//                 child: const Text('Discard'),
//               ),
//             ],
//           ),
//         ) ??
//         false;
//   }
//
//   void _showError(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
// }
//
// /* ───────────────────────── MODELS ───────────────────────── */
//
// class EditableExercise {
//   final TextEditingController nameController;
//   final List<EditableSet> sets;
//
//   EditableExercise({required this.nameController, required this.sets});
//
//   factory EditableExercise.empty() =>
//       EditableExercise(nameController: TextEditingController(), sets: []);
//
//   factory EditableExercise.fromJson(Map<String, dynamic> json) {
//     return EditableExercise(
//       nameController: TextEditingController(text: json['exercise_name'] ?? ''),
//       sets: (json['sets'] as List).map((s) => EditableSet.fromJson(s)).toList(),
//     );
//   }
//
//   Map<String, dynamic> toJson() => {
//     "exercise_name": nameController.text.trim(),
//     "sets": sets.map((s) => s.toJson()).toList(),
//   };
// }
//
// class EditableSet {
//   double weight;
//   int reps;
//
//   final TextEditingController weightController;
//   final TextEditingController repsController;
//
//   EditableSet({
//     required this.weight,
//     required this.reps,
//     required this.weightController,
//     required this.repsController,
//   });
//
//   factory EditableSet.empty() => EditableSet(
//     weight: 0,
//     reps: 0,
//     weightController: TextEditingController(),
//     repsController: TextEditingController(),
//   );
//
//   factory EditableSet.fromJson(Map<String, dynamic> json) {
//     final w = (json['weight_kg'] ?? 0).toDouble();
//     final r = json['reps'] ?? 0;
//
//     return EditableSet(
//       weight: w,
//       reps: r,
//       weightController: TextEditingController(text: w.toString()),
//       repsController: TextEditingController(text: r.toString()),
//     );
//   }
//
//   Map<String, dynamic> toJson() => {"weight_kg": weight, "reps": reps};
// }
