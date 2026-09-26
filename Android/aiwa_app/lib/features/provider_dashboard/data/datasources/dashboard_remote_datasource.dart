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

  Future<BookingModel> completeBooking(String bookingId);

  Future<BookingModel> markNoShow(String bookingId);

  Future<BookingModel> onTheWay(String bookingId);

  Future<BookingModel> arrived(String bookingId);

  Future<BookingModel> inProgress(String bookingId);
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final ApiClient _api;
  DashboardRemoteDataSourceImpl(this._api);

  @override
  Future<DashboardStats> getStats() async {
    final response = await _api.get(ApiConstants.providerStats);
    final d = response.data['data'] ?? response.data;
    return DashboardStats(
      totalBookings: (d['totalBookings'] as int?) ?? 0,
      pendingBookings: (d['pendingBookings'] as int?) ?? 0,
      completedBookings: (d['completedBookings'] as int?) ?? 0,
      totalRevenue: (d['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (d['totalReviews'] as int?) ?? 0,
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
    final response =
        await _api.patch(ApiConstants.bookingAccept(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> rejectBooking(
      String bookingId, String reason) async {
    final response = await _api.patch(
      ApiConstants.bookingReject(bookingId),
      data: {'reason': reason},
    );
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> completeBooking(String bookingId) async {
    final response =
        await _api.patch(ApiConstants.bookingComplete(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> markNoShow(String bookingId) async {
    final response =
        await _api.patch(ApiConstants.bookingNoShow(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> onTheWay(String bookingId) async {
    final response =
        await _api.patch(ApiConstants.bookingOnTheWay(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> arrived(String bookingId) async {
    final response =
        await _api.patch(ApiConstants.bookingArrived(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }

  @override
  Future<BookingModel> inProgress(String bookingId) async {
    final response =
        await _api.patch(ApiConstants.bookingInProgress(bookingId));
    return BookingModel.fromJson(response.data['data'] ?? response.data);
  }
}
