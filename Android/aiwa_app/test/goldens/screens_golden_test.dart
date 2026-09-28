// Goldens for the four core screens × both palettes × LTR/RTL.
// Update: flutter test --update-goldens test/goldens
// Fixtures in fixtures/ are real responses from the local seeded backend
// (aiwa-backend LocalDataSeeder), served through ApiClient's Dio adapter so
// the pages, blocs and repositories run unmodified.
import 'dart:io';
import 'dart:typed_data';

import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/core/theme/app_theme.dart';
import 'package:aiwa_app/core/theme/theme_controller.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/bookings/presentation/pages/booking_page.dart';
import 'package:aiwa_app/features/bookings/presentation/pages/tracking_page.dart';
import 'package:aiwa_app/features/home/presentation/pages/home_page.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:aiwa_app/features/providers/presentation/pages/provider_detail_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

const _providerId = '1'; // Nadia Studio
const _bookingId = '1'; // Hana's in-progress booking

/// GET path -> fixture file; anything else gets an empty success.
const _fixtures = {
  '/providers/nearby': 'providers_nearby.json',
  '/providers/$_providerId': 'provider_detail.json',
  '/providers/$_providerId/services': 'provider_services.json',
  '/providers/$_providerId/reviews': 'provider_reviews.json',
  '/bookings/$_bookingId': 'booking.json',
};

class _FixtureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final file = _fixtures[options.uri.path.replaceFirst('/api', '')];
    final body = file == null
        ? '{"success":true,"data":null}'
        : File('test/goldens/fixtures/$file').readAsStringSync();
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget _host(Widget page, Locale locale) => MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => sl<AuthBloc>()),
    BlocProvider(create: (_) => sl<NotificationBloc>()),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: page,
  ),
);

void main() {
  setUpAll(() async {
    useTestFonts();
    await loadAppFonts();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await initDependencies();
    sl.unregister<ApiClient>();
    sl.registerSingleton(
      ApiClient(sl<SecureStorage>(), adapter: _FixtureAdapter()),
    );
  });
  tearDownAll(resetPalette);

  final screens = <String, Widget Function()>{
    'home': () => const HomePage(),
    'provider': () => const ProviderDetailPage(providerId: _providerId),
    // Book-now mode: the scheduled mode's 14-day strip starts at today, so
    // its golden would change daily.
    'booking': () => const BookingPage(providerId: _providerId, mode: 'now'),
    'tracking': () => const TrackingPage(bookingId: _bookingId),
  };

  for (final palette in [ThemeController.male, ThemeController.female]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final MapEntry(key: name, value: build) in screens.entries) {
        final id = '${name}_${palette}_${locale.languageCode}';
        testWidgets(id, (tester) async {
          tester.view
            ..physicalSize = const Size(390, 844) * 2
            ..devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          ThemeController.set(palette, persist: false);
          HomePage.now = () => DateTime(2026, 9, 28, 19); // evening greeting

          await tester.pumpWidget(_host(build(), locale));
          // Plugin calls (Geolocator) and fixture reads resolve in real
          // async, Dio and animations in fake time: alternate the two.
          // (pumpAndSettle would spin forever on the tracking pulse.)
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('images/$id.png'),
          );
          // Dispose the page so polling / animation timers stop.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
