import 'package:aiwa_app/l10n/l10n.dart';
import 'package:aiwa_app/features/home/domain/entities/provider_summary_entity.dart';
import 'package:aiwa_app/features/home/presentation/widgets/provider_list_item.dart';
import 'package:aiwa_app/shared/widgets/aiwa_avatar.dart';
import 'package:aiwa_app/shared/widgets/guest_locked_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../test_helpers.dart';

const _nadia = ProviderSummaryEntity(
  id: 1,
  businessName: 'Nadia Studio',
  primaryCategory: 'HAIR',
  averageRating: 4.9,
  totalReviews: 312,
  verificationStatus: 'APPROVED',
  ownerName: 'Nadia',
  distanceKm: 1.2,
  startingPrice: 350,
);

void main() {
  setUpAll(useTestFonts);

  Widget row(ProviderListItem item) => host(SizedBox(width: 360, child: item));

  testWidgets('home row: rating with count, distance and From price', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      row(ProviderListItem(provider: _nadia, onTap: () => taps++)),
    );

    expect(find.text('Nadia Studio'), findsOneWidget);
    expect(find.text('Hair'), findsOneWidget);
    expect(find.text('4.9 (312)'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('EGP 350'), findsOneWidget);
    expect(find.byIcon(LucideIcons.chevronRightDir), findsNothing);

    final avatar = tester.widget<AiwaAvatar>(find.byType(AiwaAvatar));
    expect(avatar.size, 52);
    expect(avatar.verified, isTrue);

    await tester.tap(find.text('Nadia Studio'));
    expect(taps, 1);
  });

  testWidgets('discover row: bigger avatar, chevron, no price or count', (
    tester,
  ) async {
    await tester.pumpWidget(
      row(ProviderListItem(provider: _nadia, showPrice: false, onTap: () {})),
    );

    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('EGP 350'), findsNothing);
    expect(find.byIcon(LucideIcons.chevronRightDir), findsOneWidget);
    expect(tester.widget<AiwaAvatar>(find.byType(AiwaAvatar)).size, 56);
  });

  testWidgets('new provider without rating shows "New"', (tester) async {
    await tester.pumpWidget(
      row(
        ProviderListItem(
          provider: const ProviderSummaryEntity(
            id: 9,
            businessName: 'Fresh Cuts',
            primaryCategory: 'HAIR',
            totalReviews: 0,
            verificationStatus: 'PENDING',
            ownerName: 'Omar',
          ),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('New'), findsOneWidget);
    expect(
      tester.widget<AiwaAvatar>(find.byType(AiwaAvatar)).verified,
      isFalse,
    );
  });

  testWidgets('guest locked view explains and offers sign in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: GuestLockedView(
            title: 'Keep your favorites',
            body: 'Sign in to save providers.',
          ),
        ),
      ),
    );

    expect(find.text('BROWSING AS GUEST'), findsOneWidget);
    expect(find.text('Keep your favorites'), findsOneWidget);
    expect(find.text('Sign in or create account'), findsOneWidget);
  });
}
