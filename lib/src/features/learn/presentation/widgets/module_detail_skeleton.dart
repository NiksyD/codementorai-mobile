import 'package:flutter/material.dart';
import '../../../../common_widgets/shimmer_skeleton.dart';
import '../../../../constants/app_colors.dart';

class ModuleDetailSkeleton extends StatelessWidget {
  const ModuleDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const ShimmerLoading(
          child: SkeletonBox(width: 160.0, height: 18.0, borderRadius: 6.0),
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: ShimmerLoading(
              child: SkeletonBox(width: 24.0, height: 24.0, borderRadius: 6.0),
            ),
          ),
        ],
      ),
      body: ShimmerLoading(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  SkeletonBox(width: 56.0, height: 24.0, borderRadius: 12.0),
                  SkeletonBox(width: 90.0, height: 12.0, borderRadius: 4.0),
                ],
              ),
              const SizedBox(height: 16.0),
              const SkeletonBox(width: 260.0, height: 24.0, borderRadius: 4.0),
              const SizedBox(height: 10.0),
              const SkeletonBox(
                width: double.infinity,
                height: 12.0,
                borderRadius: 4.0,
              ),
              const SizedBox(height: 6.0),
              const SkeletonBox(width: 220.0, height: 12.0, borderRadius: 4.0),
              const SizedBox(height: 20.0),
              const SkeletonBox(
                width: double.infinity,
                height: 4.0,
                borderRadius: 999.0,
              ),
              const SizedBox(height: 16.0),
              const SkeletonBox(width: 180.0, height: 16.0, borderRadius: 4.0),
              const SizedBox(height: 16.0),
              const SkeletonBox(
                width: double.infinity,
                height: 48.0,
                borderRadius: 12.0,
              ),
              const SizedBox(height: 32.0),
              const SkeletonBox(width: 140.0, height: 18.0, borderRadius: 4.0),
              const SizedBox(height: 12.0),
              for (int i = 0; i < 3; i++) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: const SkeletonBox(
                    width: double.infinity,
                    height: 36.0,
                    borderRadius: 4.0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
