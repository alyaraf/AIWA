import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Transparent button with a 1.5px dashed divider border and a plum
/// "+ label" — the kit's "Add new address" / "Add another contact".
class DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  /// Icon above the label, e.g. the gallery 'Add' tile.
  final bool vertical;
  final double radius;
  final double padding;
  final double fontSize;
  final double iconSize;
  final double gap;

  const DashedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.radius = 16,
    this.padding = 14,
    this.fontSize = 14,
    this.iconSize = 16,
    this.vertical = false,
    this.gap = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: DashedBorder(AppColors.divider, radius),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: iconSize,
                  color: AppColors.plum700,
                ),
                SizedBox(width: gap, height: vertical ? 5 : 0),
                Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    fontSize: fontSize,
                    color: AppColors.plum700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dash 5 / gap 4 rounded-rect outline — CSS `border: … dashed`.
class DashedBorder extends CustomPainter {
  final Color color;
  final double radius;
  final double width;
  const DashedBorder(this.color, this.radius, {this.width = 1.5});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(width / 2),
          Radius.circular(radius),
        ),
      );
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorder old) =>
      old.color != color || old.radius != radius || old.width != width;
}
