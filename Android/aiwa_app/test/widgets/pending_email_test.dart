import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/domain/entities/user_entity.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/features/profile/data/account_repository.dart';
import 'package:aiwa_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:aiwa_app/features/profile/presentation/pages/profile_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

/// CR-05: an email added to the account waits in pendingEmail (GET /auth/me).
/// The profile shows it, and Personal info offers the code step until it is
/// confirmed.
UserEntity _user({String? pending, String email = 'old@example.com'}) =>
    UserEntity(
      id: 7,
      fullName: 'Salma Adel',
      email: email,
      pendingEmail: pending,
      phone: '+201001112222',
      role: 'CUSTOMER',
      active: true,
      preferredLanguage: 'EN',
      termsAccepted: true,
    );

class _Repo implements AuthRepository {
  UserEntity user = _user(pending: 'new@example.com');
  final codes = <String>[];

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async => Right(user);

  @override
  Future<Either<Failure, void>> verifyEmail({required String code}) async {
    codes.add(code);
    if (code != '123456') return const Left(ServerFailure('Wrong code'));
    user = _user(email: 'new@example.com');
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<AuthBloc> _open(WidgetTester tester, _Repo repo, Widget page) async {
  final bloc = AuthBloc(
    authRepository: repo,
    secureStorage: SecureStorage(const FlutterSecureStorage()),
  )..add(AuthGetCurrentUserEvent());
  await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
  addTearDown(bloc.close);
  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  await _settle(tester);
  return bloc;
}

/// Not pumpAndSettle: a loading AiwaButton animates forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(useTestFonts);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(sl.reset);

  testWidgets('profile shows the email that is waiting for its code', (
    tester,
  ) async {
    sl.registerSingleton<AccountRepository>(
      AccountRepository(ApiClient(SecureStorage(const FlutterSecureStorage()))),
    );
    await _open(tester, _Repo(), const ProfilePage());
    expect(
      find.text('Waiting for you to confirm new@example.com.'),
      findsOneWidget,
    );
  });

  testWidgets('Personal info: pending email -> code -> confirmed', (
    tester,
  ) async {
    final repo = _Repo();
    sl.registerSingleton<AuthRepository>(repo);
    final bloc = await _open(tester, repo, const EditProfilePage());
    const waiting = 'Waiting for you to confirm new@example.com.';
    expect(find.text(waiting), findsOneWidget);

    await tester.tap(find.text('Enter the code'));
    await _settle(tester);
    final field = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget); // code only, no password
    await tester.enterText(field, '123456');
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Verify'),
      ),
    );
    await _settle(tester);

    expect(repo.codes, ['123456']);
    expect(find.text(waiting), findsNothing);
    expect((bloc.state as AuthAuthenticated).user.email, 'new@example.com');
  });
}
