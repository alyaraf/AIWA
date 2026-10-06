// M-07 follow-up: when the policy changed during sign-up and the reload FAILS, the outdated text must not stay on screen
// (with a Continue button that can never succeed); the screen says so, offers Retry, and the new text is announced.
import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/router/app_router.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/presentation/pages/terms_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test_helpers.dart';

class _Repo implements AuthRepository {
  final responses = <Either<Failure, TermsDoc>>[
    Right((version: '1.0.0', content: 'OLD POLICY TEXT', contentAr: '', pdfUrl: null)),
  ];
  int calls = 0;

  @override
  Future<Either<Failure, TermsDoc>> latestTerms(String type) async =>
      responses[calls++ < responses.length ? calls - 1 : responses.length - 1];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(useTestFonts);

  testWidgets('a failed reload after "terms changed" removes the old policy and offers Retry; the retry shows the new one', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    if (sl.isRegistered<AuthRepository>()) sl.unregister<AuthRepository>();
    sl.registerSingleton<AuthRepository>(repo);
    addTearDown(() => sl.unregister<AuthRepository>());

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const TermsPage(registrationData: {'role': 'CUSTOMER'})),
        GoRoute(
          path: AppRoutes.preferences,
          builder: (context, _) => Scaffold(
            body: TextButton(onPressed: () => context.pop('terms-changed'), child: const Text('policy moved on')),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('OLD POLICY TEXT'), findsOneWidget);

    // agree to the old text and continue: preferences reports that the policy changed meanwhile
    final l = lookupAppLocalizations(const Locale('en'));
    repo.responses.add(const Left(NetworkFailure('offline'))); // the reload that follows fails
    await tester.ensureVisible(find.byKey(const Key('terms-consent')));
    await tester.tap(find.byKey(const Key('terms-consent'))); // the consent checkbox
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.authAgreeContinue));
    await tester.pumpAndSettle();
    await tester.tap(find.text('policy moved on'));
    await tester.pumpAndSettle();

    expect(find.textContaining('OLD POLICY TEXT'), findsNothing, reason: 'the outdated policy must not stay on screen');
    expect(find.text(l.authTermsLoadFailed), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, l.authAgreeContinue), findsNothing);

    // Retry: now the new policy loads, announced as new, and has to be agreed to again
    repo.responses.add(Right((version: '2.0.0', content: 'NEW POLICY TEXT', contentAr: '', pdfUrl: null)));
    await tester.ensureVisible(find.text(l.commonRetry));
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.textContaining('NEW POLICY TEXT'), findsOneWidget);
    expect(find.byKey(const Key('terms-updated-notice')), findsOneWidget);
    expect(find.textContaining('v2.0.0'), findsOneWidget);
  });
}
