// Audit follow-up to M-05: a provider sign-up can be resumed after the app was killed between steps, from a checkpoint
// that holds no password, OTP or contact, and every step is safe to repeat.
import 'dart:convert';
import 'dart:io';

import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aiwa_app/features/auth/domain/provider_setup.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/features/auth/presentation/pages/provider_pending_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// The server: it remembers what it received, like a real one across app restarts.
class _Server implements AuthRemoteDataSource {
  bool hasProfile = false;
  final staff = <String>[];
  final calls = <String>[];
  String? failStaffNamed;
  bool docsUploaded = false;

  @override
  Future<UserModel> getCurrentUser() async => UserModel.fromJson({
    'id': 7,
    'fullName': 'Nadia',
    'role': 'PROVIDER',
    if (hasProfile) 'providerProfileId': 12,
    if (hasProfile) 'providerStatus': 'PENDING_VERIFICATION',
    'providerOnboarding': !hasProfile ? 'NO_PROFILE' : docsUploaded ? 'SUBMITTED' : 'NEEDS_DOCUMENTS',
  });

  @override
  Future<Map<String, dynamic>> latestTerms(String type) async => {'version': '2.0', 'contentEn': 'x', 'contentAr': ''};

  @override
  Future<void> acceptTerms(String version) async => calls.add('terms:$version');

  @override
  Future<void> updatePreferences({required double minKm, required double maxKm}) async => calls.add('prefs');

  @override
  Future<void> createProviderProfile(Map<String, dynamic> profile) async {
    calls.add('createProfile');
    hasProfile = true;
  }

  @override
  Future<List<String>> staffNames(int providerId) async => List.of(staff);

  @override
  Future<void> addStaff(String fullName) async {
    calls.add('addStaff:$fullName');
    if (fullName == failStaffNamed) throw const NetworkException();
    staff.add(fullName);
  }

  @override
  Future<void> uploadVerificationDocuments({
    required String idFront,
    required String idBack,
    required String selfie,
  }) async {
    calls.add('docs');
    docsUploaded = true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ProviderSetupCheckpoint _cp({int done = 0, String userId = '7'}) => ProviderSetupCheckpoint(
  userId: userId,
  done: done,
  minKm: 2,
  maxKm: 9,
  language: 'en',
  termsVersion: '2.0',
  termsType: 'PROVIDER_TERMS',
  profile: const {'businessName': 'Studio', 'primaryCategory': 'HAIR'},
  staff: const ['Mona', 'Dina', 'Rania'],
  idFront: '/cache/front.jpg',
  idBack: '/cache/back.jpg',
  selfie: '/cache/selfie.jpg',
);

void main() {
  setUpAll(useTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('killing the app after the profile was created loses neither the staff nor the documents', () async {
    final server = _Server()..failStaffNamed = 'Dina';
    var storage = SecureStorage(const FlutterSecureStorage());
    var repo = AuthRepositoryImpl(server, storage);

    // process 1: terms + radius done, the profile is created, Mona added, then the connection dies on Dina
    var cp = _cp();
    await storage.saveSetupCheckpoint(cp.encode());
    final first = await runProviderSetup(repo, cp, fileExists: (_) => true, onProgress: (n) async {
      await storage.saveSetupCheckpoint(cp.withDone(n).encode());
    });
    expect(first, isA<NetworkFailure>());
    expect(server.calls, ['terms:2.0', 'prefs', 'createProfile', 'addStaff:Mona', 'addStaff:Dina']);

    // process 2: everything in memory is gone; only secure storage and the server remain
    storage = SecureStorage(const FlutterSecureStorage());
    repo = AuthRepositoryImpl(server, storage);
    server
      ..failStaffNamed = null
      ..calls.clear();
    final restored = ProviderSetupCheckpoint.decode(await storage.getSetupCheckpoint())!;
    expect(restored.done, 2, reason: 'terms and radius are not repeated');
    expect(restored.staff, ['Mona', 'Dina', 'Rania']);
    final second = await runProviderSetup(repo, restored, fileExists: (_) => true);
    expect(second, isNull);
    expect(server.calls, ['addStaff:Dina', 'addStaff:Rania', 'docs'], reason: 'no second profile, no duplicate Mona');
    expect(server.staff, ['Mona', 'Dina', 'Rania']);
  });

  test('the checkpoint holds no password, OTP, contact or token', () {
    final json = jsonDecode(_cp().encode()) as Map<String, dynamic>;
    expect(json.keys.toSet(), {
      'userId', 'done', 'minKm', 'maxKm', 'language', 'termsVersion', 'termsType', 'gender', 'profile', 'staff',
      'idFront', 'idBack', 'selfie',
    });
    final text = _cp().encode().toLowerCase();
    for (final secret in ['password', 'otp', 'phone', 'email', 'token', 'receipt']) {
      expect(text.contains(secret), isFalse, reason: secret);
    }
  });

  test('ID photos that are gone are reported, earlier steps stay done, and the run completes once they exist again', () async {
    final server = _Server();
    final storage = SecureStorage(const FlutterSecureStorage());
    final repo = AuthRepositoryImpl(server, storage);
    final saved = <int>[];
    final failure = await runProviderSetup(repo, _cp(), fileExists: (_) => false, onProgress: saved.add);
    expect(failure, isA<DocumentsMissingFailure>());
    expect(saved, [1, 2, 3], reason: 'terms, radius and the profile are finished and recorded');
    expect(server.docsUploaded, isFalse);

    final again = await runProviderSetup(repo, _cp(done: 3), fileExists: (_) => true);
    expect(again, isNull);
    expect(server.docsUploaded, isTrue);
  });

  test('a customer finishes after the preferences: no profile and no documents', () async {
    final server = _Server();
    final repo = AuthRepositoryImpl(server, SecureStorage(const FlutterSecureStorage()));
    expect(await runProviderSetup(repo, _cp(), provider: false), isNull);
    expect(server.calls, ['terms:2.0', 'prefs']);
  });

  test('a corrupt or foreign value is "no checkpoint", and sign-out deletes the real one', () async {
    expect(ProviderSetupCheckpoint.decode('{not json'), isNull);
    expect(ProviderSetupCheckpoint.decode(null), isNull);
    expect(ProviderSetupCheckpoint.decode('{"userId":1}'), isNull);
    final storage = SecureStorage(const FlutterSecureStorage());
    await storage.saveSetupCheckpoint(_cp().encode());
    expect(await storage.getSetupCheckpoint(), isNotNull);
    await storage.clearAll();
    expect(await storage.getSetupCheckpoint(), isNull);
  });

  testWidgets('the pending screen offers to finish a saved setup, runs it and removes the checkpoint', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('aiwa-setup');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final n in ['front', 'back', 'selfie']) {
      File('${dir.path}/$n.jpg').writeAsStringSync('x');
    }
    final cp = ProviderSetupCheckpoint(
      userId: '7', done: 2, minKm: 2, maxKm: 9, language: 'en', termsVersion: '2.0', termsType: 'PROVIDER_TERMS',
      profile: const {'businessName': 'Studio'}, staff: const ['Mona'],
      idFront: '${dir.path}/front.jpg', idBack: '${dir.path}/back.jpg', selfie: '${dir.path}/selfie.jpg',
    );
    FlutterSecureStorage.setMockInitialValues({'provider_setup_checkpoint': cp.encode()});
    final server = _Server();
    final storage = SecureStorage(const FlutterSecureStorage());
    final repo = AuthRepositoryImpl(server, storage);
    for (final t in <Type>[SecureStorage, AuthRepository]) {
      if (t == SecureStorage && sl.isRegistered<SecureStorage>()) sl.unregister<SecureStorage>();
      if (t == AuthRepository && sl.isRegistered<AuthRepository>()) sl.unregister<AuthRepository>();
    }
    sl.registerSingleton<SecureStorage>(storage);
    sl.registerSingleton<AuthRepository>(repo);
    addTearDown(() {
      sl.unregister<SecureStorage>();
      sl.unregister<AuthRepository>();
    });

    final bloc = AuthBloc(authRepository: repo, secureStorage: storage)..add(AuthGetCurrentUserEvent());
    await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ProviderPendingPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    server.hasProfile = true; // the profile exists server side (NEEDS_DOCUMENTS) after the earlier run
    bloc.add(AuthGetCurrentUserEvent());
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('resume-setup'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(server.calls, ['addStaff:Mona', 'docs']);
    expect(await storage.getSetupCheckpoint(), isNull);
    expect(server.docsUploaded, isTrue);
  });
}
