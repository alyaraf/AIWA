// R7-07: contesting a no-show confirms with the AIWA toast; a failure shows inline on the card, never a SnackBar.
import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_response.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/domain/entities/user_entity.dart';
import 'package:aiwa_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:aiwa_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/booking_bloc.dart';
import 'package:aiwa_app/features/bookings/presentation/pages/my_bookings_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

final _noShow = BookingModel.fromJson({
  'id': 5,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': 'NO_SHOW',
  'totalPrice': 350,
});

class _Bookings implements BookingRepository {
  bool fail = true;

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({String? status, int page = 0, int size = 20}) async =>
      Right(PagedData(content: [_noShow], totalElements: 1, totalPages: 1, number: 0, size: 20, last: true));

  @override
  Future<Either<Failure, BookingEntity>> contestNoShow(String bookingId) async =>
      fail ? const Left(ServerFailure('Something went wrong')) : Right(_noShow);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async =>
      Right(UserModel.fromJson({'id': 7, 'fullName': 'Salma', 'role': 'CUSTOMER'}));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(useTestFonts);

  testWidgets('contest no-show: failure inline, success as the AIWA toast', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final bookings = _Bookings();
    if (sl.isRegistered<BookingBloc>()) sl.unregister<BookingBloc>();
    sl.registerFactory<BookingBloc>(() => BookingBloc(bookingRepository: bookings));
    addTearDown(() => sl.unregister<BookingBloc>());
    if (sl.isRegistered<BookingRepository>()) sl.unregister<BookingRepository>();
    sl.registerSingleton<BookingRepository>(bookings);
    addTearDown(() => sl.unregister<BookingRepository>());
    final auth = AuthBloc(authRepository: _Auth(), secureStorage: SecureStorage(const FlutterSecureStorage()))
      ..add(AuthGetCurrentUserEvent());
    await auth.stream.firstWhere((s) => s is AuthAuthenticated);
    addTearDown(auth.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MyBookingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();

    final contest = find.text('This wasn’t a no-show');
    await tester.ensureVisible(contest);
    await tester.tap(contest);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Something went wrong'), findsOneWidget);

    bookings.fail = false;
    await tester.tap(contest);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Something went wrong'), findsNothing);
    expect(find.text('Sent. AIWA support will review it.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5)); // let the toast timer finish
  });
}
