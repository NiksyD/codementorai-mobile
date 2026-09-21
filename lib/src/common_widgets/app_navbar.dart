import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class NavItemData {
  const NavItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class AppNavbar extends StatelessWidget {
  const AppNavbar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  static const List<NavItemData> items = <NavItemData>[
    NavItemData(
      label: 'Dashboard',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    NavItemData(
      label: 'Modules',
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers_rounded,
    ),
    NavItemData(
      label: 'My Activity',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
    ),
    NavItemData(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color slateColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color activeColor = AppColors.primary;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.85)
                    : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SizedBox(
              height: 58.0,
              child: Row(
                children: List<Widget>.generate(items.length, (int index) {
                  final NavItemData item = items[index];
                  final bool isSelected = selectedIndex == index;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onItemSelected(index);
                      },
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AnimatedScale(
                            scale: isSelected ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 22.0,
                              color: isSelected ? activeColor : slateColor,
                            ),
                          ),
                          const SizedBox(height: 3.5),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? activeColor : slateColor,
                              letterSpacing: -0.1,
                            ),
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 3.0),
                          // Subtle active indicator micro-dot
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: isSelected ? 4.0 : 0.0,
                            height: isSelected ? 4.0 : 0.0,
                            decoration: BoxDecoration(
                              color: isSelected ? activeColor : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.6),
                                        blurRadius: 4.0,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
