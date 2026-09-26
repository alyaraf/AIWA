import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Display serif — DM Serif Display
  static TextStyle get display => _serif(
    fontSize: 48,
    color: AppColors.plum900,
    height: 1.1,
    letterSpacing: -0.02 * 48,
  );

  static TextStyle get h1 => _serif(
    fontSize: 32,
    color: AppColors.plum900,
    height: 1.1,
    letterSpacing: -0.02 * 32,
  );

  static TextStyle get h2 => _serif(
    fontSize: 26,
    color: AppColors.plum900,
    height: 1.15,
    letterSpacing: -0.01 * 26,
  );

  static TextStyle get h3 => _serif(
    fontSize: 22,
    color: AppColors.plum900,
    height: 1.15,
    letterSpacing: -0.01 * 22,
  );

  static TextStyle get h4 =>
      _serif(fontSize: 18, color: AppColors.plum900, height: 1.2);

  // Body — Plus Jakarta Sans
  static TextStyle get bodyLg =>
      _sans(fontSize: 16, color: AppColors.ink, height: 1.5);

  static TextStyle get body =>
      _sans(fontSize: 15, color: AppColors.ink, height: 1.5);

  static TextStyle get bodySm =>
      _sans(fontSize: 14, color: AppColors.ink, height: 1.55);

  static TextStyle get meta =>
      _sans(fontSize: 13, color: AppColors.ink3, height: 1.4);

  static TextStyle get micro =>
      _sans(fontSize: 11, color: AppColors.ink3, height: 1.4);

  static TextStyle get eyebrow => _sans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.14 * 11,
    color: AppColors.ink3,
    height: 1,
  ).copyWith(fontFeatures: const [FontFeature.enable('smcp')]);

  static TextStyle get price => _serif(
    fontSize: 22,
    color: AppColors.plum900,
    height: 1,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

  static TextStyle get label => _sans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1,
  );

  static TextStyle get labelSm => _sans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1,
  );

  static TextStyle get button => _sans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.paper,
    height: 1,
  );

  static TextStyle get buttonSm => _sans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.paper,
    height: 1,
  );

  // Mono
  static TextStyle get mono =>
      _mono(fontSize: 13, color: AppColors.ink, height: 1.4);
}

/// Test seam: widget tests set this to `false` so text styles use plain
/// family names instead of google_fonts, which would fetch over the network.
bool aiwaUseGoogleFonts = true;

typedef _GoogleFont = TextStyle Function({TextStyle? textStyle});

TextStyle _styled(String family, _GoogleFont google, TextStyle base) =>
    aiwaUseGoogleFonts
    ? google(textStyle: base)
    : base.copyWith(fontFamily: family);

TextStyle _base({
  double? fontSize,
  Color? color,
  double? height,
  FontWeight? fontWeight,
  double? letterSpacing,
  List<FontFeature>? fontFeatures,
}) => TextStyle(
  fontSize: fontSize,
  color: color,
  height: height,
  fontWeight: fontWeight,
  letterSpacing: letterSpacing,
  fontFeatures: fontFeatures,
);

TextStyle _serif({
  double? fontSize,
  Color? color,
  double? height,
  FontWeight? fontWeight,
  double? letterSpacing,
  List<FontFeature>? fontFeatures,
}) => _styled(
  'DM Serif Display',
  GoogleFonts.dmSerifDisplay,
  _base(
    fontSize: fontSize,
    color: color,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    fontFeatures: fontFeatures,
  ),
);

TextStyle _sans({
  double? fontSize,
  Color? color,
  double? height,
  FontWeight? fontWeight,
  double? letterSpacing,
  List<FontFeature>? fontFeatures,
}) => _styled(
  'Plus Jakarta Sans',
  GoogleFonts.plusJakartaSans,
  _base(
    fontSize: fontSize,
    color: color,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    fontFeatures: fontFeatures,
  ),
);

TextStyle _mono({
  double? fontSize,
  Color? color,
  double? height,
  FontWeight? fontWeight,
  double? letterSpacing,
  List<FontFeature>? fontFeatures,
}) => _styled(
  'JetBrains Mono',
  GoogleFonts.jetBrainsMono,
  _base(
    fontSize: fontSize,
    color: color,
    height: height,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    fontFeatures: fontFeatures,
  ),
);
