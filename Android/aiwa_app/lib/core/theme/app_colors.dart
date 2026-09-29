import 'package:flutter/material.dart';

/// One full set of AIWA colour tokens.
///
/// The token names (plum / rose / gold …) are kept from the original brand
/// palette so every screen keeps working; the two gender palettes below just
/// remap them, exactly like `theme.jsx` in the design handoff.
class AiwaPalette {
  final Color plum900, plum700, plum500, plum300, plum100;
  final Color rose700, rose500, rose300, rose100;
  final Color gold700, gold500, gold300, gold100;
  final Color ink, ink2, ink3, ink4;
  final Color bone, cream, paper, divider, hover;
  final Color success700, success500, success100;
  final Color warn700, warn500, warn100;
  final Color danger700, danger500, danger100;
  final Color info700, info500, info100;

  const AiwaPalette({
    required this.plum900,
    required this.plum700,
    required this.plum500,
    required this.plum300,
    required this.plum100,
    required this.rose700,
    required this.rose500,
    required this.rose300,
    required this.rose100,
    required this.gold700,
    required this.gold500,
    required this.gold300,
    required this.gold100,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.ink4,
    required this.bone,
    required this.cream,
    required this.paper,
    required this.divider,
    required this.hover,
    required this.success700,
    required this.success500,
    required this.success100,
    required this.warn700,
    required this.warn500,
    required this.warn100,
    required this.danger700,
    required this.danger500,
    required this.danger100,
    required this.info700,
    required this.info500,
    required this.info100,
  });
}

class AiwaPalettes {
  AiwaPalettes._();

  /// MAIN / MALE — Deep Charcoal #2E2A26, Warm Stone #B5A898, Off White #F5F2ED.
  /// This is the spec-defined default palette.
  static const AiwaPalette male = AiwaPalette(
    plum900: Color(0xFF2E2A26),
    plum700: Color(0xFF2E2A26),
    plum500: Color(0xFF5C544D),
    plum300: Color(0xFFB5A898),
    plum100: Color(0xFFE8E2D9),
    rose700: Color(0xFF5C544D),
    rose500: Color(0xFF8A8074),
    rose300: Color(0xFFB5A898),
    rose100: Color(0xFFE8E2D9),
    gold700: Color(0xFF2E2A26),
    gold500: Color(0xFF5C544D),
    gold300: Color(0xFFB5A898),
    gold100: Color(0xFFE8E2D9),
    ink: Color(0xFF2E2A26),
    ink2: Color(0xFF4A4540),
    ink3: Color(0xFF7A7268),
    ink4: Color(0xFFA39A8E),
    bone: Color(0xFFF5F2ED),
    cream: Color(0xFFEBE5DA),
    paper: Color(0xFFFFFFFF),
    divider: Color(0xFFD8CFC2),
    hover: Color(0xFFEBE5DA),
    success700: Color(0xFF2E2A26),
    success500: Color(0xFF2E2A26),
    success100: Color(0xFFE8E2D9),
    warn700: Color(0xFF2E2A26),
    warn500: Color(0xFF5C544D),
    warn100: Color(0xFFEBE5DA),
    danger700: Color(0xFF2E2A26),
    danger500: Color(0xFF2E2A26),
    danger100: Color(0xFFE8E2D9),
    info700: Color(0xFF2E2A26),
    info500: Color(0xFF5C544D),
    info100: Color(0xFFEBE5DA),
  );

  /// FEMALE — Deep Mauve #6B3A3A, Dusty Rose #C4837A, Blush White #FDF6F4.
  static const AiwaPalette female = AiwaPalette(
    plum900: Color(0xFF6B3A3A),
    plum700: Color(0xFF6B3A3A),
    plum500: Color(0xFF9A5A55),
    plum300: Color(0xFFC4837A),
    plum100: Color(0xFFF2D9D3),
    rose700: Color(0xFF6B3A3A),
    rose500: Color(0xFFC4837A),
    rose300: Color(0xFFE6BAB0),
    rose100: Color(0xFFF8E4DE),
    gold700: Color(0xFF6B3A3A),
    gold500: Color(0xFFC4837A),
    gold300: Color(0xFFE6BAB0),
    gold100: Color(0xFFF8E4DE),
    ink: Color(0xFF2E2026),
    ink2: Color(0xFF5A4347),
    ink3: Color(0xFF8A6F71),
    ink4: Color(0xFFB59A99),
    bone: Color(0xFFFDF6F4),
    cream: Color(0xFFF8E8E3),
    paper: Color(0xFFFFFFFF),
    divider: Color(0xFFEFDCD6),
    hover: Color(0xFFF8E8E3),
    success700: Color(0xFF6B3A3A),
    success500: Color(0xFF6B3A3A),
    success100: Color(0xFFF2D9D3),
    warn700: Color(0xFF6B3A3A),
    warn500: Color(0xFFC4837A),
    warn100: Color(0xFFF8E4DE),
    danger700: Color(0xFF6B3A3A),
    danger500: Color(0xFF6B3A3A),
    danger100: Color(0xFFF2D9D3),
    info700: Color(0xFF6B3A3A),
    info500: Color(0xFF9A5A55),
    info100: Color(0xFFF8E4DE),
  );
}

/// Colour tokens for the active palette.
///
/// These are getters, not constants: the palette is swapped at runtime by
/// [ThemeController] when the user's gender is known, so never capture them
/// in a `const` expression.
class AppColors {
  AppColors._();

  static AiwaPalette _p = AiwaPalettes.male;

  static AiwaPalette get palette => _p;

  static void use(AiwaPalette palette) => _p = palette;

  // Base-brand literals the kit hard-codes in JSX/CSS, so they stay plum/pink
  // in both themes (tokens/colors_and_type.css:22-65, not runtime-themed).
  static const Color scrim = Color(0xFF2A1320); // base plum-900: scrims, toast
  static const Color shadowTint = Color(0xFF4A1F38); // base plum-700
  static const Color shadowInk = Color(0xFF1A1316); // base ink
  static const Color glowRose = Color(0xFFE7BAB6); // base rose-300
  static const Color glowGold = Color(0xFFD8B98A); // base gold-300
  static const Color focusRing = Color(0xFF7E3A5C); // states.jsx:17

  // Primary
  static Color get plum900 => _p.plum900;
  static Color get plum700 => _p.plum700;
  static Color get plum500 => _p.plum500;
  static Color get plum300 => _p.plum300;
  static Color get plum100 => _p.plum100;

  // Accent
  static Color get rose700 => _p.rose700;
  static Color get rose500 => _p.rose500;
  static Color get rose300 => _p.rose300;
  static Color get rose100 => _p.rose100;

  // Premium / rating
  static Color get gold700 => _p.gold700;
  static Color get gold500 => _p.gold500;
  static Color get gold300 => _p.gold300;
  static Color get gold100 => _p.gold100;

  // Neutrals
  static Color get ink => _p.ink;
  static Color get ink2 => _p.ink2;
  static Color get ink3 => _p.ink3;
  static Color get ink4 => _p.ink4;
  static Color get bone => _p.bone;
  static Color get cream => _p.cream;
  static Color get paper => _p.paper;
  static Color get divider => _p.divider;
  static Color get hover => _p.hover;

  // Semantic
  static Color get success700 => _p.success700;
  static Color get success500 => _p.success500;
  static Color get success100 => _p.success100;
  static Color get warn700 => _p.warn700;
  static Color get warn500 => _p.warn500;
  static Color get warn100 => _p.warn100;
  static Color get danger700 => _p.danger700;
  static Color get danger500 => _p.danger500;
  static Color get danger100 => _p.danger100;
  static Color get info700 => _p.info700;
  static Color get info500 => _p.info500;
  static Color get info100 => _p.info100;

  // Semantic shorthand aliases
  static Color get success => success500;
  static Color get danger => danger500;
  static Color get warn => warn500;
  static Color get info => info500;
}
