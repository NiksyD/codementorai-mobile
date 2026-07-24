import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Animated Organic Ambient Blob Background Widget
class AnimatedBlobBackground extends StatefulWidget {
  const AnimatedBlobBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedBlobBackground> createState() => _AnimatedBlobBackgroundState();
}

class _AnimatedBlobBackgroundState extends State<AnimatedBlobBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double value = _controller.value;
        final double sinVal = math.sin(value * 2 * math.pi);
        final double cosVal = math.cos(value * 2 * math.pi);

        return Stack(
          children: <Widget>[
            // Solid Base Surface
            Container(
              color: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
            ),

            // Top-Right Glowing Primary Indigo Blob
            Positioned(
              top: -60 + (30 * sinVal),
              right: -80 + (40 * cosVal),
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                      AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.08),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Bottom-Left Glowing Ambient Violet/Cyan Blob
            Positioned(
              bottom: -80 + (40 * cosVal),
              left: -80 + (30 * sinVal),
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.accent.withValues(alpha: isDark ? 0.3 : 0.15),
                      AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Center Ambient Pulsing Glow
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35 + (20 * sinVal),
              left: MediaQuery.of(context).size.width * 0.2 + (20 * cosVal),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Screen Content Child
            widget.child,
          ],
        );
      },
    );
  }
}
