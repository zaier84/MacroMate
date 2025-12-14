import 'package:flutter/material.dart';
import 'package:onboarding/screens/diary/diary_screen.dart';
import 'package:onboarding/screens/home/home_screen.dart';
import 'package:onboarding/screens/main_navigation/widgets/floating_action_button.dart';
import 'package:onboarding/screens/profile/profile_screen.dart';
import 'package:onboarding/screens/progress/progress_screen.dart';
import '../../theme/colors.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiaryScreen(),
    const ProgressScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      extendBody: true, // keep body drawn behind bottom area
      // remove bottomNavigationBar and render a custom bar via overlay
      body: Stack(
        children: [
          // 1) Your main content
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            children: _screens,
          ),

          // 2) The custom notched bottom bar painted above the PageView
          //    We position it at the bottom and let it show transparent hole.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 72,
                child: CustomPaint(
                  // painter clears the notch using BlendMode.clear
                  painter: _BottomBarNotchPainter(
                    barColor: Colors.white,
                    notchRadius: 40, // notch radius (FAB radius + margin)
                    // notchRadius: 34, // notch radius (FAB radius + margin)
                    borderRadius: 20,
                    shadowColor: Colors.black.withOpacity(0.06),
                  ),
                  child: SizedBox(
                    height: 72,
                    // The content (nav items) should be inside an IgnorePointer=false area
                    // so taps are handled. We align nav items left/right and leave center gap.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          height: 64,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // LEFT GROUP
                              Row(
                                children: [
                                  _buildNavItem(
                                    icon: Icons.home_outlined,
                                    label: "Home",
                                    index: 0,
                                  ),
                                  _buildNavItem(
                                    icon: Icons.book_outlined,
                                    label: "Diary",
                                    index: 1,
                                  ),
                                ],
                              ),

                              // CENTER GAP width must match FAB + margin so bar has hole
                              const SizedBox(width: 88),

                              // RIGHT GROUP
                              Row(
                                children: [
                                  _buildNavItem(
                                    icon: Icons.show_chart_outlined,
                                    label: "Progress",
                                    index: 2,
                                  ),
                                  _buildNavItem(
                                    icon: Icons.person_outlined,
                                    label: "Profile",
                                    index: 3,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Replace your existing FAB Positioned block with this
          // Positioned(
          //   bottom: 0, // anchor to bottom of screen
          //   left: 0,
          //   right: 0,
          //   // make this container tall enough to contain the menu when expanded
          //   height: 300, // <-- increase if your menu needs more space
          //   child: IgnorePointer(
          //     ignoring: false,
          //     child: Align(
          //       alignment: Alignment.bottomCenter,
          //       child: Padding(
          //         padding: const EdgeInsets.only(
          //           bottom: 16.0,
          //         ), // visually lift the FAB
          //         child: SizedBox(
          //           // Do NOT limit height here — let the parent height allow menu to appear
          //           width: 56,
          //           // NOTE: Do not wrap FloatingActionButtonMenu in another SizedBox(height:56)
          //           // because it will re-constrain the menu's hit area.
          //           child: const FloatingActionButtonMenu(),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          // 3) The floating button (placed above the custom painted bar)
          //    A small top padding pushes it a little down into the notch visually.
          Positioned(
            bottom: 40, // push FAB a little down (tweak this)
            left: 0,
            right: 0,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 0),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: GestureDetector(
                    onTap: () {
                      // forward to your FloatingActionButtonMenu logic
                      // If your FloatingActionButtonMenu is a standalone widget that
                      // handles its own animation and menu, use it directly instead:
                    },
                    child: const FloatingActionButtonMenu(), // your widget
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return MaterialButton(
      minWidth: 64,
      onPressed: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.brandPrimary : Colors.grey,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppColors.brandPrimary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class BottomBarNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double fabRadius = 28; // FAB is 56
    const double notchRadius = fabRadius + 8;

    final centerX = size.width / 2;
    final centerY = 0.0;

    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(20),
        ),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: notchRadius),
      );

    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(20),
        ),
      ),
      Path()..addOval(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: notchRadius),
      ),
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class TransparentCircularNotchedRectangle extends NotchedShape {
  const TransparentCircularNotchedRectangle();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || guest.isEmpty) {
      return Path()..addRect(host);
    }

    const double notchMargin = 6;
    final double fabRadius = guest.width / 2;
    final double notchRadius = fabRadius + notchMargin;

    final Path fullBar = Path()..addRect(host);

    // Circular transparent notch
    final Path notch = Path()
      ..addOval(Rect.fromCircle(center: guest.center, radius: notchRadius));

    return Path.combine(PathOperation.difference, fullBar, notch);
  }
}

class _BottomBarNotchPainter extends CustomPainter {
  final Color barColor;
  final double notchRadius;
  final double borderRadius;
  final Color shadowColor;

  _BottomBarNotchPainter({
    required this.barColor,
    required this.notchRadius,
    required this.borderRadius,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // The top center of the bar is where we want the notch center.
    final Offset notchCenter = Offset(width / 2, 0);

    // 1) draw shadow under bar
    final Path roundedRectPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, width, height),
          Radius.circular(borderRadius),
        ),
      );

    // Draw shadow by painting a blurred rect slightly above the bar
    final Paint shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.save();
    canvas.translate(
      0,
      -2,
    ); // shadow offset slightly upward so it sits above bottom
    canvas.drawPath(roundedRectPath, shadowPaint);
    canvas.restore();

    // 2) For clearing the notch, draw into a separate layer and then clear a circle.
    final Paint paint = Paint();
    final Rect layerRect = Rect.fromLTWH(0, 0, width, height);
    canvas.saveLayer(layerRect, Paint());

    // draw the rounded white bar
    final Paint barPaint = Paint()..color = barColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(layerRect, Radius.circular(borderRadius)),
      barPaint,
    );

    // clear the circular notch using BlendMode.clear
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    canvas.drawCircle(notchCenter, notchRadius, clearPaint);

    // commit
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BottomBarNotchPainter oldDelegate) {
    return oldDelegate.barColor != barColor ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class BottomNavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 20;
    const double fabRadius = 32; // FAB is 56
    const double notchMargin = 12;
    final double notchRadius = fabRadius + notchMargin;

    final centerX = size.width / 2;
    final centerY = 0.0;

    // Create layer for clear blend mode
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(rect, Paint());

    // Draw rounded bar
    final Paint barPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      barPaint,
    );

    // Clear circular notch
    final Paint clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.drawCircle(Offset(centerX, centerY), notchRadius, clearPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
