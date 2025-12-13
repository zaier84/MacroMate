import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onboarding/screens/login_screen.dart';
import 'package:onboarding/screens/main_navigation/main_navigation.dart';
import 'package:onboarding/screens/onboarding_screen.dart';
import 'package:onboarding/screens/splash_screen.dart';
import 'package:onboarding/services/api_service.dart';
import 'package:onboarding/services/auth_service.dart';

class AuthRedirect extends StatefulWidget {
  const AuthRedirect({super.key});

  @override
  State<AuthRedirect> createState() => _AuthRedirectState();
}

class _AuthRedirectState extends State<AuthRedirect> {
  late final AuthService _auth;
  final ApiService _api = ApiService();
  bool _navigated = false;
  final _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _auth = AuthService();
    _decide();
  }

  Future<void> _safeNavigate(Widget page) async {
    if (_navigated || !mounted) return;
    _navigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => page));
    });
  }

  Future<void> _decide() async {
    final user = _auth.auth.currentUser;

    if (user == null) {
      _safeNavigate(LoginScreen());
      return;
    }

    bool? isProfileComplete;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final resp = await _api.get("/api/users/me/status");

        if (resp.body.isEmpty) {
          debugPrint("Attempt $attempt: Empty body");
          throw Exception("Empty response body");
        }

        final decoded = jsonDecode(resp.body);

        if (decoded is! Map<String, dynamic>) {
          debugPrint("Attempt $attempt: Invalid JSON format");
          throw Exception("Invalid JSON");
        }

        final value = decoded["isProfileComplete"];

        if (value is bool) {
          isProfileComplete = value;
          break; // success
        } else {
          debugPrint("Attempt $attempt: isProfileComplete is null or invalid");
          throw Exception("Invalid isProfileComplete");
        }
      } catch (e) {
        debugPrint("Status fetch failed (attempt $attempt): $e");

        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }

    debugPrint("Body: $isProfileComplete");

    if (isProfileComplete == null) {
      debugPrint("Fallback: assuming profile incomplete");
      _safeNavigate(LoginScreen());
      return;
    }

    if (isProfileComplete) {
      // _safeNavigate(HomeScreen());
      _safeNavigate(MainNavigation());
    } else {
      _safeNavigate(OnboardingScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
