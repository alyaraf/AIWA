// M-05: the pending screen says what is really missing, and offers the way to finish.
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/domain/entities/user_entity.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/features/auth/presentation/pages/provider_pending_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

class _Repo implements AuthRepository {
  _Repo(this.user);
  UserEntity user;

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async => Right(user);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

UserModel _provider(String? onboarding, {bool profile = true}) => UserModel.fromJson({
  'id': 7,
  'fullName': 'Nadia',
  'role': 'PROVIDER',
  'providerOnboarding': onboarding,
  if (profile) 'providerProfileId': 12,
  if (profile) 'providerStatus': 'PENDING_VERIFICATION',
});

Future<void> _open(WidgetTester tester, UserModel user) async {
  // a phone-sized screen: the page is laid out for one, the default 800x600 test surface is shorter than its content
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final bloc = AuthBloc(
    authRepository: _Repo(user),
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
        home: const ProviderPendingPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(useTestFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('no business profile: it says setup is unfinished and offers to continue, not "ID received"', (tester) async {
    await _open(tester, _provider('NO_PROFILE', profile: false));
    expect(find.text('Finish setting up your business'), findsOneWidget);
    expect(find.text('Continue setup'), findsOneWidget);
    expect(find.textContaining('ID received'), findsNothing);
    expect(find.textContaining('Admin review'), findsNothing);
  });

  testWidgets('profile saved but documents missing: it asks for the documents', (tester) async {
    await _open(tester, _provider('NEEDS_DOCUMENTS'));
    expect(find.text('Upload your ID'), findsOneWidget);
    expect(find.text('Upload documents'), findsOneWidget);
    expect(find.textContaining('ID received'), findsNothing);
  });

  testWidgets('everything submitted: the usual waiting-for-review status', (tester) async {
    await _open(tester, _provider('SUBMITTED'));
    expect(find.text('Finish setting up your business'), findsNothing);
    expect(find.text('Upload documents'), findsNothing);
    expect(find.textContaining('ID'), findsWidgets);
  });
}
