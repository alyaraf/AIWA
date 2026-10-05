// M-07: the policy being accepted is shown in full (scrollable), before consent; no six-line ellipsis.
import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/pages/terms_page.dart';
import 'package:aiwa_app/features/auth/presentation/pages/terms_reaccept_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

final _long = [for (var i = 1; i <= 60; i++) 'Clause $i of the provider policy.'].join('\n');

class _Repo implements AuthRepository {
  @override
  Future<Either<Failure, TermsDoc>> latestTerms(String type) async =>
      Right((version: '2.4.0', content: _long, contentAr: '', pdfUrl: null));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(useTestFonts);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    if (sl.isRegistered<AuthRepository>()) sl.unregister<AuthRepository>();
    sl.registerSingleton<AuthRepository>(_Repo());
  });
  tearDown(() => sl.unregister<AuthRepository>());

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the re-accept screen carries the whole text, not an ellipsised excerpt', (tester) async {
    await phone(tester);
    final bloc = AuthBloc(authRepository: _Repo(), secureStorage: SecureStorage(const FlutterSecureStorage()));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TermsReacceptPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final richText = tester.widgetList<RichText>(find.byType(RichText)).firstWhere(
      (r) => r.text.toPlainText().contains('Clause 1 '),
    );
    expect(richText.maxLines, isNull);
    expect(richText.overflow, isNot(TextOverflow.ellipsis));
    expect(richText.text.toPlainText(), contains('Clause 60 of the provider policy.'));
    expect(richText.text.toPlainText(), contains('v2.4.0'));
  });

  testWidgets('sign-up shows the current policy in full and pins its version for consent', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TermsPage(registrationData: {'role': 'PROVIDER'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Clause 60 of the provider policy.'), findsOneWidget);
    expect(find.textContaining('v2.4.0'), findsOneWidget);
  });
}
