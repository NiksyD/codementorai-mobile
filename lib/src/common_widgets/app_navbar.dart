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
      label: 'Hubs',
      icon: Icons.hub_outlined,
      activeIcon: Icons.hub_rounded,
    ),
    NavItemData(
      label: 'Activity',
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
    final Color activePillBg = isDark
        ? AppColors.primary.withValues(alpha: 0.20)
        : AppColors.primary.withValues(alpha: 0.12);
    final Color activePillBorder = isDark
        ? AppColors.primary.withValues(alpha: 0.55)
        : AppColors.primary.withValues(alpha: 0.40);
    final Color activeTextColor = isDark ? Colors.white : AppColors.primaryVariant;

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 10.0),
        child: Container(
          height: 60.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36.0),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceCard.withValues(alpha: 0.82)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(36.0),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List<Widget>.generate(items.length, (int index) {
                    final NavItemData item = items[index];
                    final bool isSelected = selectedIndex == index;

                    return Semantics(
                      label: item.label,
                      selected: isSelected,
                      button: true,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onItemSelected(index);
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(24.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 14.0 : 10.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? activePillBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(
                              color: isSelected ? activePillBorder : Colors.transparent,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                isSelected ? item.activeIcon : item.icon,
                                size: 20.0,
                                color: isSelected ? activeColor : slateColor,
                              ),
                              ClipRect(
                                child: AnimatedCrossFade(
                                  firstChild: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const SizedBox(width: 6.0),
                                        Text(
                                          item.label,
                                          maxLines: 1,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w700,
                                            color: activeTextColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  secondChild: const SizedBox.shrink(),
                                  crossFadeState: isSelected
                                      ? CrossFadeState.showFirst
                                      : CrossFadeState.showSecond,
                                  duration: const Duration(milliseconds: 200),
                                  sizeCurve: Curves.easeOutCubic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
