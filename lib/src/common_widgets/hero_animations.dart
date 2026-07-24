import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// 0. Simple & Minimal Animated Logo Stage for Splash Screen
class AILogoSplashStage extends StatefulWidget {
  const AILogoSplashStage({super.key});

  @override
  State<AILogoSplashStage> createState() => _AILogoSplashStageState();
}

class _AILogoSplashStageState extends State<AILogoSplashStage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double value = _controller.value;
        return SizedBox(
          width: 140,
          height: 140,
          child: Center(
            child: Transform.scale(
              scale: 1.0 + (0.05 * value),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.35 + (0.1 * value),
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 1. AI Mentor Chat & Pair-Programming Stage (1st Onboarding)
class AIMentorChatHeroStage extends StatefulWidget {
  const AIMentorChatHeroStage({super.key});

  @override
  State<AIMentorChatHeroStage> createState() => _AIMentorChatHeroStageState();
}

class _AIMentorChatHeroStageState extends State<AIMentorChatHeroStage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double value = _controller.value;
        return SizedBox(
          width: 230,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Main Chat Card Container
              Container(
                width: 220,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceCard,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Header Bar with AI Status
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI Mentor',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // User Message Bubble (Right)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'How do I optimize lookup?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // AI Response Bubble (Left)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                'Use HashMap for O(1) speed ',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.bolt_rounded,
                              size: 12,
                              color: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Floating Pulse Tag
              Positioned(
                top: 10 + (6 * math.sin(value * math.pi)),
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        '24/7 Pair AI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 2. Interactive Code Sandbox Stage (2nd Onboarding)
class CodeSandboxHeroStage extends StatefulWidget {
  const CodeSandboxHeroStage({super.key});

  @override
  State<CodeSandboxHeroStage> createState() => _CodeSandboxHeroStageState();
}

class _CodeSandboxHeroStageState extends State<CodeSandboxHeroStage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double value = _controller.value;
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Terminal Window Card
              Container(
                width: 190,
                height: 150,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceCard,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Terminal Top Dots
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Code Lines
                    Container(
                      width: 100 + (30 * value),
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 70 + (40 * (1 - value)),
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 50,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.darkTextSecondary.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Blinking Cursor
                        Opacity(
                          opacity: value > 0.5 ? 1.0 : 0.0,
                          child: Container(
                            width: 8,
                            height: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 3. Skill Radar Grid & Performance Analytics Stage (3rd Onboarding)
class SkillRadarGridHeroStage extends StatefulWidget {
  const SkillRadarGridHeroStage({super.key});

  @override
  State<SkillRadarGridHeroStage> createState() =>
      _SkillRadarGridHeroStageState();
}

class _SkillRadarGridHeroStageState extends State<SkillRadarGridHeroStage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double value = _controller.value;
        return SizedBox(
          width: 230,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Pentagon Polygon Radar Grid Painter
              CustomPaint(
                size: const Size(200, 180),
                painter: _RadarPolygonPainter(progress: value),
              ),

              // Animated Mastery Badge
              Positioned(
                bottom: 10,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.insights_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(85 + (10 * value)).toInt()}% Mastery',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RadarPolygonPainter extends CustomPainter {
  _RadarPolygonPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2.2;
    const int numSides = 5;

    final Paint gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw Grid Concentric Polygons
    for (int step = 1; step <= 3; step++) {
      final double r = radius * (step / 3);
      final Path path = Path();
      for (int i = 0; i < numSides; i++) {
        final double angle = (i * 2 * math.pi / numSides) - (math.pi / 2);
        final double x = center.dx + r * math.cos(angle);
        final double y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Draw Skill Area Shape
    final Paint fillPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3 + (0.1 * progress))
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Path skillPath = Path();
    final List<double> factors = <double>[
      0.9,
      0.75 + (0.15 * progress),
      0.85,
      0.7 + (0.2 * progress),
      0.95,
    ];

    for (int i = 0; i < numSides; i++) {
      final double angle = (i * 2 * math.pi / numSides) - (math.pi / 2);
      final double r = radius * factors[i];
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        skillPath.moveTo(x, y);
      } else {
        skillPath.lineTo(x, y);
      }
    }
    skillPath.close();
    canvas.drawPath(skillPath, fillPaint);
    canvas.drawPath(skillPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPolygonPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
