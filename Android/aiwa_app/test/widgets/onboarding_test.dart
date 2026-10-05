import 'dart:async';

import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:aiwa_app/features/auth/presentation/pages/terms_page.dart';
import 'package:aiwa_app/shared/widgets/aiwa_button.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Answers latestTerms with [result] (null = never answers, i.e. still loading).
class _Repo implements AuthRepository {
  Either<Failure, TermsDoc>? result;

  @override
  Future<Either<Failure, TermsDoc>> latestTerms(String type) async {
    final r = result;
    if (r == null) return Completer<Either<Failure, TermsDoc>>().future;
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(useTestFonts);

  late _Repo repo;
  setUp(() {
    if (sl.isRegistered<AuthRepository>()) sl.unregister<AuthRepository>();
    repo = _Repo();
    sl.registerSingleton<AuthRepository>(repo);
  });
  tearDown(() => sl.unregister<AuthRepository>());

  Future<void> pumpTerms(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const TermsPage(registrationData: {}),
      ),
    );
  }

  AiwaButton cta(WidgetTester tester) => tester.widget(find.widgetWithText(AiwaButton, 'Agree & continue'));

  testWidgets('Terms: Agree & continue is gated on the checkbox, once the policy is shown', (tester) async {
    repo.result = Right((version: '1.0.0', content: 'The policy.', contentAr: '', pdfUrl: null));
    await pumpTerms(tester);
    await tester.pumpAndSettle();

    expect(cta(tester).onPressed, isNull);
    final agree = find.textContaining("I've read and agree");
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pump();
    expect(cta(tester).onPressed, isNotNull);
  });

  testWidgets('Terms: nothing can be agreed to before the current policy has loaded (audit M-07)', (tester) async {
    await pumpTerms(tester); // repo.result is null: the policy request never answers
    await tester.pump();

    final agree = find.textContaining("I've read and agree");
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pump();
    expect(cta(tester).onPressed, isNull);

  });

  testWidgets('Terms: a policy that cannot be loaded offers a retry and still blocks consent', (tester) async {
    repo.result = const Left(NetworkFailure());
    await pumpTerms(tester);
    await tester.pumpAndSettle();

    expect(find.text("We couldn't load the current terms. Check your connection and try again."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    final agree = find.textContaining("I've read and agree");
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pump();
    expect(cta(tester).onPressed, isNull);
  });
}
