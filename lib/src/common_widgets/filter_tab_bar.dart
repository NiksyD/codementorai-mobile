import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class FilterTabItem {
  const FilterTabItem({required this.id, required this.label, this.count});

  final String id;
  final String label;
  final int? count;
}

/// Plain text filters. The selected one is bold and underlined; the rest are muted.
/// Same pattern as the switches on the web.
class FilterTabBar extends StatelessWidget {
  const FilterTabBar({
    super.key,
    required this.tabs,
    required this.selectedId,
    required this.onTabSelected,
    this.height = 44.0,
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
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 20.0),
        itemBuilder: (BuildContext context, int index) {
          final FilterTabItem tab = tabs[index];
          final bool isSelected = selectedId == tab.id;

          return Semantics(
            button: true,
            selected: isSelected,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(tab.id);
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? textPrimary : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tab.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? textPrimary : textSecondary,
                      ),
                    ),
                    if (tab.count != null && tab.count! >= 0) ...<Widget>[
                      const SizedBox(width: 5.0),
                      Text(
                        '${tab.count}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.0,
                          color: textSecondary,
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
