import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Shimmer placeholders — `Skeleton*` in the kit. No spinners anywhere.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cream,
      highlightColor: AppColors.paper,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// `SkeletonCard` — a list row placeholder.
class ProviderCardShimmer extends StatelessWidget {
  const ProviderCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 64, height: 64, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LayoutBuilder(
                builder: (context, c) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: c.maxWidth * 0.62, height: 14),
                    const SizedBox(height: 8),
                    ShimmerBox(width: c.maxWidth * 0.40, height: 11),
                    const SizedBox(height: 8),
                    ShimmerBox(width: c.maxWidth * 0.78, height: 11),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `SkeletonList` — a column of [ProviderCardShimmer]s.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? 10 : 0),
          child: const ProviderCardShimmer(),
        ),
      ),
    );
  }
}

/// `SkeletonTile` — a horizontal-carousel card placeholder.
class SkeletonTile extends StatelessWidget {
  final double width;
  final double height;
  const SkeletonTile({super.key, this.width = 200, this.height = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: width, height: height, radius: AppTheme.radiusLg),
          const SizedBox(height: 8),
          ShimmerBox(width: width * 0.72, height: 11),
          const SizedBox(height: 8),
          ShimmerBox(width: width * 0.46, height: 10),
        ],
      ),
    );
  }
}
