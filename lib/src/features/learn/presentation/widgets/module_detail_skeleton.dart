import 'package:flutter/material.dart';
import '../../../../common_widgets/shimmer_skeleton.dart';
import '../../../../constants/app_colors.dart';

class ModuleDetailSkeleton extends StatelessWidget {
  const ModuleDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color cardBg =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: ShimmerLoading(
          child: SkeletonBox(
            width: 160.0,
            height: 18.0,
            borderRadius: 6.0,
          ),
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ShimmerLoading(
              child: SkeletonBox(
                width: 24.0,
                height: 24.0,
                borderRadius: 6.0,
              ),
            ),
          ),
        ],
      ),
      body: ShimmerLoading(
        child: Column(
          children: <Widget>[
            // ── SUB-NAV TAB PLACEHOLDERS ──
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 0.8),
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: const <Widget>[
                  SkeletonBox(width: 80.0, height: 20.0, borderRadius: 6.0),
                  SizedBox(width: 24.0),
                  SkeletonBox(width: 95.0, height: 20.0, borderRadius: 6.0),
                ],
              ),
            ),

            // ── SCROLLABLE SKELETON CONTENT ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Hero Module Card Skeleton
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const <Widget>[
                              Row(
                                children: <Widget>[
                                  SkeletonCircle(size: 28.0),
                                  SizedBox(width: 6.0),
                                  SkeletonCircle(size: 28.0),
                                ],
                              ),
                              SkeletonBox(
                                width: 90.0,
                                height: 22.0,
                                borderRadius: 10.0,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          const SkeletonBox(
                            width: 220.0,
                            height: 20.0,
                            borderRadius: 6.0,
                          ),
                          const SizedBox(height: 8.0),
                          const SkeletonBox(
                            width: double.infinity,
                            height: 14.0,
                            borderRadius: 4.0,
                          ),
                          const SizedBox(height: 6.0),
                          const SkeletonBox(
                            width: 180.0,
                            height: 14.0,
                            borderRadius: 4.0,
                          ),
                          const SizedBox(height: 16.0),
                          const SkeletonBox(
                            width: double.infinity,
                            height: 6.0,
                            borderRadius: 3.0,
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const <Widget>[
                              Row(
                                children: <Widget>[
                                  SkeletonCircle(size: 26.0),
                                  SizedBox(width: 8.0),
                                  SkeletonBox(
                                    width: 110.0,
                                    height: 14.0,
                                    borderRadius: 4.0,
                                  ),
                                ],
                              ),
                              SkeletonBox(
                                width: 40.0,
                                height: 16.0,
                                borderRadius: 4.0,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Section Title Skeleton
                    const SkeletonBox(
                      width: 130.0,
                      height: 18.0,
                      borderRadius: 6.0,
                    ),
                    const SizedBox(height: 14.0),

                    // 3 Topic Pathway Cards Skeleton
                    for (int i = 0; i < 3; i++) ...<Widget>[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(15.0),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: <Widget>[
                            const SkeletonBox(
                              width: 28.0,
                              height: 28.0,
                              borderRadius: 8.0,
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const <Widget>[
                                  SkeletonBox(
                                    width: 150.0,
                                    height: 14.0,
                                    borderRadius: 4.0,
                                  ),
                                  SizedBox(height: 6.0),
                                  SkeletonBox(
                                    width: 210.0,
                                    height: 11.0,
                                    borderRadius: 4.0,
                                  ),
                                ],
                              ),
                            ),
                            const SkeletonBox(
                              width: 16.0,
                              height: 16.0,
                              borderRadius: 4.0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
