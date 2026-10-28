import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'language_icon.dart';

class LanguageAvatarStack extends StatelessWidget {
  const LanguageAvatarStack({
    super.key,
    required this.languages,
    this.size = 24.0,
    this.maxVisible = 3,
    this.overlap = 8.0,
    this.borderColor,
  });

  final List<String> languages;
  final double size;
  final int maxVisible;
  final double overlap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color ringColor = borderColor ??
        (isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard);

    final List<String> uniqueLangs = languages
        .where((String l) => l.trim().isNotEmpty)
        .toSet()
        .toList();

    if (uniqueLangs.isEmpty) {
      return LanguageIcon(language: 'python', size: size, showContainer: false);
    }

    final int visibleCount = uniqueLangs.length > maxVisible ? maxVisible : uniqueLangs.length;
    final List<String> visible = uniqueLangs.sublist(0, visibleCount);
    final int remaining = uniqueLangs.length - visibleCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < visible.length; i++)
          Transform.translate(
            offset: Offset(-i * overlap, 0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border.all(
                  color: ringColor,
                  width: 2.0,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 4.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: LanguageIcon(
                  language: visible[i],
                  size: size - 8.0,
                  showContainer: false,
                ),
              ),
            ),
          ),
        if (remaining > 0)
          Transform.translate(
            offset: Offset(-visible.length * overlap, 0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border.all(
                  color: ringColor,
                  width: 2.0,
                ),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: TextStyle(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
