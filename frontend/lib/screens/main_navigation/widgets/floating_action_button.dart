import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:onboarding/screens/meal/manual_meal_screen.dart';
import 'package:onboarding/screens/meal/snap_meal_screen.dart';
import 'package:onboarding/screens/water/water_log_screen.dart';
import 'package:onboarding/screens/weight/weight_log_screen.dart';

class FloatingActionButtonMenu extends StatefulWidget {
  const FloatingActionButtonMenu({super.key});

  @override
  State<FloatingActionButtonMenu> createState() =>
      _FloatingActionButtonMenuState();
}

class _FloatingActionButtonMenuState extends State<FloatingActionButtonMenu>
    with SingleTickerProviderStateMixin {
  final GlobalKey _fabKey = GlobalKey(); // <-- Key for positioning
  OverlayEntry? _overlayEntry;
  late AnimationController _controller;

  bool _menuOpen = false;
  final double _menuWidth = 200;

  final List<Map<String, dynamic>> _items = [
    {'id': 'snap-meal', 'label': 'Snap Meal', 'icon': FontAwesomeIcons.camera},
    {
      'id': 'manual-meal',
      'label': 'Manual Meal',
      'icon': FontAwesomeIcons.pencil,
    },
    // {
    //   'id': 'cheat-meal-balance',
    //   'label': 'Cheat Meal Balance',
    //   'icon': FontAwesomeIcons.wandMagicSparkles,
    // },
    {
      'id': 'add-weight',
      'label': 'Add Weight',
      'icon': FontAwesomeIcons.weightScale,
    },
    {'id': 'log-water', 'label': 'Log Water', 'icon': FontAwesomeIcons.droplet},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _showMenu() {
    final RenderBox renderBox =
        _fabKey.currentContext!.findRenderObject() as RenderBox;
    final Offset fabPosition = renderBox.localToGlobal(Offset.zero);
    final double fabWidth = renderBox.size.width;

    const double itemHeight = 52;
    const double itemSpacing = 12;
    final int itemCount = _items.length;

    final double totalHeight =
        itemCount * itemHeight + (itemCount - 1) * itemSpacing;

    final double top = fabPosition.dy - totalHeight - 12;
    final double left = fabPosition.dx + (fabWidth / 2) - (_menuWidth / 2);

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: closeMenu,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              top: top,
              left: left,
              width: _menuWidth,
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: _controller,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutBack,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: _items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () {
                              _handleItemTap(item['id']);
                            },
                            child: Container(
                              height: itemHeight,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['label'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    item['icon'],
                                    size: 16,
                                    color: Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _controller.forward();
    _menuOpen = true;
  }

  void _handleItemTap(String id) {
    closeMenu();

    switch (id) {
      case 'manual-meal':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManualMealScreen()),
        );
        break;
      case 'snap-meal':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SnapMealScreen()),
        );
        break;
      // case 'cheat-meal-balance':
      case 'add-weight':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WeightLogScreen()),
        );
        break;
      case 'log-water':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WaterLogScreen()),
        );
        break;
        // Handle other taps here
        break;
    }
  }

  void openMenu() {
    if (!_menuOpen) _showMenu();
  }

  void closeMenu() {
    if (!_menuOpen) return;
    _controller.reverse();
    Future.delayed(const Duration(milliseconds: 220), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _menuOpen = false;
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _fabKey, // <-- assign the key here
      onTap: openMenu,
      child: Container(
        height: 56,
        width: 56,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
