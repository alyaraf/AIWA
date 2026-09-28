import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StarRating extends StatelessWidget {
  final double value;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const StarRating({
    super.key,
    required this.value,
    this.size = 14,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 1,
      children: List.generate(5, (i) {
        // Integer fill like the kit (`n <= value`): 4.8 shows 4 stars.
        final filled = i + 1 <= value;
        return AiwaStar(
          size: size,
          filled: filled,
          color: filled
              ? activeColor ?? AppColors.gold500
              : inactiveColor ?? AppColors.ink4,
        );
      }),
    );
  }
}

/// The kit's star: the Lucide polygon drawn inline with a 2px stroke and an
/// optional fill (components.jsx StarRating). Lucide's icon font has no filled
/// glyphs, so rating stars are painted instead of using LucideIcons.star.
class AiwaStar extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const AiwaStar({
    super.key,
    required this.size,
    required this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _StarPainter(color, filled)),
  );
}

class _StarPainter extends CustomPainter {
  final Color color;
  final bool filled;
  _StarPainter(this.color, this.filled);

  // <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77
  //   5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/> on a 24x24 viewBox.
  static const _pts = [
    12.0, 2.0, 15.09, 8.26, 22.0, 9.27, 17.0, 14.14, 18.18, 21.02, //
    12.0, 17.77, 5.82, 21.02, 7.0, 14.14, 2.0, 9.27, 8.91, 8.26,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()..moveTo(_pts[0] * s, _pts[1] * s);
    for (var i = 2; i < _pts.length; i += 2) {
      path.lineTo(_pts[i] * s, _pts[i + 1] * s);
    }
    path.close();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * s; // default miter join, like the inline SVG
    if (filled) canvas.drawPath(path, paint..style = PaintingStyle.fill);
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.color != color || old.filled != filled;
}
