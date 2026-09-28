# aiwa_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Tests

```bash
flutter analyze
flutter test                                  # unit, widget and golden tests
flutter test --update-goldens test/goldens    # after an intended UI change
```

Goldens (`test/goldens/`) cover Home, Provider profile, Booking (Book now)
and Tracking in both palettes, LTR and RTL. They load the bundled fonts and
serve fixtures captured from the seeded backend, so no network is needed.
Goldens are platform-specific: regenerate them on the OS your CI runs.

The end-to-end booking lifecycle (`integration_test/`) needs a device or
emulator and a backend seeded by `LocalDataSeeder` (Spring `local` profile).
Accounts come from the seeder; the password is passed in, not committed:

```bash
flutter test integration_test --dart-define=API_BASE_URL=http://10.0.2.2:8080/api --dart-define=E2E_PASSWORD=<seed password>
```

Override `E2E_CUSTOMER`, `E2E_PROVIDER`, `E2E_PROVIDER_NAME` and
`E2E_SERVICE` with `--dart-define` for other environments. The test opens
today's hours for the provider and adds an `E2E` address for the customer
before it starts.

Crash reporting is off unless a DSN is passed:
`--dart-define=SENTRY_DSN=https://…`.
