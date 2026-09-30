import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/constants/api_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/theme_controller.dart';
import 'app.dart';

void main() async {
  // FE-1: a release binary must never talk to the emulator loopback or plain
  // http. Android also blocks this at build time (checkReleaseConfig); this
  // catches iOS and any build that skipped the Gradle check.
  if (kReleaseMode && !ApiConstants.baseUrl.startsWith('https://')) {
    throw StateError(
      'Release build without an https API_BASE_URL. '
      'Build with tool/build_release.sh (see docs/release.md).',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets/google_fonts/; never fetch over the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await di.initDependencies();
  await ThemeController.load();
  await LocaleController.load();
  // --dart-define=SENTRY_DSN=…; empty (dev, tests) keeps Sentry off.
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isEmpty) return runApp(const AiwaApp());
  await SentryFlutter.init(
    (o) => o
      ..dsn = dsn
      ..sendDefaultPii = false,
    appRunner: () => runApp(const AiwaApp()),
  );
}
