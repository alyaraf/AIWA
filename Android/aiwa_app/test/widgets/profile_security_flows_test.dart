import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_client.dart';
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
import 'package:aiwa_app/features/profile/data/account_repository.dart';
import 'package:aiwa_app/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:aiwa_app/features/profile/presentation/pages/profile_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

/// CR-05: the backend wants the current password for an email change, a phone
/// change and account deletion, and a code for the new email. These drive the
/// real pages against a fake repository / HTTP adapter.

const _wrongPassword = 'Your current password is not correct';
const _wrongCode = 'Incorrect code. Please try again.';

UserEntity _user({
  String email = 'old@example.com',
  String phone = '+201001112222',
}) => UserEntity(
  id: 7,
  fullName: 'Salma Adel',
  email: email,
  phone: phone,
  role: 'CUSTOMER',
  active: true,
  preferredLanguage: 'EN',
  termsAccepted: true,
);

/// Enforces the U05 backend rules; records what the app sent.
class _FakeAuthRepo implements AuthRepository {
  UserEntity user = _user();
  final updates = <Map<String, String?>>[];
  final phoneChanges = <Map<String, String>>[];
  final verifiedCodes = <String>[];
  final otpsTo = <String>[];
  String? pendingEmail;

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async => Right(user);

  @override
  Future<Either<Failure, void>> sendOtp({required String phone}) async {
    otpsTo.add(phone);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> changePhone({
    required String phone,
    required String code,
    String? currentPassword,
  }) async {
    phoneChanges.add({
      'phone': phone,
      'code': code,
      'currentPassword': currentPassword ?? '',
    });
    if (currentPassword != 'right-pw') {
      return const Left(ServerFailure(_wrongPassword));
    }
    user = _user(email: user.email!, phone: phone);
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? fullName,
    String? email,
    String? currentPassword,
    String? profileImageUrl,
  }) async {
    updates.add({'email': email, 'currentPassword': currentPassword});
    final changed = email != null && email != user.email;
    if (changed && currentPassword != 'right-pw') {
      return const Left(ServerFailure(_wrongPassword));
    }
    if (changed) pendingEmail = email;
    return Right(user);
  }

  @override
  Future<Either<Failure, void>> verifyEmail({required String code}) async {
    verifiedCodes.add(code);
    if (code != '123456') return const Left(ServerFailure(_wrongCode));
    user = _user(email: pendingEmail!, phone: user.phone!);
    pendingEmail = null;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

AuthBloc _bloc(_FakeAuthRepo repo) => AuthBloc(
  loginUseCase: LoginUseCase(repo),
  registerUseCase: RegisterUseCase(repo),
  sendOtpUseCase: SendOtpUseCase(repo),
  verifyOtpUseCase: VerifyOtpUseCase(repo),
  getCurrentUserUseCase: GetCurrentUserUseCase(repo),
  updateProfileUseCase: UpdateProfileUseCase(repo),
  secureStorage: SecureStorage(const FlutterSecureStorage()),
);

/// Pumps [page] at /page on top of a placeholder at /, so pop() has somewhere
/// to go; returns the bloc.
Future<AuthBloc> _open(
  WidgetTester tester,
  _FakeAuthRepo repo,
  Widget page,
) async {
  final bloc = _bloc(repo)..add(AuthGetCurrentUserEvent());
  await bloc.stream.firstWhere((s) => s is AuthAuthenticated);
  addTearDown(bloc.close);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(path: '/page', builder: (_, _) => page),
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

void main() {
  setUpAll(useTestFonts);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('edit profile', () {
    late _FakeAuthRepo repo;

    setUp(() {
      repo = _FakeAuthRepo();
      sl.registerSingleton<AuthRepository>(repo);
    });
    tearDown(sl.reset);

    testWidgets(
      'email change: password sheet (wrong password stays usable), then the code step',
      (tester) async {
        final bloc = await _open(tester, repo, const EditProfilePage());

        // Third field is the email.
        await tester.enterText(find.byType(TextField).at(2), 'new@example.com');
        await tester.pump();
        await tester.tap(find.text('Save changes'));
        await _settle(tester);

        // Asks for the current password before anything is sent.
        expect(_sheetText("Confirm it's you"), findsOneWidget);
        await tester.enterText(_sheetFields.first, 'wrong-pw');
        await tester.pump();
        await tester.tap(_sheetText('Confirm'));
        await _settle(tester);

        // Wrong password: the error shows in the sheet and it stays open.
        expect(repo.updates.last['currentPassword'], 'wrong-pw');
        expect(_sheetText(_wrongPassword), findsOneWidget);
        expect(_sheetText("Confirm it's you"), findsOneWidget);

        await tester.enterText(_sheetFields.first, 'right-pw');
        await tester.pump();
        await tester.tap(_sheetText('Confirm'));
        await _settle(tester);
        expect(repo.updates.last, {
          'email': 'new@example.com',
          'currentPassword': 'right-pw',
        });

        // Code step for the new address.
        expect(_sheetText('Confirm your new email'), findsOneWidget);
        expect(
          _sheetText('We sent a 6-digit code to new@example.com.'),
          findsOneWidget,
        );
        await tester.enterText(_sheetFields.first, '000000');
        await tester.pump();
        await tester.tap(_sheetText('Verify'));
        await _settle(tester);
        expect(_sheetText(_wrongCode), findsOneWidget);
        expect(_sheetText('Confirm your new email'), findsOneWidget);

        await tester.enterText(_sheetFields.first, '123456');
        await tester.pump();
        await tester.tap(_sheetText('Verify'));
        await _settle(tester);

        expect(repo.verifiedCodes, ['000000', '123456']);
        // Saved: the page closed and the shown email is the confirmed one.
        expect(find.byType(EditProfilePage), findsNothing);
        expect((bloc.state as AuthAuthenticated).user.email, 'new@example.com');
      },
    );

    testWidgets('unchanged email asks for no password', (tester) async {
      await _open(tester, repo, const EditProfilePage());
      await tester.enterText(find.byType(TextField).first, 'Salma A.');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await _settle(tester);
      expect(repo.updates.single['currentPassword'], isNull);
      expect(find.byType(EditProfilePage), findsNothing);
    });

    testWidgets('phone change sends the current password with the code', (
      tester,
    ) async {
      await _open(tester, repo, const EditProfilePage());
      await tester.enterText(find.byType(TextField).at(1), '+201009998888');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await _settle(tester);
      expect(repo.otpsTo, ['+201009998888']);

      // Password and code are both asked; a wrong password keeps the sheet.
      expect(_sheetFields, findsNWidgets(2));
      await tester.enterText(_sheetFields.at(0), 'wrong-pw');
      await tester.enterText(_sheetFields.at(1), '654321');
      await tester.pump();
      await tester.tap(_sheetText('Verify'));
      await _settle(tester);
      expect(_sheetText(_wrongPassword), findsOneWidget);
      expect(_sheetFields, findsNWidgets(2));

      await tester.enterText(_sheetFields.at(0), 'right-pw');
      await tester.pump();
      await tester.tap(_sheetText('Verify'));
      await _settle(tester);

      expect(repo.phoneChanges.last, {
        'phone': '+201009998888',
        'code': '654321',
        'currentPassword': 'right-pw',
      });
      expect(find.byType(EditProfilePage), findsNothing);
    });
  });

  group('delete account', () {
    final bodies = <Object?>[];

    testWidgets('asks for the password; a wrong one keeps the sheet open', (
      tester,
    ) async {
      bodies.clear();
      // Tall enough for the Delete account row without scrolling.
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = ApiClient(
        SecureStorage(const FlutterSecureStorage()),
        adapter: _AccountAdapter(bodies),
      );
      sl.registerSingleton<AccountRepository>(AccountRepository(api));
      addTearDown(sl.reset);
      final repo = _FakeAuthRepo();
      await _open(tester, repo, const ProfilePage());

      await tester.tap(find.text('Delete account'));
      await _settle(tester);
      await tester.enterText(_sheetFields.first, 'DELETE');
      await tester.pump();
      await tester.tap(_sheetText('Delete account'));
      await _settle(tester);

      // Second sheet: the current password.
      expect(
        _sheetText('Enter your current password to continue.'),
        findsOneWidget,
      );
      await tester.enterText(_sheetFields.first, 'wrong-pw');
      await tester.pump();
      await tester.tap(_sheetText('Delete account'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await _settle(tester);
      expect(bodies.last, {'currentPassword': 'wrong-pw'});
      expect(_sheetText(_wrongPassword), findsOneWidget);

      await tester.enterText(_sheetFields.first, 'right-pw');
      await tester.pump();
      await tester.tap(_sheetText('Delete account'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await _settle(tester);
      expect(bodies.last, {'currentPassword': 'right-pw'});
      expect(find.text('home'), findsOneWidget);
    });
  });
}

/// DELETE /account: 400 unless the body carries the right password.
class _AccountAdapter implements HttpClientAdapter {
  _AccountAdapter(this.bodies);
  final List<Object?> bodies;
  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (o.method == 'DELETE' && o.path.endsWith('/account')) {
      bodies.add(o.data);
      final ok = (o.data as Map?)?['currentPassword'] == 'right-pw';
      return ResponseBody.fromString(
        jsonEncode(
          ok
              ? {'success': true, 'data': null}
              : {'success': false, 'message': _wrongPassword},
        ),
        ok ? 200 : 400,
        headers: _json,
      );
    }
    return ResponseBody.fromString(
      '{"success":true,"data":null}',
      200,
      headers: _json,
    );
  }

  @override
  void close({bool force = false}) {}
}
