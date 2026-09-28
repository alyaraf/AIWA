import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<PagedData<NotificationModel>> getNotifications({
    int page = 0,
    int size = 20,
  });

  Future<int> getUnreadCount();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final ApiClient _api;
  NotificationRemoteDataSourceImpl(this._api);

  @override
  Future<PagedData<NotificationModel>> getNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      ApiConstants.notifications,
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data['data'] ?? response.data;
    return PagedData.fromJson(
      data,
      (e) => NotificationModel.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _api.get(ApiConstants.notificationsUnread);
    return (response.data['data'] as int?) ?? 0;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    // TODO(BE-11): backend has no per-row read endpoint yet, so this 404s and
    // NotificationBloc rolls the row back to unread.
    await _api.put('${ApiConstants.notifications}/$notificationId/read');
  }

  @override
  Future<void> markAllAsRead() async {
    await _api.post(ApiConstants.notificationsReadAll);
  }
}
