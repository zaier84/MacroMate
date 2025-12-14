import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:onboarding/screens/login_screen.dart';
import 'package:onboarding/services/auth_service.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final Map<String, dynamic> user = {
    "name": "Zaier Ahmad",
    "email": "zaier@example.com",
    "isPro": false,
    "streak": 12,
  };

  final List<Map<String, dynamic>> quickActions = [
    {
      "title": "Notifications",
      "icon": FontAwesomeIcons.bell,
      "description": "Meal and workout reminders",
    },
    {
      "title": "Privacy",
      "icon": FontAwesomeIcons.eye,
      "description": "Data sharing settings",
    },
    {
      "title": "Upgrade",
      "icon": FontAwesomeIcons.crown,
      "description": "Unlock AI features",
      "highlight": true,
    },
  ];

  // void _handleSignOut(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: true,
  //     builder: (context) {
  //       return AlertDialog(
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //         title: const Text("Sign out"),
  //         content: const Text(
  //           "Are you sure you want to sign out of your account?",
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text("Cancel"),
  //           ),
  //           ElevatedButton(
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.red,
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(10),
  //               ),
  //             ),
  //             onPressed: () {
  //               Navigator.pop(context);
  //
  //               // --------------------------------------------------
  //               // TODO (later):
  //               // - Clear auth token
  //               // - Clear local storage / secure storage
  //               // - Call backend logout
  //               // --------------------------------------------------
  //
  //               // Temporary mock logout navigation
  //               Navigator.of(context).pushAndRemoveUntil(
  //                 MaterialPageRoute(builder: (_) => const LoginScreen()),
  //                 (route) => false,
  //               );
  //             },
  //             child: const Text(
  //               "Sign Out",
  //               style: TextStyle(color: Colors.white),
  //             ),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _showSignOutError(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? "Failed to sign out."),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleSignOut(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Sign out"),
          content: const Text(
            "Are you sure you want to sign out of your account?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  // Firebase Sign Out
                  await AuthService().signOut();

                  // Navigate to Login & clear stack
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  _showSignOutError(context, e.message);
                } catch (e) {
                  _showSignOutError(
                    context,
                    "Something went wrong while signing out.",
                  );
                }
              },
              child: const Text(
                "Sign Out",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ------------------------------------------------------
            //                     HEADER (FULL WIDTH)
            // ------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              // decoration: BoxDecoration(gradient: AppColors.brandGradient),
              child: Center(
                child: Text(
                  "Profile",
                  style: AppTextStyles.heading.copyWith(color: Colors.black),
                ),
              ),
            ),

            // ------------------------------------------------------
            //               CONTENT SCROLL VIEW
            // ------------------------------------------------------
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ------------------------------------------------------
                    //                     USER CARD
                    // ------------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cardBorderDefault,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.04),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                user["name"].split(" ").map((n) => n[0]).join(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // User info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user["name"],
                                  style: AppTextStyles.title.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user["email"],
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    // Subscription Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: user["isPro"]
                                            ? Colors.green.withOpacity(0.1)
                                            : AppColors.neutral100,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: user["isPro"]
                                              ? Colors.green.withOpacity(0.3)
                                              : AppColors.cardBorderDefault,
                                        ),
                                      ),
                                      child: Text(
                                        user["isPro"]
                                            ? "Pro Member"
                                            : "Free Plan",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: user["isPro"]
                                              ? Colors.green
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Streak badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        "🔥 ${user["streak"]} day streak",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            FontAwesomeIcons.chevronRight,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ------------------------------------------------------
                    //                    QUICK ACTIONS
                    // ------------------------------------------------------
                    Text(
                      "Quick Actions",
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorderDefault),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: quickActions.map((action) {
                          bool highlight = action["highlight"] == true;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: highlight
                                      ? AppColors.brandGradient
                                      : null,
                                  border: highlight
                                      ? null
                                      : Border.all(
                                          color: AppColors.cardBorderDefault,
                                        ),
                                ),
                                child: Icon(
                                  action["icon"],
                                  size: 22,
                                  color: highlight
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                action["title"],
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                action["description"],
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ------------------------------------------------------
                    //                  SETTINGS SECTIONS
                    // ------------------------------------------------------
                    Text(
                      "Settings",
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _settingsCard(
                      icon: FontAwesomeIcons.user,
                      title: "Profile Overview",
                      subtitle: "Personal info, stats & bio",
                    ),
                    _settingsCard(
                      icon: FontAwesomeIcons.gear,
                      title: "Preferences",
                      subtitle: "Units, theme & notifications",
                    ),
                    _settingsCard(
                      icon: FontAwesomeIcons.shield,
                      title: "Security & Privacy",
                      subtitle: "Passwords, biometrics & data",
                    ),
                    _settingsCard(
                      icon: FontAwesomeIcons.phone,
                      title: "Connected Apps",
                      subtitle: "Health app integrations",
                      badge: "3 connected",
                    ),
                    _settingsCard(
                      icon: FontAwesomeIcons.creditCard,
                      title: "Subscription",
                      subtitle: user["isPro"]
                          ? "Manage Pro features"
                          : "Upgrade to Pro",
                      badge: user["isPro"] ? "Pro" : "Free",
                      badgeColor: user["isPro"]
                          ? Colors.green
                          : AppColors.textSecondary,
                    ),
                    _settingsCard(
                      icon: FontAwesomeIcons.info,
                      title: "About & Legal",
                      subtitle: "Version · Changelog · Legal",
                    ),

                    const SizedBox(height: 30),

                    // ------------------------------------------------------
                    //                      SIGN OUT BUTTON
                    // ------------------------------------------------------
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleSignOut(context),
                        icon: const Icon(
                          FontAwesomeIcons.arrowRightFromBracket,
                          size: 18,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Sign Out",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ------------------------------------------------------
                    //                     APP INFO CARD
                    // ------------------------------------------------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorderDefault),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "MacroMate v2.1.4",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Your AI-powered health companion",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------
  //            SETTINGS CARD WIDGET BUILDER
  // ------------------------------------------------------
  Widget _settingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.brandPrimary),
          ),
          const SizedBox(width: 16),

          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              badgeColor?.withOpacity(0.12) ??
                              AppColors.neutral100,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 11,
                            color: badgeColor ?? AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            FontAwesomeIcons.chevronRight,
            size: 18,
            color: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}
