import 'package:aiwa_app/core/theme/app_text_styles.dart';
import 'package:aiwa_app/core/theme/theme_controller.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Loads the bundled fonts under the plain family names [useTestFonts]
/// uses, plus the pubspec families (Arabic fallbacks, Material icons), so
/// goldens render real glyphs instead of Ahem boxes.
Future<void> loadAppFonts() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final byFamily = <String, List<String>>{};
  // google_fonts files: 'PlusJakartaSans-SemiBold.ttf' -> 'Plus Jakarta Sans'.
  const names = {
    'PlusJakartaSans': 'Plus Jakarta Sans',
    'DMSerifDisplay': 'DM Serif Display',
    'JetBrainsMono': 'JetBrains Mono',
  };
  for (final a in manifest.listAssets()) {
    final m = RegExp(r'google_fonts/(\w+)-\w+\.ttf$').firstMatch(a);
    final family = names[m?[1]];
    if (family != null) (byFamily[family] ??= []).add(a);
  }
  final fontManifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final f in fontManifest.cast<Map<String, dynamic>>()) {
    byFamily[f['family'] as String] = [
      for (final font in f['fonts'] as List) font['asset'] as String,
    ];
  }
  for (final MapEntry(key: family, value: assets) in byFamily.entries) {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }
}
