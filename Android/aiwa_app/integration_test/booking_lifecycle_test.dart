// End-to-end booking lifecycle against a seeded backend
// (aiwa-backend LocalDataSeeder, `local` profile). See README "Tests".
//
//   customer: sign in → search → book (Book now, home service) ─┐
//   provider: accept → on the way → arrived → start → complete ─┤
//   customer: pay (confirm cash) → review ◄─────────────────────┘
//
// Sign-up isn't driven: /auth/send-otp sends a random code by SMS (the
// local profile only logs it), so a test can't read it. Add a fixed-code
// test number on staging to cover it.
import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/router/app_router.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/main.dart' as app;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// Seeded accounts (LocalDataSeeder); override for other environments.
const _customer = String.fromEnvironment(
  'E2E_CUSTOMER',
  defaultValue: 'karim@example.com',
);
const _provider = String.fromEnvironment(
  'E2E_PROVIDER',
  defaultValue: 'layla.beauty@aiwa.com', // does home service
);
const _providerName = String.fromEnvironment(
  'E2E_PROVIDER_NAME',
  defaultValue: 'Layla Beauty',
);
const _service = String.fromEnvironment(
  'E2E_SERVICE',
  defaultValue: 'Gel Manicure',
);
const _password = String.fromEnvironment('E2E_PASSWORD');
const _addressLabel = 'E2E';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('booking lifecycle: customer books, provider completes, '
      'customer pays and reviews', (tester) async {
    expect(
      _password,
      isNotEmpty,
      reason: 'pass --dart-define=E2E_PASSWORD=<seed password>',
    );
    await _arrange();
    app.main();
    await _settle(tester);

    // ── Customer ──
    await _signIn(tester, _customer);
    router.go(AppRoutes.search);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, _providerName);
    await _settle(tester);
    await _tap(tester, find.text(_providerName).first);
    await _tap(tester, find.text('Book now'));
    await _tap(tester, find.text('Get someone on the way'));
    await _tap(tester, find.text(_service));
    await _tap(tester, find.text(_addressLabel));
    await _tap(tester, find.text('Confirm booking'));
    final path = router.routerDelegate.currentConfiguration.uri.path;
    final bookingId = RegExp(r'/booking-confirmed/(\d+)').firstMatch(path)?[1];
    expect(bookingId, isNotNull, reason: 'landed on $path');
    await _signOut(tester);

    // ── Provider ──
    await _signIn(tester, _provider);
    router.go('/pro/bookings/$bookingId');
    await _settle(tester);
    for (final step in [
      'Accept',
      'On my way',
      "I've arrived",
      'Start service',
      'Mark completed',
      'Yes, cash received',
    ]) {
      await _tap(tester, find.text(step));
    }
    await _signOut(tester);

    // ── Customer ──
    await _signIn(tester, _customer);
    router.go('/booking/$bookingId/payment');
    await _settle(tester);
    await _tap(tester, find.textContaining('Yes, I paid'));
    await _tap(tester, find.text('Rate your provider'));
    await _tap(tester, find.byIcon(LucideIcons.star).last); // 5★
    await _tap(tester, find.text('Submit review'));
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.myBookings,
    );
  });
}

/// Seed data has no provider hours and no customer address; open today and
/// add one address so Book now + home service can go through.
Future<void> _arrange() async {
  final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  Future<Options> as(String email) async {
    final r = await dio.post(
      ApiConstants.login,
      data: {'identifier': email, 'password': _password},
    );
    return Options(
      headers: {'Authorization': 'Bearer ${r.data['data']['accessToken']}'},
    );
  }

  const days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  await dio.post(
    ApiConstants.providerAvailabilityCreate,
    data: {
      'dayOfWeek': days[DateTime.now().weekday - 1],
      'startTime': '00:00',
      'endTime': '23:59',
      'available': true,
    },
    options: await as(_provider),
  );

  final customer = await as(_customer);
  final addresses =
      (await dio.get(
            ApiConstants.savedAddresses,
            options: customer,
          )).data['data']
          as List;
  if (!addresses.any((a) => a['label'] == _addressLabel)) {
    await dio.post(
      ApiConstants.savedAddresses,
      data: {
        'label': _addressLabel,
        'addressLine': 'E2E test address',
        'latitude': 30.06,
        'longitude': 31.22,
        'defaultAddress': false,
      },
      options: customer,
    );
  }
}

Future<void> _signIn(WidgetTester tester, String email) async {
  router.go(AppRoutes.signIn);
  await _settle(tester);
  await _tap(tester, find.text('Email'));
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), _password);
  await _tap(tester, find.text('Sign in'));
}

Future<void> _signOut(WidgetTester tester) async {
  tester
      .element(find.byType(Navigator).first)
      .read<AuthBloc>()
      .add(AuthLogoutEvent());
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _settle(tester);
  expect(f, findsWidgets);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await _settle(tester);
}

/// pumpAndSettle can spin on live pulses; pump real time instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
