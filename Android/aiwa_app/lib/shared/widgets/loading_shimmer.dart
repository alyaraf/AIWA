import 'package:flutter/cupertino.dart';
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
      highlightColor: AppColors.hover,
      period: const Duration(milliseconds: 1250),
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
  const SkeletonTile({super.key, this.width = 132, this.height = 168});

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

/// `SkeletonRows` — table placeholder: first column 80%, the rest 58%.
class SkeletonRows extends StatelessWidget {
  final int cols;
  final int rows;
  const SkeletonRows({super.key, this.cols = 5, this.rows = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (_) => Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            spacing: 12,
            children: List.generate(
              cols,
              (c) => Expanded(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: c == 0 ? .8 : .58,
                  child: const ShimmerBox(height: 12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pull-to-refresh without a spinner: a pulsing rose dot (aiwa-pulse).
/// First sliver of a CustomScrollView using [physics].
class AiwaRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const AiwaRefresh({super.key, required this.onRefresh});

  /// Overscroll is needed for the pull gesture on Android too.
  static const physics = BouncingScrollPhysics(
    parent: AlwaysScrollableScrollPhysics(),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: onRefresh,
      builder: (_, mode, pulled, _, _) => Center(
        child: mode == RefreshIndicatorMode.inactive
            ? const SizedBox.shrink()
            : _PulseDot(still: mode == RefreshIndicatorMode.drag, t: pulled),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool still;
  final double t;
  const _PulseDot({required this.still, required this.t});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    lowerBound: .55,
    upperBound: .9,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.rose500,
        shape: BoxShape.circle,
      ),
    );
    if (widget.still) {
      return Opacity(opacity: (widget.t / 100).clamp(0.0, .9), child: dot);
    }
    return FadeTransition(opacity: _c, child: dot);
  }
}
