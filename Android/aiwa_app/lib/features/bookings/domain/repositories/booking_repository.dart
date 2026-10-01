import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/booking_entity.dart';
import '../entities/chat_message_entity.dart';
import '../entities/saved_address_entity.dart';

abstract class BookingRepository {
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
  });

  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  });

  Future<Either<Failure, BookingEntity>> getBookingDetail(String bookingId);

  Future<Either<Failure, List<SavedAddressEntity>>> getSavedAddresses();

  Future<Either<Failure, BookingEntity>> cancelBooking(
    String bookingId, {
    String? reason,
  });

  Future<Either<Failure, BookingEntity>> respondToProposal(
    String bookingId,
    bool accept,
  );

  /// Customer answer to a provider's travel-fee quote. Not in the backend.
  Future<Either<Failure, BookingEntity>> respondToTravelFee(
    String bookingId,
    bool accept,
  );

  Future<Either<Failure, BookingEntity>> checkIn(String bookingId);

  /// paid=false reports unpaid; [reason] is filed as a complaint because
  /// confirm-payment takes no text.
  Future<Either<Failure, BookingEntity>> confirmPayment(
    String bookingId, {
    required bool paid,
    String? providerId,
    String? reason,
  });

  /// [latitude]/[longitude]: where the user is, when a fix was available.
  Future<Either<Failure, void>> sendSos(
    String bookingId, {
    double? latitude,
    double? longitude,
  });

  /// The caller's open SOS on this booking and what was actually delivered
  /// (R2-03), or null when none is open.
  Future<Either<Failure, SosReport?>> sosReport(String bookingId);

  /// "I'm safe" after an SOS: closes the caller's open SOS.
  Future<Either<Failure, void>> resolveSos(String bookingId);

  /// Masked-number proxy for the call button. Not in the backend.
  Future<Either<Failure, String>> maskedPhone(String bookingId);

  Future<Either<Failure, void>> submitComplaint({
    required String bookingId,
    required String providerId,
    required String category,
    required String description,
  });

  Future<Either<Failure, List<ChatMessageEntity>>> getChat(String bookingId);

  Future<Either<Failure, ChatMessageEntity>> sendChat(
    String bookingId,
    String message,
  );

  Future<Either<Failure, void>> reportChatMessage(
    String bookingId,
    String messageId,
  );

  Future<Either<Failure, BookingEntity>> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  });
}

/// What an SOS reached, from the backend's delivery records (R2-03). The SOS
/// screen says only this: before, it always claimed a trusted contact had been
/// alerted, even with no contacts, no location, or a failed text.
class SosReport {
  final bool supportAlerted;
  final int contactsTexted;
  final int contactsFailed;
  final int contactsPending;

  const SosReport({
    this.supportAlerted = false,
    this.contactsTexted = 0,
    this.contactsFailed = 0,
    this.contactsPending = 0,
  });

  factory SosReport.fromJson(Map<String, dynamic> j) => SosReport(
    supportAlerted: j['supportAlerted'] == true,
    contactsTexted: (j['contactsTexted'] as num?)?.toInt() ?? 0,
    contactsFailed: (j['contactsFailed'] as num?)?.toInt() ?? 0,
    contactsPending: (j['contactsPending'] as num?)?.toInt() ?? 0,
  );
}
