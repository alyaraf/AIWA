// M-02: Upcoming asks the server for the live statuses, and a page that is empty after filtering never hides "Load more".
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

BookingModel _b(int id, String status) => BookingModel.fromJson({
  'id': id,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': status,
  'totalPrice': 350,
});

class _Bookings implements BookingRepository {
  final statuses = <String?>[];

  /// The newest page holds only finished bookings; the live one is on the next page.
  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({String? status, int page = 0, int size = 20}) async {
    statuses.add(status);
    if (page == 0) {
      return Right(PagedData(content: [_b(1, 'COMPLETED')], totalElements: 2, totalPages: 2, number: 0, size: 1, last: false));
    }
    return Right(PagedData(content: [_b(2, 'ACCEPTED')], totalElements: 2, totalPages: 2, number: 1, size: 1, last: true));
  }

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

  testWidgets('Upcoming sends the live statuses and keeps Load more when the page is empty after filtering', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final bookings = _Bookings();
    if (sl.isRegistered<BookingBloc>()) sl.unregister<BookingBloc>();
    sl.registerFactory<BookingBloc>(() => BookingBloc(bookingRepository: bookings));
    addTearDown(() => sl.unregister<BookingBloc>());
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

    // the first request is the live statuses, not "everything"
    expect(bookings.statuses.first, 'PENDING,ACCEPTED,ON_THE_WAY,ARRIVED,IN_PROGRESS');
    // the guard hides the finished row on the Upcoming tab, but the server has more: Load more must be there
    expect(find.text('Load more'), findsOneWidget);
    expect(find.text('Nothing booked yet'), findsNothing);

    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Nadia Studio'), findsWidgets); // the live booking from the second page is reachable
  });
}
