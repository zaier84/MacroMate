import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:onboarding/auth_redirect.dart';
import 'package:onboarding/services/api_service.dart';
import 'package:onboarding/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingSummaryScreen extends StatefulWidget {
  const OnboardingSummaryScreen({super.key});

  @override
  State<OnboardingSummaryScreen> createState() =>
      _OnboardingSummaryScreenState();
}

class _OnboardingSummaryScreenState extends State<OnboardingSummaryScreen>
    with SingleTickerProviderStateMixin {
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  late AnimationController _controller;
  final Random _random = Random();

  bool _loading = false;
  final Map<String, dynamic> _summaryData = {};

  final AuthService _auth = AuthService();
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _loadOnboardingData();
  }

  Map<String, dynamic> getString(
    final SharedPreferences prefs,
    final String key,
  ) {
    return jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
  }

  Future<void> _loadOnboardingData() async {
    // Build payload from shared_prefs (same as you had)
    Map<String, dynamic> jsonPayload = {};
    final prefs = await SharedPreferences.getInstance();

    try {
      jsonPayload = {
        "email": _auth.auth.currentUser?.email,
        ...getString(prefs, 'onboarding_personal_info'),
        ...getString(prefs, 'onboarding_body_metrics'),
        ...getString(prefs, 'onboarding_goal_setting'),
        ...getString(prefs, 'onboarding_activity_level'),
        ...getString(prefs, 'onboarding_dietary_preferences'),
        ...getString(prefs, 'onboarding_macro_distribution'),
        ...getString(prefs, 'onboarding_meal_preferences'),
        ...getString(prefs, 'onboarding_notifications'),
      };
    } catch (e, st) {
      debugPrint('Failed reading local prefs: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _summaryData['error'] = 'Failed to read local data';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _summaryData.clear();
    });

    // Helper: a small wrapper to handle timeouts and status codes
    Future<Map<String, dynamic>> _postAndFetchSummary() async {
      // 1) Post onboarding payload
      final String postBody = jsonEncode(jsonPayload);
      http.Response postResp;
      try {
        // set an explicit timeout
        postResp = await _api
            .post("/api/onboarding/submit", postBody)
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        throw Exception('Request timed out while submitting onboarding data.');
      } catch (e) {
        rethrow;
      }
      if (postResp.statusCode < 200 || postResp.statusCode >= 300) {
        throw Exception(
          'Submit failed: ${postResp.statusCode} ${postResp.body}',
        );
      }

      // 2) GET the summary (server may need a moment; if your server returns the summary in POST response,
      // you can avoid second call — prefer server returning summary in POST for efficiency)
      http.Response getResp;
      try {
        getResp = await _api
            .get("/api/onboarding/summary")
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        throw Exception('Request timed out while fetching summary.');
      } catch (e) {
        rethrow;
      }

      if (getResp.statusCode < 200 || getResp.statusCode >= 300) {
        throw Exception(
          'Summary fetch failed: ${getResp.statusCode} ${getResp.body}',
        );
      }

      // parse body as JSON
      final Map<String, dynamic> parsed = (getResp.body.isNotEmpty)
          ? jsonDecode(getResp.body) as Map<String, dynamic>
          : {};
      return parsed;
    }

    // Attempt with basic retry for transient errors (optional)
    const int maxAttempts = 2;
    int attempt = 0;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        final summary = await _postAndFetchSummary();

        if (!mounted) return;

        setState(() {
          _summaryData.addAll(summary); // store server-calculated summary
          _loading = false;
        });
        return;
      } catch (e, st) {
        debugPrint('Attempt $attempt failed: $e\n$st');

        // If auth issues: you might want to sign out / refresh token
        if (e.toString().contains('401') ||
            e.toString().contains('Not authenticated')) {
          // handle auth error - navigate to login, or try to refresh token if AuthService exposes that
          if (!mounted) return;
          setState(() {
            _loading = false;
            _summaryData['error'] =
                'Authentication failed. Please sign in again.';
          });
          return;
        }

        if (attempt >= maxAttempts) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _summaryData['error'] =
                'Failed to submit onboarding. Please check your connection and try again.';
          });
          return;
        }

        // small backoff before retry
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleGetStarted() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AuthRedirect()));
    // debugPrint("ONBOARDING COMPLETE! LOADING HOME SCREEN");
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    // Brand colors (matching your TSX theme)
    const Color brandPrimary = Color(0xFF4F46E5);
    const Color brandSecondary = Color(0xFF9333EA);
    const Color headerTextColor = Color(0xFF111827);
    const Color neutralTextColor = Color(0xFF6B7280);
    const Color neutral600 = Color(0xFF525252);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_summaryData.containsKey('error')) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_summaryData['error'] ?? 'Unknown error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadOnboardingData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Safe extraction with fallbacks
    final profile = _toMap(_summaryData['profile']);
    final goal = _toMap(_summaryData['goal']);
    final daily = _toMap(_summaryData['daily_targets']);
    final macros = _toMap(daily['macro_targets']);
    final tracking = _toMap(_summaryData['tracking']);

    final name = profile['name']?.toString() ?? 'Friend';
    final age = profile['age'] != null ? profile['age'].toString() : '-';
    final weightKg = profile['current_weight_kg'] != null
        ? (profile['current_weight_kg'] is num
              ? (profile['current_weight_kg'] as num).toStringAsFixed(1)
              : profile['current_weight_kg'].toString())
        : '-';
    final heightCm = profile['height_cm'] != null
        ? profile['height_cm'].toString()
        : '-';
    final bmi = profile['bmi'] is num
        ? (profile['bmi'] as num).toDouble()
        : (profile['bmi'] != null
              ? double.tryParse(profile['bmi'].toString()) ?? 0.0
              : 0.0);
    final bmiCategory = profile['bmi_category']?.toString() ?? '';

    // Goal
    final primaryGoal = goal['primary_goal']?.toString() ?? 'maintain';
    final targetWeight = goal['target_weight_kg'] != null
        ? goal['target_weight_kg'].toString()
        : null;
    final activityLevel = goal['activity_level']?.toString() ?? '-';

    // Daily targets / macros
    final dailyCalories = daily['daily_calories'] is num
        ? (daily['daily_calories'] as num).toInt()
        : (daily['daily_calories'] != null
              ? int.tryParse(daily['daily_calories'].toString()) ?? 0
              : 0);

    final proteinG = macros['protein_g'] is num
        ? (macros['protein_g'] as num).toInt()
        : (macros['protein_g'] != null
              ? int.tryParse(macros['protein_g'].toString()) ?? 0
              : 0);
    final carbsG = macros['carbs_g'] is num
        ? (macros['carbs_g'] as num).toInt()
        : (macros['carbs_g'] != null
              ? int.tryParse(macros['carbs_g'].toString()) ?? 0
              : 0);
    final fatsG = macros['fats_g'] is num
        ? (macros['fats_g'] as num).toInt()
        : (macros['fats_g'] != null
              ? int.tryParse(macros['fats_g'].toString()) ?? 0
              : 0);

    final proteinPct = macros['protein_pct'] is num
        ? (macros['protein_pct'] as num).toInt()
        : (macros['protein_pct'] != null
              ? int.tryParse(macros['protein_pct'].toString()) ?? 0
              : 0);
    final carbsPct = macros['carbs_pct'] is num
        ? (macros['carbs_pct'] as num).toInt()
        : (macros['carbs_pct'] != null
              ? int.tryParse(macros['carbs_pct'].toString()) ?? 0
              : 0);
    final fatsPct = macros['fat_pct'] is num
        ? (macros['fat_pct'] as num).toInt()
        : (macros['fat_pct'] != null
              ? int.tryParse(macros['fat_pct'].toString()) ?? 0
              : 0);

    // Tracking
    final metricsCount = tracking['metrics_count'] is num
        ? (tracking['metrics_count'] as num).toInt()
        : (tracking['metrics_count'] != null
              ? int.tryParse(tracking['metrics_count'].toString()) ?? 0
              : 0);
    final mealsPerDay = tracking['meals_per_day']?.toString() ?? '-';
    final dietType = tracking['diet_type']?.toString() ?? 'All foods';
    final units = _toMap(tracking['units']);
    final weightUnit = units['weight']?.toString() ?? 'kg';
    final heightUnit = units['height']?.toString() ?? 'cm';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Main icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primaryGradientStart, primaryGradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Welcome text (inserted: name)
                  Text(
                    "Welcome to MacroMate, $name! 🎉", // <-- INSERTED: profile.name
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: headerTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your personalized nutrition and fitness journey starts now. Here's your custom profile summary.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: neutralTextColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Cards
                  _SummaryCard(
                    title: "Your Profile",
                    icon: Icons.person_outline,
                    gradientColors: [
                      primaryGradientStart.withOpacity(0.05),
                      primaryGradientEnd.withOpacity(0.05),
                    ],
                    borderColor: primaryGradientStart.withOpacity(0.2),
                    children: [
                      // INSERTED: Age, weight, height, BMI + category
                      _InfoRow("Age", "$age years"),
                      _InfoRow("Current Weight", "$weightKg $weightUnit"),
                      _InfoRow(
                        "Height",
                        "$heightCm ${heightUnit == 'ft_in' ? 'ft/in' : 'cm'}",
                      ),
                      _InfoRow(
                        "BMI",
                        "${bmi.toStringAsFixed(1)} (${bmiCategory.isNotEmpty ? bmiCategory : '—'})",
                        color: bmiCategory.toLowerCase().contains('normal')
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ],
                  ),

                  _SummaryCard(
                    title: "Your Goal",
                    icon: Icons.trending_up,
                    gradientColors: const [
                      Color(0xFFF0FDF4),
                      Color(0xFFDCFCE7),
                    ],
                    borderColor: const Color(0xFFA7F3D0),
                    children: [
                      // INSERTED: goal.primary_goal and target weight, activity level
                      _InfoRow(
                        "Primary Goal",
                        primaryGoal.replaceAll('_', ' '),
                      ),
                      _InfoRow(
                        "Target Weight",
                        targetWeight != null
                            ? "$targetWeight $weightUnit"
                            : "—",
                      ),
                      _InfoRow("Activity Level", activityLevel),
                    ],
                  ),

                  _SummaryCard(
                    title: "Daily Targets",
                    icon: Icons.local_fire_department_outlined,
                    gradientColors: const [
                      Color(0xFFFFF7ED),
                      Color(0xFFFFFBEB),
                    ],
                    borderColor: const Color(0xFFFDE68A),
                    children: [
                      const SizedBox(height: 6),
                      // INSERTED: daily calories
                      Text(
                        "${dailyCalories.toString()} kcal/day",
                        style: const TextStyle(
                          color: Color(0xFFEA580C),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // INSERTED: protein grams and pct
                          _MacroStat(
                            "Protein",
                            "$proteinG g • $proteinPct%",
                            Colors.red,
                          ),
                          _MacroStat(
                            "Carbs",
                            "$carbsG g • $carbsPct%",
                            Colors.blue,
                          ),
                          _MacroStat(
                            "Fat",
                            "$fatsG g • $fatsPct%",
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),

                  _SummaryCard(
                    title: "You're all set to track",
                    icon: Icons.auto_graph_outlined,
                    gradientColors: const [
                      Color(0xFFF3E8FF),
                      Color(0xFFFCE7F3),
                    ],
                    borderColor: const Color(0xFFE9D5FF),
                    children: [
                      // INSERTED: tracking details
                      _InfoRow("Tracking Metrics", metricsCount.toString()),
                      _InfoRow("Meals per Day", mealsPerDay.toString()),
                      _InfoRow("Diet Type", dietType.replaceAll('_', ' ')),
                      _InfoRow("Units", "$weightUnit & $heightUnit"),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Button
                  GestureDetector(
                    onTap: handleGetStarted,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [primaryGradientStart, primaryGradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "Start Your Journey 🎯",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "🎉 You've joined over 1 million people on their health journey!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: neutral600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          // Confetti overlay (same as before)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      _random,
                      _controller.value,
                      brandPrimary,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable components
// ─────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600

  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final List<Widget> children;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    // const textPrimary = Color(0xFF111827);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: gradientColors.last.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: neutralTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600

  final String label;
  final String value;
  final Color? color;

  const _InfoRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    // const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF525252);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: textSecondary)),
          Text(
            value,
            style: TextStyle(
              color: color ?? neutralTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Confetti painter (animated falling dots)
// ─────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final Random random;
  final double progress;
  final Color color;

  _ConfettiPainter(this.random, this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 40; i++) {
      paint.color = color.withOpacity(0.6);
      final dx = random.nextDouble() * size.width;
      final dy = (size.height * progress * 1.5 + i * 10) % size.height;
      final radius = random.nextDouble() * 3 + 2;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
