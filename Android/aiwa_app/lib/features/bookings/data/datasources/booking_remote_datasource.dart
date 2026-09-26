import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../models/booking_model.dart';

abstract class BookingRemoteDataSource {
  Future<BookingModel> createBooking({
    required String providerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    String? customerNote,
  });

  Future<PagedData<BookingModel>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  });

  Future<BookingModel> getBookingDetail(String bookingId);

  Future<BookingModel> cancelBooking(String bookingId);

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
    required String scheduledDate,
    required String scheduledTime,
    String? customerNote,
  }) async {
    final response = await _api.post(ApiConstants.bookings, data: {
      'providerId': providerId,
      'serviceId': serviceId,
      'scheduledDate': scheduledDate,
      'scheduledTime': scheduledTime,
      if (customerNote != null) 'customerNote': customerNote,
    });
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
  Future<BookingModel> cancelBooking(String bookingId) async {
    final response =
        await _api.patch(ApiConstants.bookingCancel(bookingId));
    final data = response.data['data'] ?? response.data;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<BookingModel> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) async {
    final response = await _api.patch(
      ApiConstants.bookingReschedule(bookingId),
      data: {'newDate': newDate, 'newTime': newTime},
    );
    final data = response.data['data'] ?? response.data;
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }
}
