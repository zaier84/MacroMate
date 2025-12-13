import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onboarding/services/api_service.dart';
import '../../theme/colors.dart';

class ManualMealScreen extends StatefulWidget {
  const ManualMealScreen({super.key});

  @override
  State<ManualMealScreen> createState() => _ManualMealScreenState();
}

class _ManualMealScreenState extends State<ManualMealScreen> {
  final ApiService _api = ApiService();

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _resultsScrollController = ScrollController();

  String selectedMealType = "breakfast";

  List<Map<String, dynamic>> _results = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  Timer? _debounce;

  // Selected foods. Each entry will include a `qtyController` TextEditingController.
  final List<Map<String, dynamic>> selectedFoods = [];

  // Show results container?
  bool _showResults = false;

  // Submission state to prevent double posts
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _resultsScrollController.addListener(_onResultsScroll);
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      // When search gains focus and there's text, show results. When it loses focus hide.
      if (_searchFocus.hasFocus && _searchCtrl.text.trim().isNotEmpty) {
        setState(() => _showResults = true);
      } else if (!_searchFocus.hasFocus) {
        setState(() => _showResults = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _resultsScrollController.removeListener(_onResultsScroll);
    _resultsScrollController.dispose();
    _debounce?.cancel();

    // dispose qty controllers
    for (final item in selectedFoods) {
      final ctrl = item['qtyController'];
      if (ctrl is TextEditingController) ctrl.dispose();
    }

    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final text = _searchCtrl.text.trim();
      if (text.isEmpty) {
        setState(() {
          _results.clear();
          _page = 1;
          _hasMore = true;
          _showResults = false;
        });
        return;
      }
      _page = 1;
      _hasMore = true;
      _fetchFoods(reset: true);
      // show results while typing / after debounce
      if (_searchFocus.hasFocus) setState(() => _showResults = true);
    });
  }

  void _onResultsScroll() {
    if (!_resultsScrollController.hasClients || _isLoading || !_hasMore) return;
    final threshold = 150; // px before end to trigger more
    final max = _resultsScrollController.position.maxScrollExtent;
    final pos = _resultsScrollController.position.pixels;
    if (max - pos <= threshold) {
      _fetchFoods();
    }
  }

  Future<void> _fetchFoods({bool reset = false}) async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      if (reset) {
        setState(() {
          _results.clear();
          _page = 1;
          _hasMore = true;
        });
      }
      return;
    }

    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final encoded = Uri.encodeQueryComponent(query);
      final path = "/api/foods/search?q=$encoded&page=$_page&page_size=20";
      final res = await _api.get(path);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final fetched = List<Map<String, dynamic>>.from(
          (data["foods"] as List<dynamic>? ?? []).map(
            (e) => e as Map<String, dynamic>,
          ),
        );

        if (!mounted) return;
        setState(() {
          if (reset) {
            _results = fetched;
          } else {
            _results.addAll(fetched);
          }
          _page++;
          _hasMore = fetched.isNotEmpty;
          // If results are available and search has focus, keep results visible
          if (_results.isNotEmpty && _searchFocus.hasFocus) _showResults = true;
        });
      } else {
        // stop further loads on server error
        if (mounted) {
          setState(() {
            _hasMore = false;
          });
          debugPrint("Food search failed: ${res.statusCode}");
        }
      }
    } catch (e, st) {
      debugPrint("Food search error: $e\n$st");
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectFood(Map<String, dynamic> item) {
    // Build item and add a qty controller
    final entry = <String, dynamic>{
      "provider": item["provider"],
      "id": item["id"],
      "name": item["name"] ?? "",
      "brand": item["brand"],
      "calories": item["calories"],
      "protein": item["protein_g"],
      "carbs": item["carbs_g"],
      "fats": item["fats_g"],
      "quantity": item["serving"] ?? "100g",
    };

    // create controller and store it on the entry so edits persist
    entry['qtyController'] = TextEditingController(
      text: entry['quantity']?.toString() ?? "100g",
    );

    setState(() {
      selectedFoods.add(entry);
      // clear search & hide results
      _searchCtrl.clear();
      _results.clear();
      _page = 1;
      _hasMore = true;
      _showResults = false;
      // unfocus to hide keyboard
      _searchFocus.unfocus();
    });
  }

  void _deleteFood(int index) {
    final entry = selectedFoods[index];
    final ctrl = entry['qtyController'];
    if (ctrl is TextEditingController) ctrl.dispose();
    setState(() => selectedFoods.removeAt(index));
  }

  /// parse a quantity string like "150g", "150 g", "1.5", "1.5 oz"
  /// returns { "value": int, "unit": "g" } - value is rounded integer
  Map<String, dynamic> _parseQuantity(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {"value": 0, "unit": "g"};

    final regex = RegExp(r'^([\d.,]+)\s*([a-zA-Z%]*)$');
    final m = regex.firstMatch(trimmed);

    if (m == null) {
      // fallback: try to extract digits
      final nums = RegExp(r'[\d,.]+').stringMatch(trimmed) ?? "0";
      final v = double.tryParse(nums.replaceAll(',', '.')) ?? 0.0;
      return {"value": v.round(), "unit": "g"};
    }

    final numStr = m.group(1) ?? "0";
    final unitStr = (m.group(2) ?? "").toLowerCase();
    final parsed = double.tryParse(numStr.replaceAll(',', '.')) ?? 0.0;
    final value = parsed.round();
    final unit = unitStr.isEmpty ? "g" : unitStr;
    return {"value": value, "unit": unit};
  }

  Map<String, num> get totalMacros {
    num calories = 0;
    num protein = 0;
    num carbs = 0;
    num fats = 0;

    for (var m in selectedFoods) {
      final qtyText = m["qtyController"].text;
      final parsed = _parseQuantity(qtyText);

      final int qty = parsed["value"]; // user-entered amount
      final int baseQty =
          m["base_qty"] ?? 100; // food is per 100g or API serving

      if (baseQty <= 0) continue;

      final scale = qty / baseQty;

      calories += (m["calories"] ?? 0) * scale;
      protein += (m["protein"] ?? 0) * scale;
      carbs += (m["carbs"] ?? 0) * scale;
      fats += (m["fats"] ?? 0) * scale;
    }

    return {
      "calories": calories,
      "protein": protein,
      "carbs": carbs,
      "fats": fats,
    };
  }

  Map<String, dynamic> _buildMealPayload() {
    final date = DateTime.now();
    final dateOnly =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    // final consumedAt = DateTime.now().toUtc().toIso8601String();
    final now = DateTime.now();
    final consumedAt = now.toIso8601String().replaceFirst(RegExp(r'\.\d+'), '');

    final foods = selectedFoods.map((m) {
      final qtyText = m["qtyController"] is TextEditingController
          ? (m["qtyController"] as TextEditingController).text
          : (m["quantity"]?.toString() ?? "100g");

      final parsed = _parseQuantity(qtyText);
      final baseQty = m["base_qty"] ?? 100;
      final scale = (parsed["value"] / baseQty);
      return {
        "name": m["name"],
        "brand": m["brand"] ?? "Generic",
        "quantity": parsed["value"],
        "unit": parsed["unit"],

        "calories": ((m["calories"] ?? 0) * scale).round(),
        "protein_g": ((m["protein"] ?? 0) * scale),
        "carbs_g": ((m["carbs"] ?? 0) * scale),
        "fats_g": ((m["fats"] ?? 0) * scale),
      };
    }).toList();

    return {
      "date": dateOnly,
      "meal_type": selectedMealType,
      "consumed_at": consumedAt,
      "foods": foods,
    };
  }

  /// This is the only UI-changing action you asked to add:
  /// send prepared meal payload to POST /api/nutrition/log using ApiService.post
  Future<void> _onSaveMealPressed() async {
    if (_isSubmitting) return;
    if (selectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one food item.")),
      );
      return;
    }

    final payload = _buildMealPayload();
    final body = jsonEncode(payload);

    setState(() => _isSubmitting = true);

    try {
      debugPrint(body);
      final res = await _api.post("/api/nutrition/log", body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meal logged successfully.")),
        );

        // Clear selected items (UI remains same)
        for (final item in selectedFoods) {
          final ctrl = item['qtyController'];
          if (ctrl is TextEditingController) ctrl.dispose();
        }
        setState(() {
          selectedFoods.clear();
        });
      } else {
        // Error from backend - show message
        String msg = "Failed to log meal (${res.statusCode})";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['message'] != null) {
            msg = decoded['message'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e, st) {
      debugPrint("Error posting meal: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error while logging meal.")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // UI components

  Widget _mealTypeBtn(String type) {
    final active = selectedMealType == type;
    return GestureDetector(
      onTap: () => setState(() => selectedMealType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.brandPrimary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          type[0].toUpperCase() + type.substring(1),
          style: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _foodResultTile(Map<String, dynamic> item) {
    // use small badges to show macros + calories
    final calories = item["calories"]?.toString() ?? "-";
    final protein = item["protein_g"]?.toString() ?? "-";
    final carbs = item["carbs_g"]?.toString() ?? "-";
    final fats = item["fats_g"]?.toString() ?? "-";
    final brand = (item["brand"] ?? "").toString();

    return InkWell(
      onTap: () => _selectFood(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7E7EA)),
        ),
        child: Row(
          children: [
            // left: name & brand
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["name"] ?? "",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (brand.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        brand,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // right: cals + macros
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$calories kcal",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _smallBadge("$protein g", Colors.redAccent),
                    const SizedBox(width: 6),
                    _smallBadge("$carbs g", Colors.blueAccent),
                    const SizedBox(width: 6),
                    _smallBadge("$fats g", Colors.orangeAccent),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _selectedFoodTile(int index) {
    final item = selectedFoods[index];
    final ctrl = item['qtyController'] as TextEditingController?;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item["name"] ?? "",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: ctrl,
              // onChanged: (v) => item["quantity"] = v,
              onChanged: (v) {
                setState(() {
                  item["quantity"] = v;
                });
              },
              decoration: const InputDecoration(
                hintText: "100g",
                isDense: true,
                border: OutlineInputBorder(borderSide: BorderSide.none),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _deleteFood(index),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return GestureDetector(
      onTap: _onSaveMealPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [AppColors.brandPrimary, AppColors.brandSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _isSubmitting ? "Saving..." : "Save Meal",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _resultsContainer() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _results.isEmpty && !_isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "No results. Try another search term.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          : ListView.builder(
              controller: _resultsScrollController,
              itemCount: _results.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, idx) {
                if (idx >= _results.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final item = _results[idx];
                return _foodResultTile(item);
              },
            ),
    );
  }

  Widget _totalMacrosBar() {
    final sum = totalMacros;

    final calories = (sum['calories'] ?? 0).toDouble();
    final protein = (sum['protein'] ?? 0).toDouble();
    final carbs = (sum['carbs'] ?? 0).toDouble();
    final fats = (sum['fats'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Meal Total",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMacroChip(
                      label: 'Calories',
                      value: calories,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMacroChip(
                      label: 'Protein',
                      value: protein,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMacroChip(
                      label: 'Carbs',
                      value: carbs,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMacroChip(
                      label: 'Fats',
                      value: fats,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip({
    required String label,
    required double? value,
    required Color color,
  }) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13), // 🔥 light pastel
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value != null
                ? (label == 'Calories'
                      ? '${value.round()} kcal'
                      : '${value.toStringAsFixed(1)}g')
                : (label == 'Calories' ? '0 kcal' : '0g'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tap outside to dismiss keyboard and results
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _showResults = false);
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Log Meal",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Meal type selector
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _mealTypeBtn("breakfast"),
                    _mealTypeBtn("lunch"),
                    _mealTypeBtn("snack"),
                    _mealTypeBtn("dinner"),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Search box
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        _page = 1;
                        _fetchFoods(reset: true);
                        // ensure results visible
                        setState(() => _showResults = true);
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _results.clear();
                                    _showResults = false;
                                    _page = 1;
                                    _hasMore = true;
                                  });
                                },
                              )
                            : null,
                        hintText: "Search food ...",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onTap: () {
                        // show results if we have them
                        if (_results.isNotEmpty)
                          setState(() => _showResults = true);
                      },
                    ),
                  ),
                ],
              ),

              // RESULTS container (separate)
              if (_showResults)
                Column(
                  children: [const SizedBox(height: 8), _resultsContainer()],
                ),

              const SizedBox(height: 12),

              // Selected items + submit
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (selectedFoods.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Selected items",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),

                    if (selectedFoods.isNotEmpty)
                      ...selectedFoods.asMap().entries.map((entry) {
                        final i = entry.key;
                        return _selectedFoodTile(i);
                      }).toList(),

                    const SizedBox(height: 12),

                    _totalMacrosBar(),

                    if (selectedFoods.isNotEmpty) _submitButton(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
