import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../common_widgets/language_icon.dart';
import '../../../constants/app_colors.dart';

class ActivityItemData {
  const ActivityItemData({
    required this.id,
    required this.title,
    required this.module,
    required this.language,
    required this.status, // 'Passed', 'Needs Review', 'Accepted'
    required this.score,
    required this.time,
  });

  final String id;
  final String title;
  final String module;
  final String language;
  final String status;
  final int score;
  final String time;
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const List<ActivityItemData> _recentSubmissions = <ActivityItemData>[
    ActivityItemData(
      id: 'sub-1',
      title: 'Print Multiple Lines with Formatting',
      module: 'Java Fundamentals',
      language: 'java',
      status: 'Passed',
      score: 96,
      time: 'Today',
    ),
    ActivityItemData(
      id: 'sub-2',
      title: 'Debug: Missing Main Method',
      module: 'Java Fundamentals',
      language: 'java',
      status: 'Needs Review',
      score: 84,
      time: 'Yesterday',
    ),
    ActivityItemData(
      id: 'sub-3',
      title: 'Async / Await Error Propagation',
      module: 'JavaScript Core',
      language: 'javascript',
      status: 'Passed',
      score: 100,
      time: '2 days ago',
    ),
    ActivityItemData(
      id: 'sub-4',
      title: 'LRU Cache Eviction Policy',
      module: 'Python Algorithms',
      language: 'python',
      status: 'Passed',
      score: 92,
      time: '3 days ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Title & Subtitle
              Text(
                'My Activity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                'Submissions history, code reviews, and accuracy logs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 20.0),

              // Activity Metrics Row
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildMetricBox(
                      label: 'Submissions',
                      value: '14',
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: _buildMetricBox(
                      label: 'Avg Score',
                      value: '93%',
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: _buildMetricBox(
                      label: 'Reviews',
                      value: '4',
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // Timeline Feed Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Recent Submissions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    '${_recentSubmissions.length} Recorded',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // Submissions List
              Column(
                children: _recentSubmissions.map((ActivityItemData item) {
                  final bool isPassed = item.status == 'Passed' || item.status == 'Accepted';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceCard
                          : AppColors.lightSurfaceCard,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        LanguageIcon(language: item.language, size: 22.0),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                '${item.module} · ${item.time}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.0,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              '${item.score}%',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w800,
                                color: item.score >= 90
                                    ? const Color(0xFF3ECF8E)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: (isPassed
                                        ? const Color(0xFF3ECF8E)
                                        : const Color(0xFFF59E0B))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6.0),
                              ),
                              child: Text(
                                item.status,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isPassed
                                      ? const Color(0xFF3ECF8E)
                                      : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 17.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
