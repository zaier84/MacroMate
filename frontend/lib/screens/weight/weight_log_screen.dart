import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';

class WeightLogScreen extends StatefulWidget {
  const WeightLogScreen({super.key});

  @override
  State<WeightLogScreen> createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends State<WeightLogScreen> {
  // local dummy storage for entries (use your API later)
  final List<Map<String, dynamic>> _entries = [
    // initial sample data (most recent first)
    {
      "weight": 76.4,
      "unit": "kg",
      "dateTime": DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      "notes": "Morning weigh-in",
    },
    {
      "weight": 76.8,
      "unit": "kg",
      "dateTime": DateTime.now().subtract(const Duration(days: 3)),
      "notes": "After workout",
    },
  ];

  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  String _unit = "kg"; // "kg" or "lb"
  DateTime _measuredAt = DateTime.now();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // prefill with last weight if available
    if (_entries.isNotEmpty) {
      _weightCtrl.text = _entries.first["weight"].toString();
      _unit = _entries.first["unit"] ?? "kg";
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toggleUnit(String unit) {
    // convert value when switching units if user entered a number
    final text = _weightCtrl.text.trim();
    if (text.isNotEmpty) {
      final value = double.tryParse(text.replaceAll(',', '.'));
      if (value != null) {
        double converted;
        if (unit == "kg" && _unit == "lb") {
          converted = (value * 0.45359237);
        } else if (unit == "lb" && _unit == "kg") {
          converted = (value / 0.45359237);
        } else {
          converted = value;
        }
        _weightCtrl.text = converted.toStringAsFixed(1);
      }
    }
    setState(() => _unit = unit);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measuredAt),
    );
    if (time == null) return;

    setState(() {
      _measuredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    final date =
        "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')}";
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$date • $hour:$minute";
  }

  double _calcChangeFromPrevious() {
    if (_entries.isEmpty) return 0.0;
    final last = _entries.firstWhere((e) => true, orElse: () => {});
    if (last == null || last.isEmpty) return 0.0;
    final prevWeight = (last["weight"] ?? 0.0) as double;
    final current =
        double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? prevWeight;
    // if units differ convert prevWeight to current unit
    final prevUnit = last["unit"] ?? _unit;
    double prevInCurrent = prevWeight;
    if (prevUnit != _unit) {
      if (_unit == "kg") {
        prevInCurrent = prevWeight * 0.45359237;
      } else {
        prevInCurrent = prevWeight / 0.45359237;
      }
    }
    return current - prevInCurrent;
  }

  Future<void> _saveEntry() async {
    final raw = _weightCtrl.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid weight.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Simulate a save (replace with API call)
    await Future.delayed(const Duration(milliseconds: 450));

    final entry = {
      "weight": double.parse(parsed.toStringAsFixed(1)),
      "unit": _unit,
      "dateTime": _measuredAt,
      "notes": _notesCtrl.text.trim(),
    };

    setState(() {
      _entries.insert(0, entry);
      _isSaving = false;
      _notesCtrl.clear();
      // keep weight in input for convenience
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Weight logged")));
  }

  // A small helper to convert kg -> lb for display
  String _displayWeightFor(Map<String, dynamic> entry, String toUnit) {
    final w = (entry["weight"] ?? 0.0) as double;
    final unit = entry["unit"] ?? "kg";
    if (unit == toUnit) return "${w.toStringAsFixed(1)} $unit";
    if (unit == "kg" && toUnit == "lb") {
      final v = w / 0.45359237;
      return "${v.toStringAsFixed(1)} lb";
    }
    final v = w * 0.45359237;
    return "${v.toStringAsFixed(1)} kg";
  }

  @override
  Widget build(BuildContext context) {
    final change = _entries.isNotEmpty
        ? (_entries.first["weight"] as double) -
              (_entries.length > 1
                  ? (_entries[1]["weight"] as double)
                  : (_entries.first["weight"] as double))
        : 0.0;
    final delta = _calcChangeFromPrevious();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Log Weight",
          style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            children: [
              // top card showing current / trend
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorderDefault),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // big weight display
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current",
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _entries.isNotEmpty
                              ? "${_entries.first["weight"].toStringAsFixed(1)} ${_entries.first["unit"]}"
                              : "-- ${_unit.toUpperCase()}",
                          style: AppTextStyles.heading.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              delta >= 0
                                  ? LucideIcons.trendingUp
                                  : LucideIcons.trendingDown,
                              color: delta >= 0
                                  ? Colors.redAccent
                                  : Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)} ${_unit}",
                              style: TextStyle(
                                color: delta >= 0
                                    ? Colors.redAccent
                                    : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "since last",
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // quick presets (small cards)
                    Column(
                      children: [
                        _presetButton("Morning", Duration(hours: 8)),
                        const SizedBox(height: 8),
                        _presetButton("Evening", Duration(hours: 20)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // input card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // weight input & unit toggle
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: "e.g. 76.5",
                              labelText: "Weight",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            _unitToggleButton("kg"),
                            const SizedBox(height: 6),
                            _unitToggleButton("lb"),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Date & time row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDateTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.neutral100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.calendar,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatDateTime(_measuredAt),
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    LucideIcons.chevronDown,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // notes
                    TextField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        hintText: "Notes (optional)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveEntry,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: AppColors.brandPrimary,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save weight",
                                // style: TextStyle(fontWeight: FontWeight.w700),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Recent entries header
              Row(
                children: [
                  Text(
                    "Recent",
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      // you can later navigate to full history
                    },
                    icon: const Icon(LucideIcons.chevronRight, size: 16),
                    label: const Text("History"),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Recent list (scrollable inside remaining space)
              Expanded(
                child: _entries.isEmpty
                    ? Center(
                        child: Text(
                          "No weight entries yet",
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final e = _entries[idx];
                          return _entryTile(e);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryTile(Map<String, dynamic> e) {
    final dt = e["dateTime"] as DateTime;
    final weight = (e["weight"] ?? 0.0) as double;
    final unit = e["unit"] ?? "kg";
    final notes = e["notes"] ?? "";

    return Container(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorderDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  "${weight.toStringAsFixed(1)}",
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unit,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(dt),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if ((notes as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // edit or delete action. For dummy screen provide delete:
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete entry?"),
                  content: const Text("This will remove the weight entry."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _entries.remove(e);
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(FontAwesomeIcons.trash),
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _unitToggleButton(String id) {
    final active = _unit == id;
    return GestureDetector(
      onTap: () => _toggleUnit(id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.brandPrimary : AppColors.neutral100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          id.toUpperCase(),
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _presetButton(String label, Duration at) {
    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        final target = DateTime(now.year, now.month, now.day, at.inHours);
        setState(() {
          _measuredAt = target;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
