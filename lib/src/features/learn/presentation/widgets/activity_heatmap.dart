import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../common_widgets/language_icon.dart';
import '../../../../constants/app_colors.dart';
import '../../domain/dashboard_submission.dart';

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
    this.submissions = const <DashboardSubmission>[],
    this.totalActiveDays = 0,
    this.currentStreak = 0,
    this.weeksCount = 52,
  });

  final List<DashboardSubmission> submissions;
  final int totalActiveDays;
  final int currentStreak;
  final int weeksCount;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  HeatmapDayData? _selectedDay;
  final ScrollController _scrollController = ScrollController();

  late List<List<HeatmapDayData>> _weeks;
  late List<MapEntry<String, int>> _monthPositions;

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
  void didUpdateWidget(covariant ActivityHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.submissions != widget.submissions ||
        oldWidget.weeksCount != widget.weeksCount) {
      setState(() {
        _weeks = _generateActivityData(widget.weeksCount);
        _monthPositions = _calculateMonthPositions(_weeks);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<List<HeatmapDayData>> _generateActivityData(int countWeeks) {
    final List<List<HeatmapDayData>> weeks = <List<HeatmapDayData>>[];
    final DateTime today = DateTime.now();

    final Map<String, int> countsByDate = <String, int>{};
    for (final DashboardSubmission s in widget.submissions) {
      if (s.rawDate.isNotEmpty) {
        countsByDate[s.rawDate] = (countsByDate[s.rawDate] ?? 0) + 1;
      }
    }

    for (int w = countWeeks - 1; w >= 0; w--) {
      final List<HeatmapDayData> weekDays = <HeatmapDayData>[];
      for (int d = 6; d >= 0; d--) {
        final DateTime dayDate = today.subtract(Duration(days: (w * 7 + d)));
        final String dateStr =
            '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
        final int count = countsByDate[dateStr] ?? 0;
        final int level = count == 0 ? 0 : count == 1 ? 1 : count <= 3 ? 2 : 3;
        final String month = _monthNames[dayDate.month - 1];
        final String formatted = '$month ${dayDate.day}, ${dayDate.year}';

        weekDays.add(
          HeatmapDayData(
            date: dateStr,
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
        return const Color(0xFF10B981).withValues(alpha: 0.35);
      case 2:
        return const Color(0xFF10B981).withValues(alpha: 0.65);
      case 3:
        return const Color(0xFF10B981);
      default:
        return isDark
            ? AppColors.darkSurface.withValues(alpha: 0.7)
            : AppColors.lightSurfaceCard.withValues(alpha: 0.8);
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return AppColors.primary;
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

    final List<DashboardSubmission> selectedDaySubmissions = _selectedDay == null
        ? const <DashboardSubmission>[]
        : widget.submissions
            .where((DashboardSubmission s) => s.rawDate == _selectedDay!.date)
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Card Header (Mobile Optimized Clean Stack) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Practice Activity',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3.0),
                      Text(
                        widget.totalActiveDays == 0
                            ? 'No activity recorded yet · Last 12 months'
                            : '${widget.totalActiveDays} active day${widget.totalActiveDays == 1 ? '' : 's'} · Last 12 months',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '🔥',
                          style: TextStyle(fontSize: 12.0),
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          '${widget.currentStreak} Day Streak',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Hairline separator
          Divider(
            height: 1.0,
            thickness: 1.0,
            color: isDark
                ? AppColors.darkBorder.withValues(alpha: 0.5)
                : AppColors.lightBorder.withValues(alpha: 0.8),
          ),

          // ── Card Content ──
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
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
                                    key: ValueKey<String>('cell-${day.date}'),
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
                                              ? (isDark ? Colors.white : AppColors.darkTextPrimary)
                                              : (day.level > 0
                                                  ? AppColors.primary.withValues(alpha: 0.3)
                                                  : (isDark
                                                      ? AppColors.darkBorder
                                                      : AppColors.lightBorder)),
                                          width: isSelected ? 1.5 : 0.8,
                                        ),
                                        boxShadow: isSelected
                                            ? <BoxShadow>[
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.4),
                                                  blurRadius: 4.0,
                                                ),
                                              ]
                                            : null,
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

                // ── Selected Day Activity Breakdown (Inline Collapsible List) ──
                if (_selectedDay != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Header Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceCard.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.6),
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                                    : AppColors.lightBorder.withValues(alpha: 0.6),
                              ),
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
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: _selectedDay!.count > 0
                                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                          : (isDark ? AppColors.darkSurface : Colors.white),
                                      borderRadius: BorderRadius.circular(6.0),
                                      border: Border.all(
                                        color: _selectedDay!.count > 0
                                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        if (_selectedDay!.count > 0) ...<Widget>[
                                          Container(
                                            width: 5.0,
                                            height: 5.0,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4.5),
                                        ],
                                        Text(
                                          _selectedDay!.count == 0
                                              ? 'No submissions'
                                              : '${_selectedDay!.count} challenge${_selectedDay!.count == 1 ? '' : 's'} solved',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w600,
                                            color: _selectedDay!.count > 0
                                                ? const Color(0xFF10B981)
                                                : textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: <Widget>[
                                  if (_selectedDay!.count > 0) ...<Widget>[
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
                                            'View all',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 2.0),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 12.0,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                  ],
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _selectedDay = null);
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.all(4.0),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkBorder.withValues(alpha: 0.5)
                                            : AppColors.lightBorder.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 13.0,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Submissions List or Empty Indicator
                        if (selectedDaySubmissions.isNotEmpty)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: selectedDaySubmissions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1.0,
                              thickness: 1.0,
                              color: isDark
                                  ? AppColors.darkBorder.withValues(alpha: 0.4)
                                  : AppColors.lightBorder.withValues(alpha: 0.6),
                            ),
                            itemBuilder: (context, index) {
                              final DashboardSubmission sub = selectedDaySubmissions[index];
                              final bool isPassed = sub.status == 'Passed';
                              final Color diffColor = _getDifficultyColor(sub.difficulty);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    // Row 1: Title & Difficulty Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            sub.title,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: diffColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(5.0),
                                          ),
                                          child: Text(
                                            sub.difficulty,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: diffColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3.0),

                                    // Row 2: Module Name
                                    Text(
                                      sub.module,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.0,
                                        color: textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6.0),

                                    // Row 3: Language Pill, Score, and Status Badge
                                    Row(
                                      children: <Widget>[
                                        // Language Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(
                                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              LanguageIcon(language: sub.language, size: 12.0),
                                              const SizedBox(width: 4.5),
                                              Text(
                                                sub.language.toUpperCase(),
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Score if available
                                        if (sub.score != null) ...<Widget>[
                                          const SizedBox(width: 8.0),
                                          Text(
                                            '${sub.score}%',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.w700,
                                              color: sub.score! >= 90
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],

                                        const Spacer(),

                                        // Status Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isPassed
                                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6.0),
                                            border: Border.all(
                                              color: isPassed
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                                  : const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Icon(
                                                isPassed
                                                    ? Icons.check_circle_rounded
                                                    : Icons.access_time_rounded,
                                                size: 11.5,
                                                color: isPassed
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFF59E0B),
                                              ),
                                              const SizedBox(width: 3.5),
                                              Text(
                                                sub.status,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isPassed
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFF59E0B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 14.0),
                            child: Center(
                              child: Text(
                                'No recorded practice activity on this date.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  // ── Legend & Action Footer ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
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
          ),
        ],
      ),
    );
  }
}
