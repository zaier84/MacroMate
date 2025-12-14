import 'package:flutter/material.dart';

class AppColors {
  static const Color brandPrimary = Color(0xFF4F46E5);
  static const Color brandSecondary = Color(0xFF9333EA);
  static const Color accent = Color(0xFF06B6D4);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF525252);

  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral600 = Color(0xFF525252);

  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPrimary, brandSecondary],
  );

  static const BoxDecoration brandGradientDecoration = BoxDecoration(
    gradient: brandGradient,
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
}
