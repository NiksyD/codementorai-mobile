import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class FilterTabItem {
  const FilterTabItem({
    required this.id,
    required this.label,
    this.count,
  });

  final String id;
  final String label;
  final int? count;
}

/// Unified signature filter tab bar matching the emerald capsule design.
class FilterTabBar extends StatelessWidget {
  const FilterTabBar({
    super.key,
    required this.tabs,
    required this.selectedId,
    required this.onTabSelected,
    this.height = 36.0,
    this.padding = EdgeInsets.zero,
  });

  final List<FilterTabItem> tabs;
  final String selectedId;
  final ValueChanged<String> onTabSelected;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 6.0),
        itemBuilder: (BuildContext context, int index) {
          final FilterTabItem tab = tabs[index];
          final bool isSelected = selectedId == tab.id;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(tab.id);
              },
              borderRadius: BorderRadius.circular(20.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12))
                      : (isDark ? AppColors.darkSurfaceCard : Colors.white),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : borderColor,
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tab.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark
                                ? AppColors.primary
                                : AppColors.primaryVariant)
                            : textSecondary,
                      ),
                    ),
                    if (tab.count != null && tab.count! >= 0) ...<Widget>[
                      const SizedBox(width: 4.5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.0,
                          vertical: 1.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurfaceCard),
                          borderRadius: BorderRadius.circular(999.0),
                        ),
                        child: Text(
                          '${tab.count}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isDark
                                    ? AppColors.primary
                                    : AppColors.primaryVariant)
                                : textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
