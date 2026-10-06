// Mobile destination amendment (B-05 follow-up): the existing PATCH /bookings/{id}/destination endpoint is reachable
// from the booking screen, an accepted visit is announced as going back to Pending, and every refusal is shown inline.
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:aiwa_app/features/bookings/domain/entities/saved_address_entity.dart';
import 'package:aiwa_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/live_booking_cubit.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:aiwa_app/shared/widgets/address_amend_sheet.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

Map<String, dynamic> _json(String status, String address) => {
  'id': 7,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-12-19',
  'startTime': '12:30:00',
  'status': status,
  'homeService': true,
  'savedAddress': {'id': 4, 'addressLine': address},
};

class _Repo implements BookingRepository {
  _Repo(this.result);
  Either<Failure, BookingEntity> result;
  String? amendedTo;
  Either<Failure, List<SavedAddressEntity>> addresses = const Right([
    SavedAddressEntity(id: '4', label: 'Home', addressLine: '1 Nile St'),
    SavedAddressEntity(id: '5', label: 'Work', addressLine: '5 Tahrir Sq'),
  ]);

  @override
  Future<Either<Failure, BookingEntity>> amendDestination({
    required String bookingId,
    required String savedAddressId,
  }) async {
    amendedTo = savedAddressId;
    return result;
  }

  @override
  Future<Either<Failure, List<SavedAddressEntity>>> getSavedAddresses() async => addresses;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(useTestFonts);

  test('the endpoint path is the existing backend one', () {
    expect(ApiConstants.bookingDestination('7'), '/bookings/7/destination');
  });

  test('an amendment replaces the booking: an accepted visit comes back PENDING with the new address', () async {
    final before = BookingModel.fromJson(_json('ACCEPTED', '1 Nile St'));
    final repo = _Repo(Right(BookingModel.fromJson(_json('PENDING', '5 Tahrir Sq'))));
    final cubit = LiveBookingCubit(repo, '7', initial: before);
    expect(await cubit.amendDestination('5'), isTrue);
    expect(repo.amendedTo, '5');
    expect(cubit.state.booking?.status, 'PENDING');
    expect(cubit.state.booking?.customerAddress, '5 Tahrir Sq');
    expect(cubit.state.actionError, isNull);
    await cubit.close();
  });

  test('a refusal (outside the radius, too late) keeps the old booking and shows the reason', () async {
    final before = BookingModel.fromJson(_json('ACCEPTED', '1 Nile St'));
    final repo = _Repo(const Left(ServerFailure('That address is outside the provider service area')));
    final cubit = LiveBookingCubit(repo, '7', initial: before);
    expect(await cubit.amendDestination('5'), isFalse);
    expect(cubit.state.booking?.status, 'ACCEPTED');
    expect(cubit.state.booking?.customerAddress, '1 Nile St');
    expect(cubit.state.actionError, 'That address is outside the provider service area');
    expect(cubit.state.busy, isFalse);
    await cubit.close();
  });

  test('saved addresses load through the cubit; a failure is reported and returns null', () async {
    final before = BookingModel.fromJson(_json('PENDING', '1 Nile St'));
    final repo = _Repo(Right(before));
    final cubit = LiveBookingCubit(repo, '7', initial: before);
    expect((await cubit.savedAddresses())?.length, 2);
    repo.addresses = const Left(NetworkFailure('offline'));
    expect(await cubit.savedAddresses(), isNull);
    expect(cubit.state.actionError, 'offline');
    await cubit.close();
  });

  Future<List<String?>> open(WidgetTester tester, {required bool reconfirm, List<SavedAddressEntity>? addresses, String? current}) async {
    final result = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result.add(await showAddressAmendSheet(
                context,
                providerName: 'Nadia',
                addresses: addresses ?? const [
                  SavedAddressEntity(id: '4', label: 'Home', addressLine: '1 Nile St'),
                  SavedAddressEntity(id: '5', label: 'Work', addressLine: '5 Tahrir Sq'),
                ],
                currentAddress: current ?? '1 Nile St',
                needsReconfirm: reconfirm,
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the sheet lists the other addresses, warns about reconfirmation and returns the choice', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final result = await open(tester, reconfirm: true);
    expect(find.byKey(const Key('address-choice-5')), findsOneWidget);
    expect(find.byKey(const Key('address-choice-4')), findsNothing, reason: 'the visit already goes there');
    expect(find.textContaining('already accepted this visit'), findsOneWidget);
    expect(find.textContaining('Now: 1 Nile St'), findsOneWidget);
    // nothing chosen yet: the confirm button is disabled
    final confirm = find.widgetWithText(ElevatedButton, 'Change address');
    await tester.tap(find.byKey(const Key('address-choice-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change address'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('address-choice-5')), findsNothing, reason: 'the sheet closed');
    expect(confirm, findsNothing);
    expect(result, ['5']);
  });

  testWidgets('without another saved address the sheet says where to add one', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await open(tester, reconfirm: false, addresses: const [SavedAddressEntity(id: '4', label: 'Home', addressLine: '1 Nile St')]);
    expect(find.byKey(const Key('address-amend-none')), findsOneWidget);
    expect(find.textContaining('already accepted'), findsNothing);
  });
}
