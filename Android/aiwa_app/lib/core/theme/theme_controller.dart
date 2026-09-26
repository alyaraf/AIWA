import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

/// Runtime palette switch — the gender picked at signup recolours the whole
/// app (design handoff: "implement as a runtime theme swap, not two builds").
///
/// `male` is the spec-defined default. Listen to [mode] to rebuild on change.
class ThemeController {
  ThemeController._();

  static const String male = 'male';
  static const String female = 'female';
  static const String _prefsKey = 'aiwa_theme';

  static final ValueNotifier<String> mode = ValueNotifier<String>(male);

  /// Restores the last used palette. Call once before `runApp`.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apply(prefs.getString(_prefsKey) ?? male);
    } catch (_) {
      _apply(male);
    }
  }

  /// Maps a backend gender value (`MALE` / `FEMALE`) to a palette.
  static void applyGender(String? gender, {bool persist = true}) {
    set(gender?.toUpperCase() == 'FEMALE' ? female : male, persist: persist);
  }

  static void set(String name, {bool persist = true}) {
    _apply(name);
    if (persist) {
      SharedPreferences.getInstance()
          .then((p) => p.setString(_prefsKey, mode.value))
          .catchError((_) => false);
    }
  }

  static void _apply(String name) {
    final next = name == female ? female : male;
    AppColors.use(next == female ? AiwaPalettes.female : AiwaPalettes.male);
    mode.value = next;
  }
}
