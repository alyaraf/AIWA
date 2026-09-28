import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_theme.dart';

class AppTextStyles {
  AppTextStyles._();

  // Line-height and tracking tokens (tokens/colors_and_type.css:114-122).
  // Tracking is in em: multiply by the font size.
  static const double lhTight = 1.1;
  static const double lhSnug = 1.25;
  static const double lhBase = 1.5;
  static const double lhLoose = 1.65;
  static const double trackingWide = 0.08;
  // The kit's recurring inline half-step sizes (115 JSX fontSize literals),
  // each half a pixel above the micro / labelSm / meta scale steps.
  static const double fsMicroPlus = 11.5;
  static const double fsLabelSmPlus = 12.5;
  static const double fsMetaPlus = 13.5;

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
    letterSpacing: -0.02 * 26,
  );

  static TextStyle get h3 => _serif(
    fontSize: 22,
    color: AppColors.plum900,
    height: 1.15,
    letterSpacing: -0.01 * 22,
  );

  static TextStyle get h4 =>
      _serif(fontSize: 18, color: AppColors.plum900, height: 1.2);

  // ponytail: h3/h4 above match the rendered JSX titles (DM Serif); the CSS
  // token classes .h3/.h4 are sans and live here under their own names.
  static TextStyle get h3Sans => _sans(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.plum900,
    height: lhSnug,
    letterSpacing: -0.005 * 20,
  );

  static TextStyle get h4Sans => _sans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.plum900,
    height: lhSnug,
  );

  // Body — Plus Jakarta Sans
  static TextStyle get bodyLg =>
      _sans(fontSize: 16, color: AppColors.ink, height: lhBase);

  /// Paragraph copy — CSS `p` / `.body` (16 / --lh-loose).
  static TextStyle get bodyLoose =>
      _sans(fontSize: 16, color: AppColors.ink, height: lhLoose);

  static TextStyle get body =>
      _sans(fontSize: 15, color: AppColors.ink, height: 1.5);

  static TextStyle get bodySm =>
      _sans(fontSize: 14, color: AppColors.ink2, height: 1.55);

  static TextStyle get meta =>
      _sans(fontSize: 13, color: AppColors.ink3, height: 1.45);

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
    fontSize: 20,
    color: AppColors.plum900,
    height: 1,
    letterSpacing: -0.02 * 20,
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

  // Mono — CSS `code` is plum700 (colors_and_type.css:268-275).
  static TextStyle get mono =>
      _mono(fontSize: 13, color: AppColors.plum700, height: 1.4);

  /// Inline `code` chip: cream fill, .1em/.3em padding, radius 4.
  static Widget monoChip(String text, {double fontSize = 13}) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: .3 * fontSize,
        vertical: .1 * fontSize,
      ),
      child: Text(text, style: mono.copyWith(fontSize: fontSize)),
    ),
  );
}

/// Test seam: widget tests set this to `false` so text styles use plain
/// family names instead of google_fonts, which would fetch over the network.
bool aiwaUseGoogleFonts = true;

typedef _GoogleFont = TextStyle Function({TextStyle? textStyle});

/// Arabic glyphs aren't in the Latin families; these (pubspec `fonts:`)
/// catch them so Arabic never falls back to the system font.
const kArabicSans = 'IBM Plex Sans Arabic';
const kArabicSerif = 'Markazi Text';

TextStyle _styled(
  String family,
  _GoogleFont google,
  TextStyle base, {
  String arabic = kArabicSans,
}) =>
    (aiwaUseGoogleFonts
            ? google(textStyle: base)
            : base.copyWith(fontFamily: family))
        .copyWith(fontFamilyFallback: [arabic]);

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
  arabic: kArabicSerif,
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
