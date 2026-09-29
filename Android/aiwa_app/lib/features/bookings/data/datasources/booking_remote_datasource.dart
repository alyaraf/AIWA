import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/saved_address_entity.dart';
import '../models/booking_model.dart';

abstract class BookingRemoteDataSource {
  Future<BookingModel> createBooking({
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

  Future<PagedData<BookingModel>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  });

  Future<BookingModel> getBookingDetail(String bookingId);

  Future<List<SavedAddressEntity>> getSavedAddresses();

  Future<BookingModel> cancelBooking(String bookingId, {String? reason});

  Future<BookingModel> respondToProposal(String bookingId, bool accept);

  Future<BookingModel> checkIn(String bookingId);

  Future<BookingModel> confirmPayment(String bookingId, bool paid);

  Future<void> sendSos(String bookingId, {String? notes});

  /// "I'm safe": closes the caller's latest open SOS on this booking.
  Future<void> resolveSos(String bookingId);

  /// The other party's phone (only while the booking is live).
  Future<String> contactPhone(String bookingId);

  /// Customer answer to a provider's travel-fee quote.
  Future<BookingModel> respondToTravelFee(String bookingId, bool accept);

  Future<void> submitComplaint({
    required String bookingId,
    required String providerId,
    required String category,
    required String description,
  });

  Future<List<ChatMessageEntity>> getChat(String bookingId);

  Future<ChatMessageEntity> sendChat(String bookingId, String message);

  Future<void> reportChatMessage(String bookingId, String messageId);

  Future<BookingModel> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final ApiClient _api;
  BookingRemoteDataSourceImpl(this._api);

  @override
  Future<BookingModel> createBooking({
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
  }) async {
    // BookingRequest: bookingDate / startTime / notes. The caller keeps one
    // key per booking attempt, so a retry returns the original booking.
    final response = await _api.post(
      ApiConstants.bookings,
      data: {
        'providerId': providerId,
        'serviceId': serviceId,
        // BOOK_NOW: the backend picks today + the next free slot.
        if (!bookNow) 'bookingDate': scheduledDate,
        if (!bookNow) 'startTime': scheduledTime,
        'staffMemberId': ?staffId,
        'bookingType': bookNow ? 'BOOK_NOW' : 'SCHEDULED',
        'homeService': homeService,
        'savedAddressId': ?savedAddressId,
        'paymentMethod': 'CASH',
        if (customerNote != null) 'notes': customerNote,
      },
      options: Options(headers: {'Idempotency-Key': ?idempotencyKey}),
    );
    final data = response.data['data'] ?? response.data;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<PagedData<BookingModel>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      ApiConstants.myBookings,
      queryParameters: {
        'page': page,
        'size': size,
        if (status != null) 'status': status,
      },
    );
    // The backend filters by status (comma-separated) before paging.
    final data = response.data['data'] ?? response.data;
    return PagedData.fromJson(
      data,
      (e) => BookingModel.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<BookingModel> getBookingDetail(String bookingId) async {
    final response = await _api.get(ApiConstants.bookingById(bookingId));
    final data = response.data['data'] ?? response.data;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<SavedAddressEntity>> getSavedAddresses() async {
    final response = await _api.get(ApiConstants.savedAddresses);
    return [
      for (final e in response.data['data'] as List? ?? const [])
        SavedAddressEntity.fromJson(e as Map<String, dynamic>),
    ];
  }

  BookingModel _booking(Response r) =>
      BookingModel.fromJson((r.data['data'] ?? r.data) as Map<String, dynamic>);

  @override
  Future<BookingModel> cancelBooking(
    String bookingId, {
    String? reason,
  }) async => _booking(
    await _api.patch(
      ApiConstants.bookingCancel(bookingId),
      queryParameters: {'reason': ?reason},
    ),
  );

  @override
  Future<BookingModel> respondToProposal(String bookingId, bool accept) async =>
      _booking(
        await _api.patch(
          ApiConstants.bookingProposalResponse(bookingId),
          queryParameters: {'accept': accept},
        ),
      );

  @override
  Future<BookingModel> checkIn(String bookingId) async =>
      _booking(await _api.patch(ApiConstants.bookingCheckIn(bookingId)));

  @override
  Future<BookingModel> confirmPayment(String bookingId, bool paid) async =>
      _booking(
        await _api.patch(
          ApiConstants.bookingConfirmPayment(bookingId),
          queryParameters: {'paid': paid},
        ),
      );

  @override
  Future<void> sendSos(String bookingId, {String? notes}) => _api.post(
    ApiConstants.bookingSafety(bookingId),
    data: {'type': 'SOS', 'notes': ?notes},
  );

  @override
  Future<void> resolveSos(String bookingId) async {
    // The timeline only returns the caller's own SOS events; close the newest open one.
    final response = await _api.get(ApiConstants.bookingSafety(bookingId));
    final open = [
      for (final e in response.data['data'] as List? ?? const [])
        if ((e as Map<String, dynamic>)['type'] == 'SOS' && e['resolved'] != true) e,
    ];
    if (open.isEmpty) return;
    await _api.post(
      ApiConstants.bookingSafetyResolve(bookingId, '${open.last['id']}'),
    );
  }

  @override
  Future<String> contactPhone(String bookingId) async {
    final response = await _api.get(ApiConstants.bookingContact(bookingId));
    return (response.data['data'] as Map<String, dynamic>)['phone'] as String;
  }

  @override
  Future<BookingModel> respondToTravelFee(String bookingId, bool accept) async =>
      _booking(
        await _api.patch(
          ApiConstants.bookingTravelFeeResponse(bookingId),
          queryParameters: {'accept': accept},
        ),
      );

  // POST /complaints takes request params, not a body.
  @override
  Future<void> submitComplaint({
    required String bookingId,
    required String providerId,
    required String category,
    required String description,
  }) => _api.post(
    ApiConstants.complaints,
    queryParameters: {
      'bookingId': bookingId,
      'targetProviderId': providerId,
      'category': category,
      'description': description,
    },
  );

  @override
  Future<List<ChatMessageEntity>> getChat(String bookingId) async {
    final response = await _api.get(ApiConstants.bookingChat(bookingId));
    return [
      for (final e in response.data['data'] as List? ?? const [])
        ChatMessageEntity.fromJson(e as Map<String, dynamic>),
    ];
  }

  @override
  Future<ChatMessageEntity> sendChat(String bookingId, String message) async {
    final response = await _api.post(
      ApiConstants.bookingChat(bookingId),
      data: {'message': message},
    );
    return ChatMessageEntity.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<void> reportChatMessage(String bookingId, String messageId) =>
      _api.post(ApiConstants.bookingChatReport(bookingId, messageId));

  @override
  Future<BookingModel> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) async {
    final response = await _api.patch(
      ApiConstants.bookingReschedule(bookingId),
      data: {'bookingDate': newDate, 'startTime': newTime},
    );
    final data = response.data['data'] ?? response.data;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }
}
