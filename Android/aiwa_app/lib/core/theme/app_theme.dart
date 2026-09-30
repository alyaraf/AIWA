import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 999;
  // The kit's recurring inline radii (JSX borderRadius literals).
  static const double radius2 = 2; // progress bars, sheet handles
  static const double radius10 = 10;
  static const double radius14 = 14;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius22 = 22;

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 32;
  static const double s8 = 40;
  static const double s9 = 56;
  static const double s10 = 72;

  static const double gutter = 22;

  /// "Soft door" easing from the design tokens.
  static const Curve easeSoft = Cubic(.32, .72, 0, 1);
  static const Curve easeOut = Cubic(.22, .61, .36, 1);
  static const Curve easeIn = Cubic(.55, .055, .675, .19);
  static const Curve easeBounce = Cubic(.34, 1.56, .64, 1);
  static const Duration dur1 = Duration(milliseconds: 120);
  static const Duration dur2 = Duration(milliseconds: 200);
  static const Duration dur3 = Duration(milliseconds: 320);
  static const Duration dur4 = Duration(milliseconds: 480);
  /// Half-cycle of the design's 1.1s `aiwa-pulse`, for `repeat(reverse: true)`.
  static const Duration durPulse = Duration(milliseconds: 550);

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.paper,
    borderRadius: BorderRadius.circular(radiusLg),
    border: Border.all(color: AppColors.divider, width: 1),
  );

  static BoxDecoration get sheetDecoration => BoxDecoration(
    color: AppColors.bone,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusXl)),
    boxShadow: [
      BoxShadow(
        color: AppColors.scrim.withValues(alpha: 0.20), // states.jsx:240
        blurRadius: 32,
        offset: const Offset(0, -12),
      ),
    ],
  );

  /// Hero gradient used on splash, profile header, provider cover, etc.
  static LinearGradient get heroGradient => LinearGradient(
    // CSS 160deg (prototype.jsx:357): top-left of centre to bottom-right.
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    transform: const GradientRotation(-20 * math.pi / 180),
    colors: [AppColors.plum700, AppColors.plum900],
  );

  static List<BoxShadow> get shadow1 => [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.06),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.shadowInk.withValues(alpha: 0.04),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadow2 => [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.08),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.shadowInk.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadow3 => [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.14),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.shadowInk.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadow4 => [
    BoxShadow(
      color: AppColors.scrim.withValues(alpha: 0.22),
      blurRadius: 60,
      offset: const Offset(0, 24),
    ),
  ];

  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: AppColors.shadowInk.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Booking / request cards: `0 1px 2px rgba(74,31,56,.04)`.
  static List<BoxShadow> get shadowHairline => [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get toastShadow => [
    BoxShadow(
      color: AppColors.shadowTint.withValues(alpha: 0.30),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  static OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius14),
    borderSide: BorderSide(color: color, width: 1.5),
    // No floating labels; the default 4px gap pushes text past the 14px pad.
    gapPadding: 0,
  );

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bone,
      // No ripple anywhere in the kit; rows tint to hover (states.jsx:16).
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.hover,
      focusColor: AppColors.focusRing.withValues(alpha: .24),
      canvasColor: AppColors.bone,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.plum700,
        primary: AppColors.plum700,
        onPrimary: AppColors.paper,
        secondary: AppColors.rose500,
        onSecondary: AppColors.plum900,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.danger500,
        onError: AppColors.paper,
        brightness: Brightness.light,
      ),
      textTheme:
          (aiwaUseGoogleFonts
                  ? GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
                  : base.textTheme)
              .apply(fontFamilyFallback: const [kArabicSans])
              .copyWith(
                displayLarge: AppTextStyles.display,
                headlineLarge: AppTextStyles.h1,
                headlineMedium: AppTextStyles.h2,
                headlineSmall: AppTextStyles.h3,
                titleLarge: AppTextStyles.h4,
                bodyLarge: AppTextStyles.bodyLg,
                bodyMedium: AppTextStyles.body,
                bodySmall: AppTextStyles.bodySm,
                labelLarge: AppTextStyles.label,
                labelMedium: AppTextStyles.labelSm,
                labelSmall: AppTextStyles.eyebrow,
              ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bone,
        foregroundColor: AppColors.plum900,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: AppTextStyles.h3,
        iconTheme: IconThemeData(color: AppColors.plum700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.plum700,
          foregroundColor: AppColors.paper,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.plum700,
          side: BorderSide(color: AppColors.plum700, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.plum700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.plum700,
          textStyle: AppTextStyles.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: inputBorder(AppColors.divider),
        enabledBorder: inputBorder(AppColors.divider),
        focusedBorder: inputBorder(AppColors.plum700),
        errorBorder: inputBorder(AppColors.danger500),
        focusedErrorBorder: inputBorder(AppColors.danger500),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.ink4),
        labelStyle: AppTextStyles.label,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.scrim.withValues(alpha: 0.96),
        contentTextStyle: AppTextStyles.bodySm.copyWith(
          color: AppColors.bone,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.bone,
        modalBackgroundColor: AppColors.bone,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.plum700,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.plum700,
        overlayColor: AppColors.plum700.withValues(alpha: 0.12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SoftDoorTransitionsBuilder(),
          TargetPlatform.iOS: SoftDoorTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: AppColors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}

/// Push = slide in from 8% (aiwa-slide-in); the page underneath eases to
/// .98 and back up on pop (aiwa-fade-in). 320ms soft door both ways.
class SoftDoorTransitionsBuilder extends PageTransitionsBuilder {
  const SoftDoorTransitionsBuilder();

  @override
  Duration get transitionDuration => AppTheme.dur3;

  @override
  Duration get reverseTransitionDuration => AppTheme.dur3;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final soft = CurvedAnimation(parent: animation, curve: AppTheme.easeSoft);
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: .98).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: AppTheme.easeSoft),
      ),
      child: DualTransitionBuilder(
        animation: animation,
        forwardBuilder: (_, a, c) => SlideTransition(
          position: Tween(
            begin: const Offset(.08, 0),
            end: Offset.zero,
          ).animate(soft),
          child: c,
        ),
        // The prototype drops the popped screen; fade it so it doesn't
        // cover the one being revealed for 320ms.
        reverseBuilder: (_, a, c) => FadeTransition(opacity: soft, child: c),
        child: child,
      ),
    );
  }
}
