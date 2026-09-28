import 'package:aiwa_app/core/theme/app_text_styles.dart';
import 'package:aiwa_app/core/theme/theme_controller.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Call from `setUpAll`: text styles use plain family names instead of
/// google_fonts (which would try to download fonts during tests).
void useTestFonts() {
  aiwaUseGoogleFonts = false;
}

/// Back to the default (charcoal) palette without touching storage.
void resetPalette() {
  ThemeController.set(ThemeController.male, persist: false);
}

/// Hosts a widget inside a minimal app.
Widget host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);
