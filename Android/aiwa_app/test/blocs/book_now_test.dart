import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/booking_bloc.dart';
import 'package:aiwa_app/features/bookings/presentation/widgets/book_now_check_sheet.dart';
import 'package:aiwa_app/features/providers/domain/entities/provider_detail_entity.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderDetailEntity _p({
  bool offline = false,
  bool vacation = false,
  bool paused = false,
  bool verified = true,
}) => ProviderDetailEntity(
  id: '1',
  providerName: 'Nadia',
  email: '',
  phone: '',
  categories: const [],
  averageRating: 0,
  totalReviews: 0,
  totalBookings: 0,
  isVerified: verified,
  isActive: true,
  offlineMode: offline,
  vacationMode: vacation,
  settlementPaused: paused,
);

void main() {
  final noon = DateTime(2026, 5, 19, 12);

  test('bookNowBlockFor maps provider flags and today\'s slots', () {
    BookNowBlock? r(ProviderDetailEntity p, [List<String>? free]) =>
        bookNowBlockFor(p, freeToday: free, now: noon);

    expect(r(_p(vacation: true, offline: true)), BookNowBlock.vacation);
    expect(r(_p(paused: true)), BookNowBlock.settlementPaused);
    expect(r(_p(offline: true)), BookNowBlock.offline);
    expect(r(_p(verified: false)), BookNowBlock.notApproved);
    expect(r(_p(), ['10:00', '11:30']), BookNowBlock.busy);
    expect(r(_p(), ['10:00', '13:00:00']), isNull);
    expect(r(_p()), isNull, reason: 'slot lookup failed: backend decides');
  });

  test('isSlotTaken spots the conflict error', () {
    expect(
      isSlotTaken(
        const ServerFailure(
          'This time slot is already booked. Please choose another time',
          statusCode: 400,
        ),
      ),
      isTrue,
    );
    expect(isSlotTaken(const ServerFailure('x', statusCode: 409)), isTrue);
    expect(isSlotTaken(const ServerFailure('x', statusCode: 400)), isFalse);
    expect(isSlotTaken(const NetworkFailure()), isFalse);
  });
}
