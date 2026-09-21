import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

class HeatmapDayData {
  const HeatmapDayData({
    required this.date,
    required this.formattedDate,
    required this.count,
    required this.level, // 0 to 3
    required this.month,
  });

  final String date;
  final String formattedDate;
  final int count;
  final int level;
  final String month;
}

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    this.totalActiveDays = 28,
    this.currentStreak = 3,
    this.weeksCount = 52,
  });

  final int totalActiveDays;
  final int currentStreak;
  final int weeksCount;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  HeatmapDayData? _selectedDay;
  final ScrollController _scrollController = ScrollController();

  late final List<List<HeatmapDayData>> _weeks;
  late final List<MapEntry<String, int>> _monthPositions;

  static const List<String> _monthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _weeks = _generateActivityData(widget.weeksCount);
    _monthPositions = _calculateMonthPositions(_weeks);

    // Auto-scroll to current week (end) after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<List<HeatmapDayData>> _generateActivityData(int countWeeks) {
    final List<List<HeatmapDayData>> weeks = <List<HeatmapDayData>>[];
    final DateTime today = DateTime.now();

    for (int w = countWeeks - 1; w >= 0; w--) {
      final List<HeatmapDayData> weekDays = <HeatmapDayData>[];
      for (int d = 6; d >= 0; d--) {
        final DateTime dayDate = today.subtract(Duration(days: (w * 7 + d)));
        final bool isRecent = w <= 4;
        final int weekday = dayDate.weekday;
        final bool isWeekend =
            weekday == DateTime.saturday || weekday == DateTime.sunday;

        int count = 0;
        if (isRecent && !isWeekend && (d % 2 == 0 || d == 1)) {
          count = ((d + w) % 4) + 1;
        } else if (w % 4 == 0 && d == 2) {
          count = 2;
        } else if (w % 3 == 1 && d % 3 == 0) {
          count = 1;
        }

        final int level = count == 0 ? 0 : count <= 1 ? 1 : count <= 3 ? 2 : 3;
        final String month = _monthNames[dayDate.month - 1];
        final String formatted =
            '$month ${dayDate.day}, ${dayDate.year}';

        weekDays.add(
          HeatmapDayData(
            date: dayDate.toIso8601String().split('T').first,
            formattedDate: formatted,
            count: count,
            level: level,
            month: month,
          ),
        );
      }
      weeks.add(weekDays);
    }
    return weeks;
  }

  List<MapEntry<String, int>> _calculateMonthPositions(List<List<HeatmapDayData>> weeks) {
    final List<MapEntry<String, int>> positions = <MapEntry<String, int>>[];
    String lastMonth = '';
    for (int i = 0; i < weeks.length; i++) {
      final String m = weeks[i].first.month;
      if (m != lastMonth) {
        positions.add(MapEntry<String, int>(m, i));
        lastMonth = m;
      }
    }
    return positions;
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

    const double cellSize = 11.0;
    const double cellGap = 3.0;
    final double totalGridWidth = _weeks.length * (cellSize + cellGap);

    return Container(
      padding: const EdgeInsets.all(18.0),
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
          // Header: Title and Full Activity History Link (Matching Web 1:1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Practice Activity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/activity');
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Full Activity History',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13.0,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Horizontally scrollable 52-week heatmap grid with month header track
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: totalGridWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Month Labels Header
                  SizedBox(
                    height: 16.0,
                    width: totalGridWidth,
                    child: Stack(
                      children: _monthPositions.map((MapEntry<String, int> entry) {
                        final double leftPos = entry.value * (cellSize + cellGap);
                        return Positioned(
                          left: leftPos,
                          child: Text(
                            entry.key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6.0),

                  // 52-week Grid
                  Row(
                    children: _weeks.map((List<HeatmapDayData> week) {
                      return Padding(
                        padding: const EdgeInsets.only(right: cellGap),
                        child: Column(
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
                                margin: const EdgeInsets.only(bottom: cellGap),
                                width: cellSize,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  color: _getCellColor(day.level, isDark),
                                  borderRadius: BorderRadius.circular(2.5),
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
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14.0),

          // Selected Tooltip or Legend (Matching Web 1:1)
          if (_selectedDay != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        _selectedDay!.formattedDate,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Text(
                          '·',
                          style: TextStyle(color: textSecondary.withValues(alpha: 0.5)),
                        ),
                      ),
                      Text(
                        _selectedDay!.count == 0
                            ? 'No submissions'
                            : '${_selectedDay!.count} ${_selectedDay!.count == 1 ? 'challenge' : 'challenges'} solved',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: _selectedDay!.count > 0
                              ? AppColors.primary
                              : textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDay = null);
                    },
                    child: Text(
                      'Clear',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.0,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
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
                  '${widget.totalActiveDays} active days this quarter · Last 12 Months',
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
                          border: Border.all(
                            color: lvl > 0
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: 0.6,
                          ),
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
