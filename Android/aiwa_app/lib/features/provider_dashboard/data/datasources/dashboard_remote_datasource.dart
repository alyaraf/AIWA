import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../../domain/repositories/dashboard_repository.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardStats> getStats();

  Future<PagedData<BookingModel>> getProviderBookings({
    String? status,
    int page = 0,
    int size = 20,
  });

  Future<BookingModel> acceptBooking(String bookingId);

  Future<BookingModel> rejectBooking(String bookingId, String reason);

  /// cashCollected=false marks the booking DISPUTED.
  Future<BookingModel> completeBooking(
    String bookingId, {
    bool cashCollected = true,
  });

  /// RescheduleRequest: bookingDate `yyyy-MM-dd`, startTime `HH:mm`.
  Future<BookingModel> proposeTime(String bookingId, String date, String time);

  Future<BookingModel> onTheWay(String bookingId);

  Future<BookingModel> arrived(String bookingId);

  Future<BookingModel> inProgress(String bookingId);
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final ApiClient _api;
  DashboardRemoteDataSourceImpl(this._api);

  @override
  Future<DashboardStats> getStats() async {
    final response = await _api.get(ApiConstants.providerDashboard);
    return DashboardStats.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<PagedData<BookingModel>> getProviderBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      ApiConstants.providerBookings,
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
  Future<BookingModel> acceptBooking(String bookingId) async {
    final response = await _api.patch(ApiConstants.bookingAccept(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> rejectBooking(String bookingId, String reason) async {
    // `reason` is a required @RequestParam; the response is
    // BookingWithAlternativesDto {booking, alternativeProviders}.
    final response = await _api.patch(
      ApiConstants.bookingReject(bookingId),
      queryParameters: {
        'reason': reason.isEmpty ? 'Declined by provider' : reason,
      },
    );
    return BookingModel.fromJson(
      response.data['data']['booking'] as Map<String, dynamic>,
    );
  }

  @override
  Future<BookingModel> completeBooking(
    String bookingId, {
    bool cashCollected = true,
  }) async {
    final response = await _api.patch(
      ApiConstants.bookingComplete(bookingId),
      queryParameters: {'cashCollected': cashCollected},
    );
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> proposeTime(
    String bookingId,
    String date,
    String time,
  ) async {
    final response = await _api.patch(
      ApiConstants.bookingProposeTime(bookingId),
      data: {'bookingDate': date, 'startTime': time},
    );
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> onTheWay(String bookingId) async {
    final response = await _api.patch(ApiConstants.bookingOnTheWay(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> arrived(String bookingId) async {
    final response = await _api.patch(ApiConstants.bookingArrived(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> inProgress(String bookingId) async {
    final response = await _api.patch(
      ApiConstants.bookingInProgress(bookingId),
    );
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }
}
