import 'package:aiwa_app/core/theme/app_colors.dart';
import 'package:aiwa_app/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(resetPalette);

  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('defaults to the charcoal / off-white (male) palette', () async {
    await ThemeController.load();

    expect(ThemeController.mode.value, ThemeController.male);
    expect(AppColors.plum700, const Color(0xFF2E2A26)); // Deep Charcoal
    expect(AppColors.plum300, const Color(0xFFB5A898)); // Warm Stone
    expect(AppColors.bone, const Color(0xFFF5F2ED)); // Off White
  });

  test('FEMALE gender switches to the mauve palette and saves it', () async {
    ThemeController.applyGender('FEMALE');
    await flush();

    expect(ThemeController.mode.value, ThemeController.female);
    expect(AppColors.plum700, const Color(0xFF6B3A3A)); // Deep Mauve
    expect(AppColors.rose500, const Color(0xFFC4837A)); // Dusty Rose
    expect(AppColors.bone, const Color(0xFFFDF6F4)); // Blush White

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('aiwa_theme'), 'female');
  });

  test('gender matching is case-insensitive; anything else is male', () {
    ThemeController.applyGender('female', persist: false);
    expect(ThemeController.mode.value, ThemeController.female);

    ThemeController.applyGender(null, persist: false);
    expect(ThemeController.mode.value, ThemeController.male);

    ThemeController.applyGender('OTHER', persist: false);
    expect(ThemeController.mode.value, ThemeController.male);
  });

  test('restores the saved palette on load', () async {
    SharedPreferences.setMockInitialValues({'aiwa_theme': 'female'});

    await ThemeController.load();

    expect(ThemeController.mode.value, ThemeController.female);
    expect(AppColors.plum700, const Color(0xFF6B3A3A));
  });

  test('an unknown saved value falls back to male', () async {
    SharedPreferences.setMockInitialValues({'aiwa_theme': 'neon'});

    await ThemeController.load();

    expect(ThemeController.mode.value, ThemeController.male);
  });

  test('notifies listeners when the palette changes', () {
    var calls = 0;
    void listener() => calls++;
    ThemeController.mode.addListener(listener);

    ThemeController.set(ThemeController.female, persist: false);
    ThemeController.set(ThemeController.female, persist: false); // no change
    ThemeController.set(ThemeController.male, persist: false);

    ThemeController.mode.removeListener(listener);
    expect(calls, 2);
  });
}
