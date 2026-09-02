import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

class HeatmapDayData {
  const HeatmapDayData({
    required this.date,
    required this.formattedDate,
    required this.count,
    required this.level, // 0 to 3
  });

  final String date;
  final String formattedDate;
  final int count;
  final int level;
}

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    this.totalActiveDays = 28,
    this.currentStreak = 3,
    this.weeksCount = 16,
  });

  final int totalActiveDays;
  final int currentStreak;
  final int weeksCount;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  HeatmapDayData? _selectedDay;

  late final List<List<HeatmapDayData>> _weeks;

  static const List<String> _monthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _weeks = _generateActivityData(widget.weeksCount);
  }

  List<List<HeatmapDayData>> _generateActivityData(int countWeeks) {
    final List<List<HeatmapDayData>> weeks = <List<HeatmapDayData>>[];
    final DateTime today = DateTime.now();

    for (int w = countWeeks - 1; w >= 0; w--) {
      final List<HeatmapDayData> weekDays = <HeatmapDayData>[];
      for (int d = 6; d >= 0; d--) {
        final DateTime dayDate = today.subtract(Duration(days: (w * 7 + d)));
        final bool isRecent = w <= 3;
        final int weekday = dayDate.weekday;
        final bool isWeekend =
            weekday == DateTime.saturday || weekday == DateTime.sunday;

        int count = 0;
        if (isRecent && !isWeekend && (d % 2 == 0 || d == 1)) {
          count = ((d + w) % 4) + 1;
        } else if (w % 3 == 0 && d == 2) {
          count = 2;
        } else if (w % 2 == 1 && d % 3 == 0) {
          count = 1;
        }

        final int level = count == 0 ? 0 : count <= 1 ? 1 : count <= 3 ? 2 : 3;
        final String formatted =
            '${_monthNames[dayDate.month - 1]} ${dayDate.day}, ${dayDate.year}';

        weekDays.add(
          HeatmapDayData(
            date: dayDate.toIso8601String().split('T').first,
            formattedDate: formatted,
            count: count,
            level: level,
          ),
        );
      }
      weeks.add(weekDays);
    }
    return weeks;
  }

  Color _getCellColor(int level, bool isDark) {
    switch (level) {
      case 1:
        return const Color(0xFF3ECF8E).withValues(alpha: 0.35);
      case 2:
        return const Color(0xFF3ECF8E).withValues(alpha: 0.65);
      case 3:
        return const Color(0xFF3ECF8E);
      default:
        return isDark
            ? AppColors.darkSurface.withValues(alpha: 0.7)
            : AppColors.lightSurfaceCard.withValues(alpha: 0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Title and Time Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 15.0,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Practice Activity',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                'Last ${widget.weeksCount} Weeks',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Edge-to-Edge Responsive Grid
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double availableWidth = constraints.maxWidth;
              final int numWeeks = _weeks.length;
              // Calculate responsive cell size based on container width
              const double gap = 3.5;
              final double calculatedCellSize =
                  ((availableWidth - ((numWeeks - 1) * gap)) / numWeeks)
                      .clamp(12.0, 20.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _weeks.map((List<HeatmapDayData> week) {
                  return Column(
                    children: week.map((HeatmapDayData day) {
                      final bool isSelected = _selectedDay?.date == day.date;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDay = isSelected ? null : day;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(vertical: 2.0),
                          width: calculatedCellSize,
                          height: calculatedCellSize,
                          decoration: BoxDecoration(
                            color: _getCellColor(day.level, isDark),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : (day.level > 0
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : (isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder)),
                              width: isSelected ? 1.5 : 0.8,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12.0),

          // Selected Tooltip or Legend
          if (_selectedDay != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _selectedDay!.formattedDate,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    _selectedDay!.count == 0
                        ? 'No submissions'
                        : '${_selectedDay!.count} challenges solved',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.0,
                      color: _selectedDay!.count > 0
                          ? AppColors.primary
                          : textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '${widget.totalActiveDays} active days this quarter',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.0,
                    color: textSecondary,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Text(
                      'Less',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.0,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    ...List<Widget>.generate(4, (int lvl) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 9.0,
                        height: 9.0,
                        decoration: BoxDecoration(
                          color: _getCellColor(lvl, isDark),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      );
                    }),
                    const SizedBox(width: 4.0),
                    Text(
                      'More',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.0,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
