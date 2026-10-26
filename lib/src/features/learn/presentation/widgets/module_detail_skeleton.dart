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
        isDark ? AppColors.darkSurface : Colors.white;
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
        title: const ShimmerLoading(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Split-Block Hero Banner Skeleton
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Upper Context
                    Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const <Widget>[
                              SkeletonBox(width: 60.0, height: 12.0, borderRadius: 4.0),
                              Row(
                                children: <Widget>[
                                  SkeletonCircle(size: 24.0),
                                  SizedBox(width: 4.0),
                                  SkeletonCircle(size: 24.0),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14.0),
                          const SkeletonBox(width: 220.0, height: 20.0, borderRadius: 6.0),
                          const SizedBox(height: 8.0),
                          const SkeletonBox(width: double.infinity, height: 14.0, borderRadius: 4.0),
                          const SizedBox(height: 6.0),
                          const SkeletonBox(width: 180.0, height: 14.0, borderRadius: 4.0),
                          const SizedBox(height: 14.0),
                          Row(
                            children: const <Widget>[
                              SkeletonCircle(size: 20.0),
                              SizedBox(width: 8.0),
                              SkeletonBox(width: 100.0, height: 12.0, borderRadius: 4.0),
                              SizedBox(width: 8.0),
                              SkeletonBox(width: 70.0, height: 12.0, borderRadius: 4.0),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1.0, color: borderColor.withValues(alpha: 0.35)),
                    // Lower Action Block
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      color: isDark
                          ? AppColors.darkSurfaceCard.withValues(alpha: 0.5)
                          : AppColors.lightSurfaceCard.withValues(alpha: 0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const <Widget>[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SkeletonBox(width: 50.0, height: 10.0, borderRadius: 3.0),
                                  SizedBox(height: 4.0),
                                  SkeletonBox(width: 120.0, height: 16.0, borderRadius: 4.0),
                                ],
                              ),
                              SkeletonBox(width: 80.0, height: 14.0, borderRadius: 4.0),
                            ],
                          ),
                          const SizedBox(height: 12.0),
                          const SkeletonBox(width: double.infinity, height: 5.0, borderRadius: 3.0),
                          const SizedBox(height: 14.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const <Widget>[
                              SkeletonBox(width: 130.0, height: 12.0, borderRadius: 4.0),
                              SkeletonBox(width: 110.0, height: 34.0, borderRadius: 17.0),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Module Outline Header Skeleton
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const <Widget>[
                  SkeletonBox(width: 130.0, height: 18.0, borderRadius: 6.0),
                  SkeletonBox(width: 75.0, height: 14.0, borderRadius: 4.0),
                ],
              ),
              const SizedBox(height: 10.0),
              Divider(height: 1.0, color: borderColor.withValues(alpha: 0.4)),

              // Hollow Topic Rows Skeleton
              for (int i = 0; i < 4; i++) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 4.0),
                  child: Row(
                    children: <Widget>[
                      const SkeletonBox(width: 24.0, height: 14.0, borderRadius: 4.0),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const <Widget>[
                            SkeletonBox(width: 160.0, height: 14.0, borderRadius: 4.0),
                            SizedBox(height: 5.0),
                            SkeletonBox(width: 220.0, height: 11.0, borderRadius: 4.0),
                          ],
                        ),
                      ),
                      const SkeletonBox(width: 60.0, height: 14.0, borderRadius: 4.0),
                    ],
                  ),
                ),
                Divider(height: 1.0, color: borderColor.withValues(alpha: 0.25)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
