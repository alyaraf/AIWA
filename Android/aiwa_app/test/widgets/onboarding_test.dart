import 'package:aiwa_app/l10n/l10n.dart';
import 'package:aiwa_app/features/auth/presentation/pages/terms_page.dart';
import 'package:aiwa_app/shared/widgets/aiwa_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(useTestFonts);

  testWidgets('Terms: Agree & continue is gated on the checkbox', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: TermsPage(registrationData: {}),
      ),
    );
    AiwaButton cta() => tester.widget(find.byType(AiwaButton));

    expect(cta().onPressed, isNull);
    final agree = find.textContaining("I've read and agree");
    await tester.ensureVisible(agree);
    await tester.tap(agree);
    await tester.pump();
    expect(cta().onPressed, isNotNull);
  });
}
