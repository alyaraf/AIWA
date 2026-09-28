import 'package:aiwa_app/features/provider_dashboard/presentation/pages/provider_reviews_page.dart';
import 'package:aiwa_app/features/provider_dashboard/presentation/pages/provider_schedule_page.dart';
import 'package:aiwa_app/features/provider_dashboard/presentation/pages/provider_wallet_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review filters', () {
    final all = [
      {'id': 1, 'rating': 5},
      {'id': 2, 'rating': 4, 'reply': 'Thanks!'},
      {'id': 3, 'rating': 5, 'reply': ''},
    ];
    expect(filterReviews(all, 'All').length, 3);
    expect(filterReviews(all, 'Needs reply').map((r) => r['id']), [1, 3]);
    expect(filterReviews(all, '5 star').map((r) => r['id']), [1, 3]);
    expect(filterReviews(all, '4 star').map((r) => r['id']), [2]);
  });

  test('next settlement is 7 days after the oldest outstanding entry', () {
    expect(nextSettlement([]), isNull);
    expect(
      nextSettlement([
        {'status': 'SETTLED', 'createdAt': '2026-05-01T10:00:00'},
        {'status': 'DUE', 'createdAt': '2026-05-14T10:00:00'},
        {'status': 'OVERDUE', 'createdAt': '2026-05-10T10:00:00'},
      ]),
      DateTime(2026, 5, 17, 10),
    );
  });

  test('LocalTime to HH:mm', () {
    expect(hhmm('10:00:00'), '10:00');
    expect(hhmm('09:30'), '09:30');
  });
}
