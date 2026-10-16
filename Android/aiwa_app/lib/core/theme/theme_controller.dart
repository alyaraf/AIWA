import 'dart:ui';
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
  static const String _pickedKey = 'aiwa_theme_picked';

  /// True once the user chose a palette in Personal info; gender no longer
  /// overrides it (every /auth/me refresh re-applies the gender otherwise).
  static bool _picked = false;

  static final ValueNotifier<String> mode = ValueNotifier<String>(male);

  /// Restores the last used palette. Call once before `runApp`.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _picked = prefs.getBool(_pickedKey) ?? false;
      _apply(prefs.getString(_prefsKey) ?? male);
    } catch (_) {
      _apply(male);
    }
  }

  /// Maps a backend gender value (`MALE` / `FEMALE`) to a palette.
  static void applyGender(String? gender, {bool persist = true}) {
    if (_picked) return;
    set(gender?.toUpperCase() == 'FEMALE' ? female : male, persist: persist);
  }

  /// The user's own choice: wins over [applyGender] from now on.
  static void pick(String name) {
    _picked = true;
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_pickedKey, true))
        .catchError((_) => false);
    set(name);
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

/// App language — `en` / `ar`, picked on Splash and Preferences. `ar` flips
/// the app to RTL through MaterialApp.locale.
class LocaleController {
  LocaleController._();

  static const String _prefsKey = 'aiwa_language';
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      locale.value = Locale(prefs.getString(_prefsKey) ?? 'en');
    } catch (_) {}
  }

  static void set(String code) {
    locale.value = Locale(code);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_prefsKey, code))
        .catchError((_) => false);
  }
}
