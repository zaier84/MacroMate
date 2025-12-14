import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Notif {
  String id;
  String title;
  String description;
  IconData icon;
  bool enabled;
  String time; // "HH:mm"
  Color color;
  _Notif({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.time,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'enabled': enabled,
    'time': time,
  };
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Theme constants (consistent with earlier screens)
  static const backgroundColor = Color(0xFFF5F5F7);
  static const headerTextColor = Color(0xFF111827);
  static const neutralTextColor = Color(0xFF6B7280);
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  bool _loading = true;
  bool _saving = false;

  // Notification model

  // initial notification list
  late List<_Notif> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = [
      _Notif(
        id: 'meal_logging',
        title: 'Meal Logging Reminders',
        description: 'Gentle reminders to log your meals',
        icon: Icons.notifications,
        enabled: true,
        time: '12:00',
        color: const Color(0xFF2563EB),
      ),
      _Notif(
        id: 'water_intake',
        title: 'Water Intake Reminders',
        description: 'Stay hydrated throughout the day',
        icon: Icons.invert_colors,
        enabled: true,
        time: '09:00',
        color: const Color(0xFF06B6D4),
      ),
      _Notif(
        id: 'daily_checkin',
        title: 'Daily Check-ins',
        description: 'Review your progress and plan ahead',
        icon: Icons.access_time,
        enabled: false,
        time: '20:00',
        color: const Color(0xFF10B981),
      ),
      _Notif(
        id: 'motivational',
        title: 'Motivational Messages',
        description: 'Encouraging tips and insights',
        icon: Icons.chat_bubble,
        enabled: false,
        time: '08:00',
        color: const Color(0xFF8B5CF6),
      ),
    ];
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('macromate_notifications');
      if (raw != null) {
        final parsed = jsonDecode(raw) as Map<String, dynamic>;
        final map = parsed['notifications'] as Map<String, dynamic>? ?? {};
        for (var i = 0; i < _notifications.length; i++) {
          final id = _notifications[i].id;
          if (map.containsKey(id)) {
            final entry = map[id] as Map<String, dynamic>;
            _notifications[i].enabled = (entry['enabled'] == true);
            _notifications[i].time =
                (entry['time']?.toString() ?? _notifications[i].time);
          }
        }
      }
    } catch (_) {
      // ignore parse errors
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndContinue() async {
    setState(() => _saving = true);

    final notificationData = {
      // BACKEND EXPECTATIONS
      //   "notifications": {
      //   "meal_logging": {"enabled": true, "time": "12:00"},
      //   "water_intake": {"enabled": true, "time": "09:00"},
      //   "daily_checkin": {"enabled": false, "time": "20:00"}
      // }
      'notifications': {
        for (final n in _notifications)
          n.id: {'enabled': n.enabled, 'time': n.time},
      },
    };

    // debugPrint("NOTIFICATION: ");
    // debugPrint(notificationData.toString());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'onboarding_notifications',
      jsonEncode(notificationData),
    );

    setState(() => _saving = false);

    if (!mounted) return;
    // Navigator.of(context).pushNamed('/onboarding/health-integrations');
    widget.onContinue();
  }

  void _toggleNotification(String id) {
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) _notifications[idx].enabled = !_notifications[idx].enabled;
    });
  }

  Future<void> _pickTime(int index) async {
    final current = _notifications[index].time;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 12,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() => _notifications[index].time = '$hh:$mm');
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _notifications.where((n) => n.enabled).length;

    if (_loading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // intro
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
                              Icons.notifications,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Set up reminders',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: headerTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Choose helpful reminders to stay on track with your health goals. You can adjust these anytime.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: neutralTextColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Notification list
                    Column(
                      children: List.generate(_notifications.length, (index) {
                        final n = _notifications[index];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorderDefault),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        n.icon,
                                        color: n.color,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: headerTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.description,
                                          style: const TextStyle(
                                            color: neutralTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: n.enabled,
                                    onChanged: (_) => _toggleNotification(n.id),
                                    activeColor: primaryGradientStart,
                                  ),
                                ],
                              ),

                              if (n.enabled) ...[
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () => _pickTime(index),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 52,
                                      ), // align with icon
                                      const Text(
                                        'Time:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: headerTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color(0xFFEAEFF6),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          n.time,
                                          style: const TextStyle(
                                            color: headerTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 12),

                    // Summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '📱 Notification Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              text: 'You\'ve enabled ',
                              style: const TextStyle(color: neutralTextColor),
                              children: [
                                TextSpan(
                                  text: '$enabledCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: headerTextColor,
                                  ),
                                ),
                                TextSpan(
                                  text: enabledCount != 1
                                      ? ' reminders.'
                                      : ' reminder.',
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (enabledCount == 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                              child: const Text(
                                '💡 Consider enabling at least meal logging reminders to help build healthy habits.',
                                style: TextStyle(color: Color(0xFF92400E)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Privacy note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderDefault),
                      ),
                      child: Column(
                        children: const [
                          Text(
                            '🔒 Privacy & Control',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All notifications are local to your device. You can turn them on or off anytime in Settings. We respect your preferences and won\'t spam you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: neutralTextColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: primaryGradientStart,
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
                                  strokeWidth: 2,
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

                    const SizedBox(height: 28),
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
