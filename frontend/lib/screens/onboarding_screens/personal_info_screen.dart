import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _fullNameController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _gender;
  String _weightUnit = 'kg';
  String _heightUnit = 'ft_in';

  bool _saving = false;

  // Gender options like your TSX file
  final List<Map<String, String>> genderOptions = const [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
    {'value': 'non-binary', 'label': 'Non-binary'},
    {'value': 'prefer-not-to-say', 'label': 'Prefer not to say'},
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    final monthDiff = today.month - birthDate.month;
    if (monthDiff < 0 || (monthDiff == 0 && today.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  bool get _isFormValid {
    return _fullNameController.text.trim().isNotEmpty &&
        _dateOfBirth != null &&
        _gender != null &&
        (_dateOfBirth == null || _calculateAge(_dateOfBirth!) >= 13);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Maximum date: today - 13 years (user must be >= 13)
    final lastAllowed = DateTime(now.year - 13, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: lastAllowed,
      firstDate: DateTime(1900),
      lastDate: lastAllowed,
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _handleContinue() async {
    if (!(_fullNameController.text.trim().isNotEmpty &&
        _dateOfBirth != null &&
        _gender != null)) {
      // guard - should not happen as button disabled when invalid
      return;
    }

    final age = _calculateAge(_dateOfBirth!);
    if (age < 13) {
      // replicate alert in TSX
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Age restriction'),
          content: const Text(
            'You must be at least 13 years old to use MacroMate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final personalInfo = {
      // BACKEND EXPECTATION
      // "fullName": "Muhammad Zaier Ahmad",
      // "email": "zaier@example.com",
      // "dateOfBirth": "2002-11-06",
      // "gender": "male",
      // "weightUnit": "kg",
      // "heightUnit": "ft_in",
      'fullName': _fullNameController.text.trim(),
      'dateOfBirth': _dateOfBirth!.toIso8601String(),
      'age': age,
      'gender': _gender,
      'weightUnit': _weightUnit,
      'heightUnit': _heightUnit,
    };

    // debugPrint("PERSONAL INFO:");
    // debugPrint(personalInfo.toString());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('macromate_personal_info', jsonEncode(personalInfo));
    await prefs.setString('onboarding_personal_info', jsonEncode(personalInfo));

    setState(() => _saving = false);

    // navigate to next onboarding route - adjust route name to your app
    if (mounted) {
      // Navigator.of(context).pushNamed('/onboarding/body-metrics');
      widget.onContinue();
    }
  }

  String _formatDate(DateTime d) {
    // simple yyyy-mm-dd format
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final age = _dateOfBirth == null ? 0 : _calculateAge(_dateOfBirth!);
    final isAgeValid = _dateOfBirth != null && age >= 13;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // neutral-50
      body: SafeArea(
        child: Column(
          children: [
            // Content (scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Column(
                  children: [
                    // Welcome block
                    Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Let's get to know you",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'We need some basic information to personalize your experience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Form fields
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full name
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Full Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  hintText: 'Enter your full name',
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Date of birth
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Date of Birth',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickDate,
                                child: AbsorbPointer(
                                  child: TextField(
                                    controller: TextEditingController(
                                      text: _dateOfBirth == null
                                          ? ''
                                          : _formatDate(_dateOfBirth!),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Select date of birth',
                                      suffixIcon: const Icon(
                                        Icons.calendar_today,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_dateOfBirth != null)
                                Text(
                                  isAgeValid
                                      ? '✓ Age: $age years old'
                                      : '⚠ You must be at least 13 years old',
                                  style: TextStyle(
                                    color: isAgeValid
                                        ? Colors.green.shade700
                                        : Colors.red.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Gender
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gender',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InputDecorator(
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Text('Select your gender'),
                                    value: _gender,
                                    onChanged: (v) {
                                      setState(() => _gender = v);
                                    },
                                    items: genderOptions
                                        .map(
                                          (o) => DropdownMenuItem<String>(
                                            value: o['value'],
                                            child: Text(o['label'] ?? ''),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Preferred Units
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preferred Units',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Weight units
                              const Text(
                                'Weight Units',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          setState(() => _weightUnit = 'lbs'),
                                      style: ElevatedButton.styleFrom(
                                        elevation: _weightUnit == 'lbs' ? 2 : 0,
                                        backgroundColor: _weightUnit == 'lbs'
                                            ? Colors.blue
                                            : Colors.white,
                                        side: _weightUnit == 'lbs'
                                            ? null
                                            : const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                        foregroundColor: _weightUnit == 'lbs'
                                            ? Colors.white
                                            : Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text('Pounds (lbs)'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          setState(() => _weightUnit = 'kg'),
                                      style: ElevatedButton.styleFrom(
                                        elevation: _weightUnit == 'kg' ? 2 : 0,
                                        backgroundColor: _weightUnit == 'kg'
                                            ? Colors.blue
                                            : Colors.white,
                                        side: _weightUnit == 'kg'
                                            ? null
                                            : const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                        foregroundColor: _weightUnit == 'kg'
                                            ? Colors.white
                                            : Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text('Kilograms (kg)'),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Height units
                              const Text(
                                'Height Units',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          setState(() => _heightUnit = 'ft_in'),
                                      style: ElevatedButton.styleFrom(
                                        elevation: _heightUnit == 'ft_in'
                                            ? 2
                                            : 0,
                                        backgroundColor: _heightUnit == 'ft_in'
                                            ? Colors.blue
                                            : Colors.white,
                                        side: _heightUnit == 'ft_in'
                                            ? null
                                            : const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                        foregroundColor: _heightUnit == 'ft_in'
                                            ? Colors.white
                                            : Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text('Feet & Inches'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          setState(() => _heightUnit = 'cm'),
                                      style: ElevatedButton.styleFrom(
                                        elevation: _heightUnit == 'cm' ? 2 : 0,
                                        backgroundColor: _heightUnit == 'cm'
                                            ? Colors.blue
                                            : Colors.white,
                                        side: _heightUnit == 'cm'
                                            ? null
                                            : const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                        foregroundColor: _heightUnit == 'cm'
                                            ? Colors.white
                                            : Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      child: const Text('Centimeters (cm)'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Privacy Card
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            '🔒 Privacy First',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Your personal information is encrypted and never shared. We use this data only to calculate accurate nutrition recommendations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isFormValid && !_saving
                            ? _handleContinue
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
