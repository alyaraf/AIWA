import 'package:aiwa_app/l10n/l10n.dart';
import 'package:aiwa_app/core/theme/app_colors.dart';
import 'package:aiwa_app/shared/widgets/aiwa_button.dart';
import 'package:aiwa_app/shared/widgets/aiwa_chip.dart';
import 'package:aiwa_app/shared/widgets/aiwa_icon_button.dart';
import 'package:aiwa_app/shared/widgets/confirm_sheet.dart';
import 'package:aiwa_app/shared/widgets/empty_state.dart';
import 'package:aiwa_app/shared/widgets/eyebrow_label.dart';
import 'package:aiwa_app/shared/widgets/screen_chrome.dart';
import 'package:aiwa_app/shared/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(useTestFonts);
  tearDown(resetPalette);

  group('StatusPill', () {
    const cases = {
      'PENDING': 'Pending',
      'ACCEPTED': 'Confirmed',
      'ON_THE_WAY': 'On the way',
      'ARRIVED': 'Arrived',
      'IN_PROGRESS': 'In progress',
      'COMPLETED': 'Completed',
      'CANCELLED': 'Cancelled',
      'REJECTED': 'Rejected',
      'NO_SHOW': 'No-show',
      'EXPIRED': 'Expired',
      'DISPUTED': 'Disputed',
      'onway': 'On the way', // design-kit ids work too
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key} → "${entry.value}"', (tester) async {
        await tester.pumpWidget(host(StatusPill(status: entry.key)));
        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('unknown status falls back to Pending (kit map.pending)', (
      tester,
    ) async {
      await tester.pumpWidget(host(const StatusPill(status: 'WEIRD')));
      expect(find.text('Pending'), findsOneWidget);
    });
  });

  group('AiwaButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AiwaButton(label: 'Book now', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Book now'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(taps, 1);
    });

    testWidgets('disabled button ignores taps and is dimmed', (tester) async {
      await tester.pumpWidget(host(const AiwaButton(label: 'Continue')));

      await tester.tap(find.text('Continue'));
      await tester.pump();

      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('Continue'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.45);
    });

    testWidgets('loading pulses instead of a spinner and ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AiwaButton(label: 'Sign in', loading: true, onPressed: () => taps++),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.ancestor(
          of: find.text('Sign in'),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.tap(find.text('Sign in'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(taps, 0);
    });

    testWidgets('primary uses the palette colour', (tester) async {
      await tester.pumpWidget(host(AiwaButton(label: 'Go', onPressed: () {})));

      final box = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text('Go'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.plum700);
    });
  });

  group('AiwaChip', () {
    testWidgets('active chip is filled, inactive is paper', (tester) async {
      await tester.pumpWidget(
        host(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AiwaChip(label: 'All', active: true),
              AiwaChip(label: 'Hair'),
            ],
          ),
        ),
      );

      BoxDecoration decorationOf(String label) =>
          tester
                  .widget<AnimatedContainer>(
                    find
                        .ancestor(
                          of: find.text(label),
                          matching: find.byType(AnimatedContainer),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      expect(decorationOf('All').color, AppColors.plum700);
      expect(decorationOf('Hair').color, AppColors.paper);
    });
  });

  group('EyebrowLabel', () {
    testWidgets('renders upper-case', (tester) async {
      await tester.pumpWidget(host(const EyebrowLabel('Your favorites')));
      expect(find.text('YOUR FAVORITES'), findsOneWidget);
    });
  });

  group('EmptyState / ErrorState', () {
    testWidgets('empty state shows copy and runs its action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: LucideIcons.heart,
            title: 'No favorites yet',
            subtitle: 'Tap the heart on any provider.',
            actionLabel: 'Browse providers',
            onAction: () => tapped = true,
          ),
        ),
      );

      expect(find.text('No favorites yet'), findsOneWidget);
      expect(find.text('Tap the heart on any provider.'), findsOneWidget);

      await tester.tap(find.text('Browse providers'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tapped, isTrue);
    });

    testWidgets('empty state without an action shows no button', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here'),
        ),
      );
      expect(find.byType(AiwaButton), findsNothing);
    });

    testWidgets('error state offers Try again', (tester) async {
      var retries = 0;
      await tester.pumpWidget(host(ErrorState(onRetry: () => retries++)));

      expect(find.text("Couldn't load this"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(retries, 1);
    });
  });

  group('screen chrome', () {
    testWidgets('ScreenHeader shows eyebrow, title and suffix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ScreenHeader(
              eyebrow: 'Inbox',
              title: 'Notifications',
              titleSuffix: '· 3 new',
              onBack: () {},
            ),
          ),
        ),
      );

      expect(find.text('INBOX'), findsOneWidget);
      expect(find.textContaining('Notifications'), findsOneWidget);
      expect(find.textContaining('· 3 new'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowLeftDir), findsOneWidget);
    });

    testWidgets('SettingsRow danger rows have no chevron', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Column(
              children: [
                SettingsRow(
                  icon: LucideIcons.bell,
                  label: 'Notifications',
                  onTap: () {},
                ),
                SettingsRow(
                  icon: LucideIcons.logOutDir,
                  label: 'Sign out',
                  danger: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.chevronRightDir), findsOneWidget);
    });
  });

  group('showConfirmSheet', () {
    Future<bool?> openAndPick(WidgetTester tester, String button) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showConfirmSheet(
                    context,
                    title: 'Cancel booking?',
                    confirmLabel: 'Cancel booking',
                    cancelLabel: 'Keep it',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel booking?'), findsOneWidget);

      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm returns true', (tester) async {
      expect(await openAndPick(tester, 'Cancel booking'), isTrue);
    });

    testWidgets('keep returns false', (tester) async {
      expect(await openAndPick(tester, 'Keep it'), isFalse);
    });
  });

  group('AiwaIconButton semantics (AU-12)', () {
    testWidgets('icon-only buttons are announced with a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(Row(children: [
        AiwaIconButton(icon: LucideIcons.arrowLeftDir, onTap: () {}),
        AiwaIconButton(icon: LucideIcons.phone, onTap: () {}),
        AiwaIconButton(icon: LucideIcons.send, onTap: () {}, semanticLabel: 'Send it'),
      ])));
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.bySemanticsLabel('Call'), findsOneWidget);
      expect(find.bySemanticsLabel('Send it'), findsOneWidget);
      handle.dispose();
    });
  });
}
