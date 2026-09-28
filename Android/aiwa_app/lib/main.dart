import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/theme_controller.dart';
import 'app.dart';

void main() async {
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
