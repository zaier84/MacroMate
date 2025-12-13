import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Theme constants (matching your onboarding screens)
  static const backgroundColor = Color(0xFFF5F5F7); // neutral-50 (unused here)
  static const headerTextColor = Color(0xFF111827); // text-primary
  static const neutralTextColor = Color(0xFF6B7280); // neutral-600
  static const primaryGradientStart = Color(0xFF2563EB);
  static const primaryGradientEnd = Color(0xFF06B6D4);
  static const cardBorderDefault = Color(0xFFE5E7EB);

  // late final AnimationController _controller;
  late final AnimationController _introController;
  late final AnimationController _dotController;

  // Logo scale (spring-like)
  late final Animation<double> _logoScale;

  // Title / tagline entrance animations
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _tagFade;
  late final Animation<Offset> _tagOffset;

  // loader controller drives three-dot animation
  // we'll reuse the single controller with staggered offsets for dots
  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Setup intro animations using _introController
    _logoScale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.08), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 40),
      ],
    ).animate(CurvedAnimation(parent: _introController, curve: Curves.easeOut));

    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _titleOffset = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
          ),
        );

    _tagFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    );
    _tagOffset = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
          ),
        );

    // Play the intro animation once
    _introController.forward().whenComplete(() {
      widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    // _controller.dispose();
    _introController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  // helper to get staggered scale for each dot
  double _dotScaleForIndex(int index, double t) {
    const int dotCount = 3;
    // phase offset so dots pulse sequentially left->right
    final shift = index / dotCount; // 0.0, 0.333..., 0.666...
    // shifted time in [0,1)
    double x = (t - shift) % 1.0;
    if (x < 0) x += 1.0;

    // create a triangular pulse: 0 -> 1 -> 0 over interval [0,1)
    // center the peak at x = 0.0 (so shift aligns peak positions)
    // map x in [0,1) to pulse p in [0,1]:
    //   if x <= 0.5 -> p = x * 2
    //   else -> p = (1 - x) * 2
    double p;
    if (x <= 0.5) {
      p = x * 2.0;
    } else {
      p = (1.0 - x) * 2.0;
    }

    // optional ease for smoother look (comment out if you want linear)
    p = Curves.easeInOut.transform(p);

    // map pulse to scale range (example: 0.9 .. 1.25)
    const double minScale = 0.9;
    const double maxScale = 1.25;
    return minScale + (maxScale - minScale) * p;
  }

  // opacity for dot using same linear pulse
  double _dotOpacityForIndex(int index, double t) {
    const int dotCount = 3;
    final shift = index / dotCount;
    double x = (t - shift) % 1.0;
    if (x < 0) x += 1.0;

    double p;
    if (x <= 0.5) {
      p = x * 2.0;
    } else {
      p = (1.0 - x) * 2.0;
    }

    // make opacity vary between 0.5 .. 1.0
    p = Curves.easeInOut.transform(p);
    return 0.5 + 0.5 * p;
  }

  @override
  Widget build(BuildContext context) {
    // make layout responsive
    final mq = MediaQuery.of(context);
    final logoSize = math.min(mq.size.width, 140.0);

    return Scaffold(
      // background gradient as in TSX: from-brand-primary to-brand-secondary
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryGradientStart, primaryGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _dotController]),
              builder: (context, _) {
                final t = _dotController.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo container with subtle white overlay (like TSX)
                    Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: logoSize * 0.75,
                        height: logoSize * 0.75,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          shape: BoxShape.circle,
                          // subtle blur/overlay can't be done without BackdropFilter here,
                          // but this mimics the look with opacity.
                        ),
                        child: Center(
                          child: Text(
                            'M',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: logoSize * 0.32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // App name (fade + slide)
                    SlideTransition(
                      position: _titleOffset,
                      child: Opacity(
                        opacity: _titleFade.value,
                        child: Text(
                          'MacroMate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    SlideTransition(
                      position: _tagOffset,
                      child: Opacity(
                        opacity: _tagFade.value,
                        child: Text(
                          'Your AI-powered health companion',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Loader dots (three animated dots)
                    SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final scale = _dotScaleForIndex(i, t);
                          final opacity = _dotOpacityForIndex(i, t);
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                            ),
                            child: Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: opacity,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.78),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // NOTE: Debug button removed by default; if you want a debug button
                    // to clear data during development, add a small TextButton below.
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
