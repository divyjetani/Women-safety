// App/frontend/mobile/lib/widgets/skeleton_loader_for_home.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../app/theme.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = isDark ? AppTheme.skeletonBaseDark : AppTheme.skeletonBaseLight;
    final highlight =
    isDark ? AppTheme.skeletonHighlightDark : AppTheme.skeletonHighlightLight;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: base, // ✅ theme adaptive (important)
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SafetyScoreSkeleton extends StatelessWidget {
  const SafetyScoreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    final shadowColor =
    isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(width: 100, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonLoader(width: 60, height: 40, borderRadius: 8),
                SizedBox(height: 8),
                SkeletonLoader(width: 200, height: 14, borderRadius: 4),
                SizedBox(height: 12),
                SkeletonLoader(width: 120, height: 16, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 20),
          const SkeletonLoader(width: 100, height: 100, borderRadius: 50),
        ],
      ),
    );
  }
}

class StatsGridSkeleton extends StatelessWidget {
  const StatsGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.3,
        children: List.generate(4, (index) => _buildStatCardSkeleton(context)),
      ),
    );
  }

  Widget _buildStatCardSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shadowColor =
    isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 32, height: 32, borderRadius: 16),
                SkeletonLoader(width: 40, height: 16, borderRadius: 4),
              ],
            ),
            SizedBox(height: 12),
            SkeletonLoader(width: 60, height: 32, borderRadius: 8),
            SizedBox(height: 4),
            SkeletonLoader(width: 80, height: 16, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

class RecentActivitySkeleton extends StatelessWidget {
  const RecentActivitySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonLoader(width: 120, height: 24, borderRadius: 4),
              SkeletonLoader(width: 60, height: 16, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(3, (index) => _buildActivityItemSkeleton(context)),
        ],
      ),
    );
  }

  Widget _buildActivityItemSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shadowColor =
    isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          SkeletonLoader(width: 36, height: 36, borderRadius: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 150, height: 18, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonLoader(width: 100, height: 14, borderRadius: 4),
              ],
            ),
          ),
          SkeletonLoader(width: 60, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}

class QuickActionsSkeleton extends StatelessWidget {
  const QuickActionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 120, height: 24, borderRadius: 4),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(4, (index) => _buildActionButtonSkeleton(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shadowColor =
    isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.05);

    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonLoader(width: 48, height: 48, borderRadius: 24),
          SizedBox(height: 8),
          SkeletonLoader(width: 60, height: 14, borderRadius: 4),
        ],
      ),
    );
  }
}
