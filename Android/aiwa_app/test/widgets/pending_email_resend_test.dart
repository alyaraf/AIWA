import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/domain/entities/user_entity.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

/// CR-05 follow-up: after the code is confirmed Personal info treats the new
/// address as the unchanged one, and the pending-email banner can ask for a
/// new code (the backend resends on PATCH /auth/me with the pending address
/// and the current password).
const _wrongPassword = 'Your current password is not correct';
const _expired = 'Code has expired';

UserEntity _user({String email = 'old@example.com', String? pending}) =>
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
  final updates = <Map<String, String?>>[];
  final codes = <String>[];

  /// Codes sent so far; the first one has expired when the page opens.
  var sentCodes = 1;

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async => Right(user);

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? profileImageUrl,
  }) async {
    updates.add({'email': email, 'currentPassword': currentPassword});
    if (email != null && email.toLowerCase() != user.email) {
      if (currentPassword != 'right-pw') {
        return const Left(ServerFailure(_wrongPassword));
      }
      sentCodes++;
      user = _user(email: user.email!, pending: email);
    }
    return Right(user);
  }

  @override
  Future<Either<Failure, void>> verifyEmail({required String code}) async {
    codes.add(code);
    if (sentCodes < 2) return const Left(ServerFailure(_expired));
    if (code != '123456') return const Left(ServerFailure('Wrong code'));
    user = _user(email: user.pendingEmail!);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<AuthBloc> _open(WidgetTester tester, _Repo repo) async {
  final bloc = AuthBloc(
    loginUseCase: LoginUseCase(repo),
    registerUseCase: RegisterUseCase(repo),
    sendOtpUseCase: SendOtpUseCase(repo),
    verifyOtpUseCase: VerifyOtpUseCase(repo),
    getCurrentUserUseCase: GetCurrentUserUseCase(repo),
    updateProfileUseCase: UpdateProfileUseCase(repo),
    secureStorage: SecureStorage(const FlutterSecureStorage()),
  )..add(AuthGetCurrentUserEvent());
  await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
  addTearDown(bloc.close);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/page', builder: (_, _) => const EditProfilePage()),
    ],
  );
  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  router.push('/page');
  await _settle(tester);
  return bloc;
}

Finder get _sheetFields => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(TextField),
);

Finder _sheetText(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

/// Not pumpAndSettle: a loading AiwaButton animates forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Third field on the page is the email.
String _emailField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text;

void main() {
  setUpAll(useTestFonts);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(sl.reset);

  testWidgets(
    'after the code is confirmed the field holds the new email and a Save of '
    'other fields sends no email change and asks no password',
    (tester) async {
      final repo = _Repo()..sentCodes = 2;
      sl.registerSingleton<AuthRepository>(repo);
      await _open(tester, repo);
      expect(_emailField(tester), 'old@example.com');

      await tester.tap(find.text('Enter the code'));
      await _settle(tester);
      await tester.enterText(_sheetFields.first, '123456');
      await tester.pump();
      await tester.tap(_sheetText('Verify'));
      await _settle(tester);
      expect(repo.codes, ['123456']);
      expect(_emailField(tester), 'new@example.com');

      await tester.enterText(find.byType(TextField).first, 'Salma A.');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await _settle(tester);

      // No password sheet; the email sent is the confirmed one, unchanged.
      expect(find.byType(BottomSheet), findsNothing);
      expect(repo.updates, [
        {'email': 'new@example.com', 'currentPassword': null},
      ]);
      expect(find.byType(EditProfilePage), findsNothing);
    },
  );

  testWidgets(
    'expired code: "Send the code again" asks for the password, resends to '
    'the pending address, then the new code confirms it',
    (tester) async {
      final repo = _Repo();
      sl.registerSingleton<AuthRepository>(repo);
      await _open(tester, repo);

      // The first code has expired: the sheet shows it and stays usable.
      await tester.tap(find.text('Enter the code'));
      await _settle(tester);
      await tester.enterText(_sheetFields.first, '123456');
      await tester.pump();
      await tester.tap(_sheetText('Verify'));
      await _settle(tester);
      expect(_sheetText(_expired), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await _settle(tester);

      await tester.tap(find.text('Send the code again'));
      await _settle(tester);
      // Password first; a wrong one shows in the sheet, which stays open.
      expect(_sheetFields, findsOneWidget);
      await tester.enterText(_sheetFields.first, 'wrong-pw');
      await tester.pump();
      await tester.tap(_sheetText('Confirm'));
      await _settle(tester);
      expect(_sheetText(_wrongPassword), findsOneWidget);

      await tester.enterText(_sheetFields.first, 'right-pw');
      await tester.pump();
      await tester.tap(_sheetText('Confirm'));
      await _settle(tester);
      expect(repo.updates.last, {
        'email': 'new@example.com',
        'currentPassword': 'right-pw',
      });

      // Then the code step for the pending address.
      expect(_sheetText('Confirm your new email'), findsOneWidget);
      await tester.enterText(_sheetFields.first, '123456');
      await tester.pump();
      await tester.tap(_sheetText('Verify'));
      await _settle(tester);
      expect(repo.user.email, 'new@example.com');
      expect(find.text('Send the code again'), findsNothing);
      expect(_emailField(tester), 'new@example.com');
    },
  );
}
