import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/saved_address_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _remote;
  BookingRepositoryImpl(this._remote);

  /// Every method goes through here, so a failed request reaches the screen
  /// as a Failure and never as a throw (CR-17): a 401 the refresh could not
  /// cure, no network, or anything unexpected (a bad payload, a bug).
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(
        ServerFailure(e.message, statusCode: e.statusCode, code: e.code),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } catch (_) {
      return const Left(ServerFailure('Something went wrong'));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> createBooking({
    required String providerId,
    required String serviceId,
    String? scheduledDate,
    String? scheduledTime,
    String? staffId,
    bool bookNow = false,
    bool homeService = false,
    String? savedAddressId,
    String? customerNote,
    String? idempotencyKey,
  }) => _guard(
    () => _remote.createBooking(
      providerId: providerId,
      serviceId: serviceId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      staffId: staffId,
      bookNow: bookNow,
      homeService: homeService,
      savedAddressId: savedAddressId,
      customerNote: customerNote,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<Either<Failure, List<SavedAddressEntity>>> getSavedAddresses() =>
      _guard(_remote.getSavedAddresses);

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) => _guard(
    () => _remote.getMyBookings(status: status, page: page, size: size),
  );

  @override
  Future<Either<Failure, BookingEntity>> getBookingDetail(String bookingId) =>
      _guard(() => _remote.getBookingDetail(bookingId));

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking(
    String bookingId, {
    String? reason,
  }) => _guard(() => _remote.cancelBooking(bookingId, reason: reason));

  @override
  Future<Either<Failure, BookingEntity>> respondToProposal(
    String bookingId,
    bool accept,
  ) => _guard(() => _remote.respondToProposal(bookingId, accept));

  /// PATCH /bookings/{id}/travel-fee-response — accepting applies the quote to
  /// the total; declining cancels the booking without a penalty.
  @override
  Future<Either<Failure, BookingEntity>> respondToTravelFee(
    String bookingId,
    bool accept, {
    double? amount,
  }) => _guard(
    () => _remote.respondToTravelFee(bookingId, accept, amount: amount),
  );

  @override
  Future<Either<Failure, BookingEntity>> checkIn(String bookingId) =>
      _guard(() => _remote.checkIn(bookingId));

  @override
  Future<Either<Failure, BookingEntity>> contestNoShow(String bookingId) =>
      _guard(() => _remote.contestNoShow(bookingId));

  @override
  Future<Either<Failure, BookingEntity>> confirmPayment(
    String bookingId, {
    required bool paid,
    String? providerId,
    String? reason,
  }) => _guard(() async {
    final b = await _remote.confirmPayment(bookingId, paid);
    if (!paid && reason != null && providerId != null) {
      await _remote.submitComplaint(
        bookingId: bookingId,
        providerId: providerId,
        category: 'PAYMENT',
        description: reason,
      );
    }
    return b;
  });

  @override
  Future<Either<Failure, void>> sendSos(
    String bookingId, {
    double? latitude,
    double? longitude,
    DateTime? locationTime,
    double? locationAccuracy,
  }) => _guard(
    () => _remote.sendSos(
      bookingId,
      latitude: latitude,
      longitude: longitude,
      locationTime: locationTime,
      locationAccuracy: locationAccuracy,
    ),
  );

  @override
  Future<Either<Failure, SosReport?>> sosReport(String bookingId) =>
      _guard(() => _remote.sosReport(bookingId));

  /// "I'm safe" — POST /bookings/{id}/safety/{eventId}/resolve.
  @override
  Future<Either<Failure, void>> resolveSos(String bookingId) =>
      _guard(() => _remote.resolveSos(bookingId));

  /// GET /bookings/{id}/contact — the other party's real number, released only
  /// while the booking is live. (A masked-number proxy is a later upgrade.)
  @override
  Future<Either<Failure, String>> maskedPhone(String bookingId) =>
      _guard(() => _remote.contactPhone(bookingId));

  @override
  Future<Either<Failure, void>> submitComplaint({
    required String bookingId,
    required String providerId,
    required String category,
    required String description,
  }) => _guard(
    () => _remote.submitComplaint(
      bookingId: bookingId,
      providerId: providerId,
      category: category,
      description: description,
    ),
  );

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getChat(
    String bookingId, {
    String? afterId,
  }) => _guard(() => _remote.getChat(bookingId, afterId: afterId));

  @override
  Future<Either<Failure, ChatMessageEntity>> sendChat(
    String bookingId,
    String message,
  ) => _guard(() => _remote.sendChat(bookingId, message));

  @override
  Future<Either<Failure, void>> reportChatMessage(
    String bookingId,
    String messageId,
  ) => _guard(() => _remote.reportChatMessage(bookingId, messageId));

  @override
  Future<Either<Failure, BookingEntity>> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) => _guard(
    () => _remote.rescheduleBooking(
      bookingId: bookingId,
      newDate: newDate,
      newTime: newTime,
    ),
  );

  @override
  Future<Either<Failure, BookingEntity>> amendDestination({
    required String bookingId,
    required String savedAddressId,
  }) => _guard(
    () => _remote.amendDestination(
      bookingId: bookingId,
      savedAddressId: savedAddressId,
    ),
  );
}
