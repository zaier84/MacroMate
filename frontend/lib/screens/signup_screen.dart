import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onboarding/screens/login_screen.dart';
import 'package:onboarding/services/auth_service.dart';
import 'package:onboarding/theme/colors.dart';
import 'package:onboarding/theme/text_styles.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  final _confirmPwCtl = TextEditingController();

  final AuthService _auth = AuthService();

  bool loading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool agreeToTerms = false;

  String? error;

  // -------------------------------
  // Password strength calculation
  // -------------------------------
  int _passwordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  Future<void> _signup(BuildContext context) async {
    if (_pwCtl.text != _confirmPwCtl.text) {
      setState(() => error = "Passwords don't match");
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await _auth.signUpWithEmail(
        _emailCtl.text.trim(),
        _pwCtl.text,
      );

      await _auth.sendEmailVerification();
      await _auth.getCurrentIdToken(forceRefresh: true);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = "Signup failed. Please try again.");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_pwCtl.text);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.brandGradient,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "M",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Join MacroMate",
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Start your personalized health journey today",
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.neutralTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorderDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("Full Name"),
                      _input(
                        controller: _nameCtl,
                        hint: "Enter your full name",
                        icon: Icons.person_outline,
                      ),

                      const SizedBox(height: 14),

                      _label("Email Address"),
                      _input(
                        controller: _emailCtl,
                        hint: "Enter your email",
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 14),

                      _label("Password"),
                      _input(
                        controller: _pwCtl,
                        hint: "Create a strong password",
                        icon: Icons.lock_outline,
                        obscure: !showPassword,
                        suffix: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                      ),

                      if (_pwCtl.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i < strength
                                      ? AppColors.brandPrimary
                                      : AppColors.neutral100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      _label("Confirm Password"),
                      _input(
                        controller: _confirmPwCtl,
                        hint: "Confirm your password",
                        icon: Icons.lock_outline,
                        obscure: !showConfirmPassword,
                        suffix: IconButton(
                          icon: Icon(
                            showConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              showConfirmPassword = !showConfirmPassword;
                            });
                          },
                        ),
                      ),

                      if (_confirmPwCtl.text.isNotEmpty &&
                          _pwCtl.text != _confirmPwCtl.text)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            "Passwords don't match",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),

                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: agreeToTerms,
                            onChanged: (v) {
                              setState(() => agreeToTerms = v ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              "I agree to the Terms of Service and Privacy Policy",
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),

                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading || !agreeToTerms
                              ? null
                              : () => _signup(context),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(14)),
                            ),
                            child: Center(
                              child: loading
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Create Account",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Already have an account? Sign in",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.neutral100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _pwCtl.dispose();
    _confirmPwCtl.dispose();
    super.dispose();
  }
}

