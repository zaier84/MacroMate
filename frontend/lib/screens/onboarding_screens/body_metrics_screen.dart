import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BodyMetricsScreen extends StatefulWidget {
  const BodyMetricsScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _heightCmController = TextEditingController();
  final _weightController = TextEditingController();

  Map<String, dynamic> _personalInfo = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPersonalInfo();
    // listen to controllers to update UI (e.g. BMI)
    _heightFeetController.addListener(() => setState(() {}));
    _heightInchesController.addListener(() => setState(() {}));
    _heightCmController.addListener(() => setState(() {}));
    _weightController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _heightCmController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonalInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('onboarding_personal_info') ?? '{}';
    try {
      _personalInfo = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _personalInfo = {};
    }

    // set defaults if missing (keeps parity with TSX)
    _personalInfo['heightUnit'] ??= 'ft_in';
    _personalInfo['weightUnit'] ??= 'kg';

    // Optionally prefill if body metrics already exist (tsx merges them)
    if (_personalInfo.containsKey('height')) {
      final height = _personalInfo['height'] as String;
      // parse a string like 5'9" into controllers if possible
      final ftInRegex = RegExp(r"^(\d+)'(\d+)");
      final m = ftInRegex.firstMatch(height);
      if (m != null) {
        _heightFeetController.text = m.group(1) ?? '';
        _heightInchesController.text = m.group(2) ?? '';
      } else {
        // assume cm
        _heightCmController.text = height;
      }
    }
    if (_personalInfo.containsKey('weight')) {
      _weightController.text = _personalInfo['weight'].toString();
    }

    setState(() => _loading = false);
  }

  // convert input texts safely to double, return null on invalid
  double? _toDouble(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return double.tryParse(s.trim());
  }

  double? _calculateBMI() {
    final wText = _weightController.text.trim();
    if (wText.isEmpty) return null;

    final weightRaw = _toDouble(wText);
    if (weightRaw == null) return null;

    double weightKg = weightRaw;
    final weightUnit = _personalInfo['weightUnit'] ?? 'lbs';
    if (weightUnit == 'lbs') {
      weightKg = weightKg / 2.205;
    }

    double heightM = 0.0;
    final heightUnit = _personalInfo['heightUnit'] ?? 'ft_in';
    if (heightUnit == 'ft_in') {
      final feet = _toDouble(_heightFeetController.text) ?? 0;
      final inches = _toDouble(_heightInchesController.text) ?? 0;
      if (feet == 0 && inches == 0) return null;
      final totalInches = feet * 12 + inches;
      heightM = totalInches * 0.0254;
    } else {
      final cm = _toDouble(_heightCmController.text);
      if (cm == null || cm == 0) return null;
      heightM = cm / 100;
    }

    if (heightM <= 0) return null;
    return weightKg / (heightM * heightM);
  }

  Map<String, dynamic> _bmiCategory(double bmi) {
    if (bmi < 18.5) return {'label': 'Underweight', 'color': Colors.blue};
    if (bmi < 25) return {'label': 'Normal', 'color': Colors.green};
    if (bmi < 30) return {'label': 'Overweight', 'color': Colors.orange};
    return {'label': 'Obese', 'color': Colors.red};
  }

  bool get _isFormValid {
    final heightUnit = _personalInfo['heightUnit'] ?? 'ft_in';
    final weightText = _weightController.text.trim();
    final bool weightValid =
        weightText.isNotEmpty && _toDouble(weightText) != null;
    bool heightValid = false;
    if (heightUnit == 'ft_in') {
      final f = _heightFeetController.text.trim();
      final i = _heightInchesController.text.trim();
      heightValid =
          f.isNotEmpty &&
          i.isNotEmpty &&
          _toDouble(f) != null &&
          _toDouble(i) != null;
    } else {
      final cm = _heightCmController.text.trim();
      heightValid = cm.isNotEmpty && _toDouble(cm) != null;
    }
    return heightValid && weightValid;
  }

  Future<void> _handleContinue() async {
    if (!_isFormValid) return;

    setState(() => _saving = true);

    final heightUnit = _personalInfo['heightUnit'] ?? 'ft_in';
    Map<String, dynamic> heightFormatted;
    if (heightUnit == 'ft_in') {
      // heightFormatted =
      //     "${_heightFeetController.text.trim()}'${_heightInchesController.text.trim()}\"";
      heightFormatted = {
        "height_ft": _heightFeetController.text.trim(),
        "height_in": _heightInchesController.text.trim(),
      };
    } else {
      // heightFormatted = _heightCmController.text.trim();
      heightFormatted = {"height_cm": _heightCmController.text.trim()};
    }

    final bodyMetrics = {
      // BACKEND EXPECTATIONS
      // "height_ft": 5,
      // "height_in": 7,
      // "weight": 65.0,

      ...heightFormatted,
      'weight': _weightController.text.trim(),
    // 'height': heightFormatted,
      // 'heightUnit': heightUnit,
      // 'weightUnit': _personalInfo['weightUnit'] ?? 'lbs',
    };

    final merged = {..._personalInfo, ...bodyMetrics};

    // debugPrint("BODY METRICS: ");
    // debugPrint(bodyMetrics.toString());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('macromate_personal_info', jsonEncode(merged));
    await prefs.setString('onboarding_body_metrics', jsonEncode(bodyMetrics));

    setState(() => _saving = false);

    if (mounted) {
      // Navigator.of(context).pushNamed('/onboarding/select-goal');
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _calculateBMI();
    final bmiInfo = bmi != null ? _bmiCategory(bmi) : null;
    final weightUnitLabel = _personalInfo['weightUnit'] ?? 'lbs';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        children: [
                          // Icon + title
                          Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: const LinearGradient(
                                    colors: [
                                      primaryGradientStart,
                                      primaryGradientEnd,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.straighten,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Your body metrics',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'These measurements help us calculate accurate calorie and nutrition targets.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: neutralTextColor),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Height label + inputs
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Height',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if ((_personalInfo['heightUnit'] ?? 'ft_in') ==
                                    'ft_in') ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Feet',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: neutralTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              keyboardType:
                                                  TextInputType.number,
                                              controller: _heightFeetController,
                                              decoration: InputDecoration(
                                                hintText: '5',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 12,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Inches',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: neutralTextColor,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            TextField(
                                              keyboardType:
                                                  TextInputType.number,
                                              controller:
                                                  _heightInchesController,
                                              decoration: InputDecoration(
                                                hintText: '9',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 12,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  TextField(
                                    keyboardType: TextInputType.number,
                                    controller: _heightCmController,
                                    decoration: InputDecoration(
                                      hintText: '175',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Weight input
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Weight',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  controller: _weightController,
                                  decoration: InputDecoration(
                                    hintText: (weightUnitLabel == 'lbs')
                                        ? '150'
                                        : '68',
                                    suffix: Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Text(
                                        weightUnitLabel,
                                        style: const TextStyle(
                                          color: neutralTextColor,
                                        ),
                                      ),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // BMI card
                          if (bmi != null)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEFF6FF),
                                    Color(0xFFE0F2FE),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Your BMI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    bmi.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    bmiInfo!['label'],
                                    style: TextStyle(
                                      color: bmiInfo['color'],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'BMI is a general health indicator. We\'ll create a personalized plan based on your goals.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: neutralTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Info Note
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF7ED), Color(0xFFFFF1E0)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFB923C).withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: const [
                                Text(
                                  '💡 Why we need this',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Your height and weight help us calculate your Basal Metabolic Rate (BMR) and determine accurate calorie targets for your goals.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: neutralTextColor),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Continue button
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    // If disabled → make gradient colors more transparent
                                    _isFormValid && !_saving
                                        ? primaryGradientStart
                                        : primaryGradientStart.withValues(
                                            alpha: 0.5,
                                          ),
                                    _isFormValid && !_saving
                                        ? primaryGradientEnd
                                        // : primaryGradientEnd.withOpacity(0.5),
                                        : primaryGradientEnd.withValues(
                                            alpha: 0.5,
                                          ),
                                  ], // Blue gradient
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ElevatedButton(
                                onPressed: _isFormValid && !_saving
                                    ? _handleContinue
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.0,
                                        ),
                                      )
                                    : const Text(
                                        'Continue',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
